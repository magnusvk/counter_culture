module CounterCulture
  module ActiveRecord
    module Reflection
      def counter_culture_counter
        klass.after_commit_counter_cache.find do |counter|
          counter.model.name == class_name &&
            (counter.relation.include?(inverse_of && inverse_of.name) ||
              counter.relation.include?(options[:as]))
        end
      end

      # Method inspired from `ActiveRecord::Associations::HasManyAssociation#inverse_which_updates_counter_cache`
      def inverse_which_updates_counter_culture_cache
        reflections = if Rails.version < '4.1.0'
                        klass.reflections
                      else
                        klass._reflections
                      end
        reflections.values.find { |inverse_reflection|
          inverse_reflection.belongs_to? &&
          counter_culture_counter
        }
      end
      alias inverse_updates_counter_culture_cache? inverse_which_updates_counter_culture_cache

      # Method inspired from `ActiveRecord::Associations::HasManyAssociation#cached_counter_attribute_name`
      def cached_counter_culture_attribute_name
        counter_cache_name = counter_culture_counter.counter_cache_name
        counter_cache_name.is_a?(Proc) ? counter_cache_name.call(klass.new) : counter_cache_name
      end
    end

    module Associations
      module HasManyAssociation

        private

        # Overwrite method of `ActiveRecord::Associations::HasManyAssociation`
        def count_records
          if has_cached_counter_culture? &&
             counter_culture_attribute_name = reflection.cached_counter_culture_attribute_name
            count = if Rails.version < '4.2.0'
                      owner.read_attribute(counter_culture_attribute_name).to_i
                    else
                      owner._read_attribute(counter_culture_attribute_name).to_i
                    end

            # If there's nothing in the database and @target has no new records
            # we are certain the current target is an empty array. This is a
            # documented side-effect of the method that may avoid an extra SELECT.
            @target ||= [] and loaded! if count == 0

            [association_scope.limit_value, count].compact.min
          else
            super
          end
        end

        # Method inspired from `ActiveRecord::Associations::HasManyAssociation#has_cached_counter?`
        def has_cached_counter_culture?(reflection = reflection())
          return false unless reflection.inverse_which_updates_counter_culture_cache

          owner.attribute_present?(reflection.cached_counter_culture_attribute_name)
        end
      end
    end
  end
end
