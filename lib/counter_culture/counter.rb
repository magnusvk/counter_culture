module CounterCulture
  class Counter
<<<<<<< HEAD
    CONFIG_OPTIONS = [ :column_names, :counter_cache_name, :delta_column, :foreign_key_values, :touch, :delta_magnitude ]
=======
    CONFIG_OPTIONS = [ :column_names, :counter_cache_name, :delta_column, :foreign_key_values, :touch ]
>>>>>>> da8f9679e75dee5117434df9069345a2c4e2dfd8

    attr_reader :model, :relation, *CONFIG_OPTIONS

    def initialize(model, relation, options)
      @model = model
      @relation = relation.is_a?(Enumerable) ? relation : [relation]

      @counter_cache_name = options.fetch(:column_name, "#{model.name.tableize}_count")
      @column_names = options[:column_names]
      @delta_column = options[:delta_column]
<<<<<<< HEAD
      @delta_column = options[:delta_column]
      @foreign_key_values = options[:foreign_key_values]
      @touch = options.fetch(:touch, false)
      @delta_magnitude = options[:delta_magnitude] || 1
=======
      @foreign_key_values = options[:foreign_key_values]
      @touch = options.fetch(:touch, false)
>>>>>>> da8f9679e75dee5117434df9069345a2c4e2dfd8
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
<<<<<<< HEAD
                            @delta_magnitude
=======
                            1
>>>>>>> da8f9679e75dee5117434df9069345a2c4e2dfd8
                          end
        obj.execute_after_commit do
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

          klass = relation_klass(relation)
          klass.where(relation_primary_key(relation) => id_to_change).update_all updates.join(', ')
        end
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
        klass = relation_klass(first)
        value = klass.where("#{klass.table_name}.#{relation_primary_key(first)} = ?", foreign_key_value).first if foreign_key_value
      else
        value = obj
      end
      while !value.nil? && relation.size > 0
        value = value.send(relation.shift)
      end
      return value.try(relation_primary_key(first_relation).to_sym)
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
    def first_level_relation_foreign_key
      first_relation = relation.first if relation.is_a?(Enumerable)
      relation_reflect(first_relation).foreign_key
    end

    def previous_model(obj)
      prev = obj.dup

      obj.changed_attributes.each do |key, value|
        prev.send("#{key}=", value)
      end

      prev
    end
  end
end