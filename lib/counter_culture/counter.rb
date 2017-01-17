module CounterCulture
  class Counter
    CONFIG_OPTIONS = [ :column_names, :counter_cache_name, :delta_column, :foreign_key_values, :touch, :delta_magnitude, :execute_after_commit ]

    attr_reader :model, :relation, *CONFIG_OPTIONS

    def initialize(model, relation, options)
      @model = model
      @relation = relation.is_a?(Enumerable) ? relation : [relation]

      @counter_cache_name = options.fetch(:column_name, "#{model.name.tableize}_count")
      @column_names = options[:column_names]
      @delta_column = options[:delta_column]
      @foreign_key_values = options[:foreign_key_values]
      @touch = options.fetch(:touch, false)
      @delta_magnitude = options[:delta_magnitude] || 1
      @execute_after_commit = options.fetch(:execute_after_commit, false)
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
    #   :execute_after_commit => execute the column update outside of the transaction to avoid deadlocks
    def change_counter_cache(obj, options)
      change_counter_column = options.fetch(:counter_column) { counter_cache_name_for(obj) }

      # default to the current foreign key value
      id_to_change = foreign_key_value(obj, relation, options[:was])
      # allow overwriting of foreign key value by the caller
      id_to_change = foreign_key_values.call(id_to_change) if foreign_key_values

      if id_to_change && change_counter_column
        delta_magnitude = if delta_column
                            delta_attr_name = options[:was] ? "#{delta_column}_was" : delta_column
                            obj.send(delta_attr_name) || 0
                          else
                            counter_delta_magnitude_for(obj)
                          end
        execute_change_counter_cache(obj, options) do
          # increment or decrement?
          operator = options[:increment] ? '+' : '-'

          # we don't use Rails' update_counters because we support changing the timestamp
          quoted_column = model.connection.quote_column_name(change_counter_column)

          updates = []
          # this updates the actual counter
          updates << "#{quoted_column} = COALESCE(#{quoted_column}, 0) #{operator} #{delta_magnitude}"
          # and here we update the timestamp, if so desired
          if touch
            current_time = obj.send(:current_time_from_proper_timezone)
            obj.send(:timestamp_attributes_for_update_in_model).each do |timestamp_column|
              updates << "#{timestamp_column} = '#{current_time.to_formatted_s(:db)}'"
            end
          end

          klass = relation_klass(relation, source:obj)
          klass.where(relation_primary_key(relation, source: obj) => id_to_change).update_all updates.join(', ')
        end
      end
    end

    # Gets the delta magnitude of the counter cache for a specific object
    #
    # obj: object to calculate the counter cache name for
    def counter_delta_magnitude_for(obj)
      if delta_magnitude.is_a?(Proc)
        delta_magnitude.call(obj)
      else
        delta_magnitude
      end
    end

    # Gets the name of the counter cache for a specific object
    #
    # obj: object to calculate the counter cache name for
    # cache_name_finder: object used to calculate the cache name
    def counter_cache_name_for(obj)
      # figure out what the column name is
      if counter_cache_name.is_a?(Proc)
        # dynamic column name -- call the Proc
        counter_cache_name.call(obj)
      else
        # static column name
        counter_cache_name
      end
    end

    # the string to pass to order() in order to sort by primary key
    def full_primary_key(klass)
      "#{klass.quoted_table_name}.#{klass.quoted_primary_key}"
    end

    # gets the value of the foreign key on the given relation
    #
    # relation: a symbol or array of symbols; specifies the relation
    #   that has the counter cache column
    # was: whether to get the current or past value from ActiveRecord;
    #   pass true to get the past value, false or nothing to get the
    #   current value
    def foreign_key_value(obj, relation, was = false)
      relation = relation.is_a?(Enumerable) ? relation.dup : [relation]
      first_relation = relation.first
      if was
        first = relation.shift
        foreign_key_value = obj.send("#{relation_foreign_key(first)}_was")
        klass = relation_klass(first, source:obj)
        value = klass.where("#{klass.table_name}.#{relation_primary_key(first, source:obj)} = ?", foreign_key_value).first if foreign_key_value
      else
        value = obj
      end
      while !value.nil? && relation.size > 0
        value = value.send(relation.shift)
      end
      return value.try(relation_primary_key(first_relation, related: value).to_sym)
    end

    # gets the reflect object on the given relation
    #
    # relation: a symbol or array of symbols; specifies the relation
    #   that has the counter cache column
    def relation_reflect(relation)
      relation = relation.is_a?(Enumerable) ? relation.dup : [relation]

      # go from one relation to the next until we hit the last reflect object
      klass = model
      while relation.size > 0
        cur_relation = relation.shift
        reflect = klass.reflect_on_association(cur_relation)
        raise "No relation #{cur_relation} on #{klass.name}" if reflect.nil?
        klass = reflect.klass unless relation.size == 0
      end

      return reflect
    end

    # gets the class of the given relation
    #
    # relation: a symbol or array of symbols; specifies the relation
    #   that has the counter cache column
    # source [optional]: the source object,
    #   only needed for polymorphic associations,
    #   probably only works with a single relation (symbol, or array of 1 symbol)
    def relation_klass(relation, source:nil)
      reflect = relation_reflect(relation)
      if reflect.polymorphic?
        raise "Can't work out relation's class without being passed object (relation: #{relation}, reflect: #{reflect})" if source.nil?
        raise "Can't work out polymorhpic relation's class with multiple relations yet" unless (relation.is_a?(Symbol) || relation.length == 1)
        source.try(reflect.foreign_type.to_sym).constantize
      else
        reflect.klass
      end
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
    # related [optional]: the target object that the relationship is linked to,
    #   only needed for polymorphic associations,
    #   probably only works with a single relation (symbol, or array of 1 symbol)
    # source[optional]: the model instance that the relationship is linked from,
    #   only needed for polymorphic associations,
    #   probably only works with a single relation (symbol, or array of 1 symbol)
    def relation_primary_key(relation, related: nil, source: nil)
      reflect = relation_reflect(relation)
      klass = nil
      if reflect.polymorphic?
        raise "can't handle multiple keys with polymorphic associations" unless (relation.is_a?(Symbol) || relation.length == 1)
        return source.class.primary_key if source
        klass = (related && related.class)
        raise "must specify related or source for polymorphic associations..." unless klass
      end
      reflect.association_primary_key(klass)
    end

    # gets the foreign key name of the relation. will look at the first
    # level only -- i.e., if passed an array will consider only its
    # first element
    #
    # relation: a symbol or array of symbols; specifies the relation
    #   that has the counter cache column
    def first_level_relation_foreign_key
      first_relation = relation.first if relation.is_a?(Enumerable)
      relation_reflect(first_relation).foreign_key
    end

    def polymorphic?
      relation_reflect(relation).polymorphic?.tap do |is_polymorphic|
        raise "Polymorphic associations only supported with one level" unless (relation.is_a?(Symbol) || relation.length == 1) if is_polymorphic
      end
    end

    def previous_model(obj)
      prev = obj.dup

      obj.changed_attributes.each do |key, value|
        prev.send("#{key}=", value)
      end

      prev
    end

    private

    def execute_change_counter_cache(obj, options)
      if execute_after_commit
        obj.execute_after_commit { yield }
      else
        yield
      end
    end
  end
end
