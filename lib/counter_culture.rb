require 'after_commit_action'

module CounterCulture

  module ActiveRecord

    def self.included(base)
      # also add class methods to ActiveRecord::Base
      base.extend ClassMethods
    end

    module ClassMethods
      # this holds all configuration data
      attr_reader :after_commit_counter_cache

      # called to configure counter caches
      def counter_culture(relation, options = {})
        unless @after_commit_counter_cache
          # initialize callbacks only once
          after_create :_update_counts_after_create
          after_destroy :_update_counts_after_destroy
          after_update :_update_counts_after_update

          # we keep a list of all counter caches we must maintain
          @after_commit_counter_cache = []
        end

        # add the current information to our list
        @after_commit_counter_cache<< {
          :relation => relation.is_a?(Enumerable) ? relation : [relation],
          :counter_cache_name => (options[:column_name] || "#{name.tableize}_count"),
          :column_names => options[:column_names],
          :foreign_key_values => options[:foreign_key_values]
        }
      end

      # checks all of the declared counter caches on this class for correctnes based
      # on original data; if the counter cache is incorrect, sets it to the correct
      # count
      #
      # options:
      #   { :exclude => list of relations to skip when fixing counts,
      #     :only => only these relations will have their counts fixed }
      # returns: a list of fixed record as an array of hashes of the form:
      #   { :entity => which model the count was fixed on,
      #     :id => the id of the model that had the incorrect count,
      #     :what => which column contained the incorrect count,
      #     :wrong => the previously saved, incorrect count,
      #     :right => the newly fixed, correct count }
      #
      def counter_culture_fix_counts(options = {})
        options[:exclude] = [options[:exclude]] if options[:exclude] && !options[:exclude].is_a?(Enumerable)
        options[:exclude] = options[:exclude].try(:map) {|x| x.is_a?(Enumerable) ? x : [x] }
        options[:only] = [options[:only]] if options[:only] && !options[:only].is_a?(Enumerable)
        options[:only] = options[:only].try(:map) {|x| x.is_a?(Enumerable) ? x : [x] }

        fixed = []
        @after_commit_counter_cache.each do |hash|
          next if options[:exclude] && options[:exclude].include?(hash[:relation])
          next if options[:only] && !options[:only].include?(hash[:relation])

          if options[:skip_unsupported]
            next if (hash[:foreign_key_values] || (hash[:counter_cache_name].is_a?(Proc) && !hash[:column_names]))
          else
            raise "Fixing counter caches is not supported when using :foreign_key_values; you may skip this relation with :skip_unsupported => true" if hash[:foreign_key_values]
            raise "Must provide :column_names option for relation #{hash[:relation].inspect} when :column_name is a Proc; you may skip this relation with :skip_unsupported => true" if hash[:counter_cache_name].is_a?(Proc) && !hash[:column_names]
          end

          # if we're provided a custom set of column names with conditions, use them; just use the
          # column name otherwise
          # which class does this relation ultimately point to? that's where we have to start
          klass = relation_klass(hash[:relation])

          # we are only interested in the id and the count of related objects (that's this class itself)
          query = klass.select("#{klass.table_name}.id, COUNT(#{self.table_name}.id) AS count")
          query = query.group("#{klass.table_name}.id")

          column_names = hash[:column_names] || {nil => hash[:counter_cache_name]}
          raise ":column_names must be a Hash of conditions and column names" unless column_names.is_a?(Hash)

          # iterate over all the possible counter cache column names
          column_names.each do |where, column_name|
            # if there are additional conditions, add them here
            counts = query.where(where)

            # we need to work our way back from the end-point of the relation to this class itself;
            # make a list of arrays pointing to the second-to-last, third-to-last, etc.
            reverse_relation = []
            (1..hash[:relation].length).to_a.reverse.each {|i| reverse_relation<< hash[:relation][0,i] }

            # we need to join together tables until we get back to the table this class itself
            # lives in
            reverse_relation.each do |cur_relation|
              reflect = relation_reflect(cur_relation)
              counts = counts.joins("JOIN #{reflect.active_record.table_name} ON #{reflect.table_name}.id = #{reflect.active_record.table_name}.#{reflect.foreign_key}")
            end
            # and then we collect the counts in an id => count hash
            counts = counts.inject({}){|memo, model| memo[model.id] = model.count.to_i; memo}

            # now that we know what the correct counts are, we need to iterate over all instances
            # and check whether the count is correct; if not, we correct it
            klass.find_each do |model|
              if model.read_attribute(column_name) != counts[model.id].to_i
                # keep track of what we fixed, e.g. for a notification email
                fixed<< {
                  :entity => klass.name,
                  :id => model.id,
                  :what => column_name,
                  :wrong => model.send(column_name),
                  :right => counts[model.id]
                }
                # use update_all because it's faster and because a fixed counter-cache shouldn't
                # update the timestamp
                klass.update_all "#{column_name} = #{counts[model.id].to_i}", "id = #{model.id}"
              end
            end
          end
        end

        return fixed
      end

      private
      # gets the reflect object on the given relation
      #
      # relation: a symbol or array of symbols; specifies the relation
      #   that has the counter cache column
      def relation_reflect(relation)
        relation = relation.is_a?(Enumerable) ? relation.dup : [relation]

        # go from one relation to the next until we hit the last reflect object
        klass = self
        while relation.size > 0
          cur_relation = relation.shift
          reflect = klass.reflect_on_association(cur_relation)
          raise "No relation #{cur_relation} on #{klass.name}" if reflect.nil?
          klass = reflect.klass
        end

        return reflect
      end

      # gets the class of the given relation
      #
      # relation: a symbol or array of symbols; specifies the relation
      #   that has the counter cache column
      def relation_klass(relation)
        relation_reflect(relation).klass
      end

      # gets the foreign key name of the given relation
      #
      # relation: a symbol or array of symbols; specifies the relation
      #   that has the counter cache column
      def relation_foreign_key(relation)
        relation_reflect(relation).foreign_key
      end
      
      # gets the foreign key name of the relation. will look at the first
      # level only -- i.e., if passed an array will consider only its
      # first element
      #
      # relation: a symbol or array of symbols; specifies the relation
      #   that has the counter cache column
      def first_level_relation_foreign_key(relation)
        relation = relation.first if relation.is_a?(Enumerable)
        relation_reflect(relation).foreign_key
      end
        
    end

    private
    # called by after_create callback
    def _update_counts_after_create
      self.class.after_commit_counter_cache.each do |hash|
        # increment counter cache
        change_counter_cache(hash.merge(:increment => true))
      end
    end

    # called by after_destroy callback
    def _update_counts_after_destroy
      self.class.after_commit_counter_cache.each do |hash|
        # decrement counter cache
        change_counter_cache(hash.merge(:increment => false))
      end
    end

    # called by after_update callback
    def _update_counts_after_update
      self.class.after_commit_counter_cache.each do |hash|
        # figure out whether the applicable counter cache changed (this can happen
        # with dynamic column names)
        counter_cache_name_was = counter_cache_name_for(previous_model, hash[:counter_cache_name])
        counter_cache_name = counter_cache_name_for(self, hash[:counter_cache_name])

        if send("#{first_level_relation_foreign_key(hash[:relation])}_changed?") || counter_cache_name != counter_cache_name_was
          # increment the counter cache of the new value
          change_counter_cache(hash.merge(:increment => true, :counter_column => counter_cache_name))
          # decrement the counter cache of the old value
          change_counter_cache(hash.merge(:increment => false, :was => true, :counter_column => counter_cache_name_was))
        end
      end
    end

    # increments or decrements a counter cache
    #
    # options:
    #   :increment => true to increment, false to decrement
    #   :relation => which relation to increment the count on, 
    #   :counter_cache_name => the column name of the counter cache
    #   :counter_column => overrides :counter_cache_name
    #   :was => whether to get the current value or the old value of the
    #      first part of the relation
    def change_counter_cache(options)
      options[:counter_column] = counter_cache_name_for(self, options[:counter_cache_name]) unless options.has_key?(:counter_column)
      
      # default to the current foreign key value
      id_to_change = foreign_key_value(options[:relation], options[:was])
      # allow overwriting of foreign key value by the caller
      id_to_change = options[:foreign_key_values].call(id_to_change) if options[:foreign_key_values]

      if id_to_change && options[:counter_column]
        execute_after_commit do
          # increment or decrement?
          method = options[:increment] ? :increment_counter : :decrement_counter

          # do it!
          relation_klass(options[:relation]).send(method, options[:counter_column], id_to_change)
        end
      end
    end

    # Gets the name of the counter cache for a specific object
    # 
    # obj: object to calculate the counter cache name for
    # cache_name_finder: object used to calculate the cache name
    def counter_cache_name_for(obj, cache_name_finder)
      # figure out what the column name is
      if cache_name_finder.is_a? Proc
        # dynamic column name -- call the Proc
        cache_name_finder.call(obj) 
      else
        # static column name
        cache_name_finder
      end
    end

    # Creates a copy of the current model with changes rolled back
    def previous_model
      prev = self.dup
      
      self.changed_attributes.each_pair do |key, value|
        prev.send("#{key}=".to_sym, value)
      end
      
      prev
    end

    # gets the value of the foreign key on the given relation
    #
    # relation: a symbol or array of symbols; specifies the relation
    #   that has the counter cache column
    # was: whether to get the current or past value from ActiveRecord;
    #   pass true to get the past value, false or nothing to get the
    #   current value
    def foreign_key_value(relation, was = false)
      relation = relation.is_a?(Enumerable) ? relation.dup : [relation]
      if was
        first = relation.shift
        foreign_key_value = send("#{relation_foreign_key(first)}_was")
        value = relation_klass(first).find(foreign_key_value) if foreign_key_value
      else
        value = self
      end
      while !value.nil? && relation.size > 0
        value = value.send(relation.shift)
      end
      return value.try(:id)
    end

    def relation_klass(relation)
      self.class.send :relation_klass, relation
    end

    def relation_reflect(relation)
      self.class.send :relation_reflect, relation
    end
    
    def relation_foreign_key(relation)
      self.class.send :relation_foreign_key, relation
    end

    def first_level_relation_foreign_key(relation)
      self.class.send :first_level_relation_foreign_key, relation
    end

  end

  # extend ActiveRecord with our own code here
  ::ActiveRecord::Base.send :include, ActiveRecord
end
