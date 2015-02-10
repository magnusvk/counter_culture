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
          :delta_column => options[:delta_column],
          :foreign_key_values => options[:foreign_key_values],
          :touch => options[:touch]
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
        raise "No counter cache defined on #{self.name}" unless @after_commit_counter_cache

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
          query = klass

          if klass.table_name == self.table_name
            self_table_name = "#{self.table_name}_#{self.table_name}"
          else
            self_table_name = self.table_name
          end

          # if a delta column is provided use SUM, otherwise use COUNT
          count_select = hash[:delta_column] ? "SUM(COALESCE(#{self_table_name}.#{hash[:delta_column]},0))" : "COUNT(#{self_table_name}.#{self.primary_key})"

          # respect the deleted_at column if it exists
          query = query.where("#{self.table_name}.deleted_at IS NULL") if self.column_names.include?('deleted_at')

          column_names = hash[:column_names] || {nil => hash[:counter_cache_name]}
          raise ":column_names must be a Hash of conditions and column names" unless column_names.is_a?(Hash)

          # we need to work our way back from the end-point of the relation to this class itself;
          # make a list of arrays pointing to the second-to-last, third-to-last, etc.
          reverse_relation = (1..hash[:relation].length).to_a.reverse.inject([]) {|a,i| a << hash[:relation][0,i]; a }

          # store joins in an array so that we can later apply column-specific conditions
          joins = reverse_relation.map do |cur_relation|
            reflect = relation_reflect(cur_relation)
            if klass.table_name == reflect.active_record.table_name
              join_table_name = "#{klass.table_name}_#{klass.table_name}"
            else
              join_table_name = reflect.active_record.table_name
            end
            # join with alias to avoid ambiguous table name with self-referential models:
            joins_query = "LEFT JOIN #{reflect.active_record.table_name} AS #{join_table_name} ON #{reflect.table_name}.#{reflect.association_primary_key} = #{join_table_name}.#{reflect.foreign_key}"
            # adds 'type' condition to JOIN clause if the current model is a child in a Single Table Inheritance
            joins_query = "#{joins_query} AND #{reflect.active_record.table_name}.type IN ('#{self.name}')" if reflect.active_record.column_names.include?('type') and not(self.descends_from_active_record?)
            joins_query
          end

          # iterate over all the possible counter cache column names
          column_names.each do |where, column_name|
            # select join column and count (from above) as well as cache column ('column_name') for later comparison
            counts_query = query.select("#{klass.table_name}.#{klass.primary_key}, #{klass.table_name}.#{relation_reflect(hash[:relation]).association_primary_key}, #{count_select} AS count, #{klass.table_name}.#{column_name}")

            # we need to join together tables until we get back to the table this class itself lives in
            # conditions must also be applied to the join on which we are counting
            joins.each_with_index do |join,index|
              join += " AND (#{sanitize_sql_for_conditions(where)})" if index == joins.size - 1 && where
              counts_query = counts_query.joins(join)
            end

            # iterate in batches; otherwise we might run out of memory when there's a lot of
            # instances and we try to load all their counts at once
            start = 0
            batch_size = options[:batch_size] || 1000

            while (records = counts_query.reorder(full_primary_key(klass) + " ASC").offset(start).limit(batch_size).group(full_primary_key(klass)).to_a).any?
              # now iterate over all the models and see whether their counts are right
              records.each do |model|
                count = model.read_attribute('count') || 0
                if model.read_attribute(column_name) != count
                  # keep track of what we fixed, e.g. for a notification email
                  fixed<< {
                    :entity => klass.name,
                    klass.primary_key.to_sym => model.send(klass.primary_key),
                    :what => column_name,
                    :wrong => model.send(column_name),
                    :right => count
                  }
                  # use update_all because it's faster and because a fixed counter-cache shouldn't
                  # update the timestamp
                  klass.where(klass.primary_key => model.send(klass.primary_key)).update_all(column_name => count)
                end
              end

              start += batch_size
            end
          end
        end

        return fixed
      end

      private
      # the string to pass to order() in order to sort by primary key
      def full_primary_key(klass)
        "#{klass.quoted_table_name}.#{klass.quoted_primary_key}"
      end

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

      # gets the primary key name of the given relation
      #
      # relation: a symbol or array of symbols; specifies the relation
      #   that has the counter cache column
      def relation_primary_key(relation)
        relation_reflect(relation).association_primary_key
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
    # need to make sure counter_culture is only activated once
    # per commit; otherwise, if we do an update in an after_create,
    # we would be triggered twice within the same transaction -- once
    # for the create, once for the update
    def _wrap_in_counter_culture_active(&block)
      if @_counter_culture_active
        # don't do anything; we are already active for this transaction
      else
        @_counter_culture_active = true
        block.call
        execute_after_commit { @_counter_culture_active = false}
      end
    end

    # called by after_create callback
    def _update_counts_after_create
      _wrap_in_counter_culture_active do
        self.class.after_commit_counter_cache.each do |hash|
          # increment counter cache
          change_counter_cache(hash.merge(:increment => true))
        end
      end
    end

    # called by after_destroy callback
    def _update_counts_after_destroy
      _wrap_in_counter_culture_active do
        self.class.after_commit_counter_cache.each do |hash|
          # decrement counter cache
          change_counter_cache(hash.merge(:increment => false))
        end
      end
    end

    # called by after_update callback
    def _update_counts_after_update
      _wrap_in_counter_culture_active do
        self.class.after_commit_counter_cache.each do |hash|
          # figure out whether the applicable counter cache changed (this can happen
          # with dynamic column names)
          counter_cache_name_was = counter_cache_name_for(previous_model, hash[:counter_cache_name])
          counter_cache_name = counter_cache_name_for(self, hash[:counter_cache_name])

          if send("#{first_level_relation_foreign_key(hash[:relation])}_changed?") ||
            (hash[:delta_column] && send("#{hash[:delta_column]}_changed?")) ||
            counter_cache_name != counter_cache_name_was

            # increment the counter cache of the new value
            change_counter_cache(hash.merge(:increment => true, :counter_column => counter_cache_name))
            # decrement the counter cache of the old value
            change_counter_cache(hash.merge(:increment => false, :was => true, :counter_column => counter_cache_name_was))
          end
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
    #   :delta_column => override the default count delta (1) with the value of this column in the counted record
    #   :was => whether to get the current value or the old value of the
    #      first part of the relation
    def change_counter_cache(options)
      options[:counter_column] = counter_cache_name_for(self, options[:counter_cache_name]) unless options.has_key?(:counter_column)

      # default to the current foreign key value
      id_to_change = foreign_key_value(options[:relation], options[:was])
      # allow overwriting of foreign key value by the caller
      id_to_change = options[:foreign_key_values].call(id_to_change) if options[:foreign_key_values]

      if id_to_change && options[:counter_column]
        delta_magnitude = if options[:delta_column]
                            delta_attr_name = options[:was] ? "#{options[:delta_column]}_was" : options[:delta_column]
                            self.send(delta_attr_name) || 0
                          else
                            1
                          end
        execute_after_commit do
          # increment or decrement?
          operator = options[:increment] ? '+' : '-'

          # we don't use Rails' update_counters because we support changing the timestamp
          quoted_column = self.class.connection.quote_column_name(options[:counter_column])

          updates = []
          # this updates the actual counter
          updates << "#{quoted_column} = COALESCE(#{quoted_column}, 0) #{operator} #{delta_magnitude}"
          # and here we update the timestamp, if so desired
          if options[:touch]
            current_time = current_time_from_proper_timezone
            timestamp_attributes_for_update_in_model.each do |timestamp_column|
              updates << "#{timestamp_column} = '#{current_time.to_formatted_s(:db)}'"
            end
          end

          klass = relation_klass(options[:relation])
          klass.where(relation_primary_key(options[:relation]) => id_to_change).update_all updates.join(', ')
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
      first_relation = relation.first
      if was
        first = relation.shift
        foreign_key_value = send("#{relation_foreign_key(first)}_was")
        value = relation_klass(first).where("#{relation_primary_key(first)} = ?", foreign_key_value).first if foreign_key_value
      else
        value = self
      end
      while !value.nil? && relation.size > 0
        value = value.send(relation.shift)
      end
      return value.try(relation_primary_key(first_relation).to_sym)
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

    def relation_primary_key(relation)
      self.class.send :relation_primary_key, relation
    end

    def first_level_relation_foreign_key(relation)
      self.class.send :first_level_relation_foreign_key, relation
    end

  end

  # extend ActiveRecord with our own code here
  ::ActiveRecord::Base.send :include, ActiveRecord
end

