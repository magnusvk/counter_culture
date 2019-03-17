module CounterCulture
  module ActiveRecord
    module Reflection
      # Wrapping ActiveRecord::Reflection::AbstractReflection public method
      def has_cached_counter?
        has_cached_counter_culture? || super
      end

      # Wrapping ActiveRecord::Reflection::AbstractReflection public method
      def counter_cache_column
        if has_cached_counter_culture?
          cached_counter_culture_attribute_name
        else
          super
        end
      end

      # Method inspired from `ActiveRecord::Associations::HasManyAssociation#cached_counter_attribute_name`
      def cached_counter_culture_attribute_name
        return unless counter_culture_counter

        counter_cache_name = counter_culture_counter.counter_cache_name
        counter_cache_name.is_a?(Proc) ? counter_cache_name.call(klass.new) : counter_cache_name
      end

      private

      def has_cached_counter_culture?
        return false unless inverse_which_updates_counter_culture_cache

        active_record.new.attribute_present?(cached_counter_culture_attribute_name)
      end

      def counter_culture_reflection
        return self unless is_a?(::ActiveRecord::Reflection::ThroughReflection)

        through_reflection
      end

      def inverse_which_updates_counter_culture_cache
        return if polymorphic?

        counter = counter_culture_counter
        return unless counter

        reflections = if Rails.version < '4.1.0'
                        klass.reflections
                      else
                        klass._reflections
                      end

        reflections.values.find { |inverse_reflection|
          inverse_reflection.belongs_to? &&
          counter.relation.include?(inverse_reflection.name)
        }
      end

      def counter_culture_counter
        klass.after_commit_counter_cache.find do |counter|
          counter.model.name == class_name &&
            (counter.relation.include?(counter_culture_reflection.inverse_of && counter_culture_reflection.inverse_of.name) ||
              counter.relation.include?(options[:as]))
        end
      end
    end
  end
end
