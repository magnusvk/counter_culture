require_relative './with_connection'

module CounterCulture
  class Counter
    CONFIG_OPTIONS = [ :column_names, :counter_cache_name, :delta_column, :foreign_key_values, :touch, :delta_magnitude, :execute_after_commit ]
    ACTIVE_RECORD_VERSION = Gem.loaded_specs["activerecord"].version

    attr_reader :model, :relation, *CONFIG_OPTIONS

    def initialize(model, relation, options)
      @model = model
      @relation = relation.is_a?(Enumerable) ? relation : [relation]

      @counter_cache_name = options.fetch(:column_name, "#{model.name.demodulize.tableize}_count")
      @column_names = options[:column_names]
      @delta_column = options[:delta_column]
      @foreign_key_values = options[:foreign_key_values]
      @touch = options.fetch(:touch, false)
      @delta_magnitude = options[:delta_magnitude] || 1
      @with_papertrail = options.fetch(:with_papertrail, false)
      @execute_after_commit = options.fetch(:execute_after_commit, false)

      if @execute_after_commit
        begin
          require 'after_commit_action'
        rescue LoadError
          fail(LoadError.new(
            "You need to include the `after_commit_action` gem in your "\
            "gem dependencies to use the execute_after_commit option"))
        end
        model.include(AfterCommitAction)
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
    #   :with_papertrail => update the column via Papertrail touch_with_version method
    def change_counter_cache(obj, options)
      change_counter_column = options.fetch(:counter_column) { counter_cache_name_for(obj) }

      # default to the current foreign key value
      id_to_change = foreign_key_value(obj, relation, options[:was])
      # allow overwriting of foreign key value by the caller
      id_to_change = foreign_key_values.call(id_to_change) if foreign_key_values

      if id_to_change && change_counter_column
        delta_magnitude = if delta_column
                            (options[:was] ? attribute_was(obj, delta_column) : obj.public_send(delta_column)) || 0
                          else
                            counter_delta_magnitude_for(obj)
                          end
        return if delta_magnitude.zero?

        klass = relation_klass(relation, source: obj, was: options[:was])

        column_type = klass.type_for_attribute(change_counter_column).type

        # Calculate signed delta for both paths
        signed_delta = options[:increment] ? delta_magnitude : -delta_magnitude

        if Thread.current[:aggregate_counter_updates]
          # Store structured data for later Arel assembly
          remember_counter_update(klass, id_to_change, change_counter_column, signed_delta, column_type)
        else
          # Build Arel expression for non-aggregate case
          counter_expr = Counter.build_arel_counter_expr(klass, change_counter_column, signed_delta, column_type)
          arel_updates = { change_counter_column => counter_expr }
        end

        # and this will update the timestamp, if so desired
        if touch
          current_time = klass.send(:current_time_from_proper_timezone)
          timestamp_columns = klass.send(:timestamp_attributes_for_update_in_model)
          if touch != true
            # starting in Rails 6 this is frozen
            timestamp_columns = timestamp_columns.dup
            timestamp_columns << touch
          end
          timestamp_columns.each do |timestamp_column|
            if Thread.current[:aggregate_counter_updates]
              remember_timestamp_update(klass, id_to_change, timestamp_column)
            else
              arel_updates[timestamp_column] = current_time
            end
          end
        end

        primary_key = relation_primary_key(relation, source: obj, was: options[:was])

        if foreign_key_values && id_to_change.is_a?(Enumerable) && id_to_change.count > 1 &&
            Array.wrap(primary_key).count == 1
          # To keep this feature backwards compatible, we need to accommodate a case where
          # `foreign_key_values` returns an array, but we're _not_ using composite primary
          # keys. In that case, we need to wrap the `id_to_change` in one more array to keep
          # it compatible with the `.zip` call in `primary_key_conditions`.
          id_to_change = [id_to_change]
        end

        if Thread.current[:aggregate_counter_updates]
          Thread.current[:primary_key_map][klass] ||= primary_key
        end

        if @with_papertrail
          conditions = primary_key_conditions(primary_key, id_to_change)
          instance = klass.where(conditions).first

          if instance
            if instance.paper_trail.respond_to?(:save_with_version)
              # touch_with_version is deprecated starting in PaperTrail 9.0.0

              current_time = obj.send(:current_time_from_proper_timezone)
              timestamp_columns = obj.send(:timestamp_attributes_for_update_in_model)
              timestamp_columns.each do |timestamp_column|
                instance.send("#{timestamp_column}=", current_time)
              end

              execute_now_or_after_commit(obj) do
                instance.paper_trail.save_with_version(validate: false)
              end
            else
              execute_now_or_after_commit(obj) do
                instance.paper_trail.touch_with_version
              end
            end
          end
        end

        unless Thread.current[:aggregate_counter_updates]
          execute_now_or_after_commit(obj) do
            conditions = primary_key_conditions(primary_key, id_to_change)
            # Use Arel-based updates which let Rails handle column qualification properly,
            # avoiding ambiguous column errors in Rails 8.1+ UPDATE...FROM syntax.
            klass.where(conditions).distinct(false).update_all(arel_updates)
            # Determine if we should update the in-memory counter on the associated object.
            # When updating the old counter (was: true), we need to carefully consider two scenarios:
            # 1) The belongs_to relation changed (e.g., moving a child from parent A to parent B):
            #    In this case, obj.association now points to parent B, but we're decrementing parent A's
            #    counter. We should NOT update the in-memory counter because it would incorrectly
            #    modify parent B's cached value.
            # 2) A conditional counter's condition changed (e.g., condition: true → false):
            #    In this case, obj.association still points to the same parent, but the counter column
            #    name changed (e.g., from 'conditional_count' to nil). We SHOULD update the in-memory
            #    counter so the parent object reflects the decremented value without requiring a reload.
            # We distinguish these cases by comparing foreign keys: if the current and previous foreign
            # keys are identical, we're in scenario 2 and should update the in-memory counter.
            should_update_counter = if options[:was]
              current_fk = foreign_key_value(obj, relation, false)
              previous_fk = foreign_key_value(obj, relation, true)
              current_fk == previous_fk && current_fk.present?
            else
              true
            end

            if should_update_counter
              operator = options[:increment] ? '+' : '-'
              assign_to_associated_object(obj, relation, change_counter_column, operator, delta_magnitude)
            end
          end
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
      Array.wrap(klass.quoted_primary_key).map { |pk| "#{klass.quoted_table_name}.#{pk}" }.join(', ')
    end

    # gets the value of the foreign key on the given relation
    #
    # relation: a symbol or array of symbols; specifies the relation
    #   that has the counter cache column
    # was: whether to get the current or past value from ActiveRecord;
    #   pass true to get the past value, false or nothing to get the
    #   current value
    def foreign_key_value(obj, relation, was = false)
      original_relation = relation
      relation = relation.is_a?(Enumerable) ? relation.dup : [relation]

      value = if was
        first = relation.shift
        foreign_key_value = attribute_was(obj, relation_foreign_key(first))
        klass = relation_klass(first, source: obj, was: was)
        if foreign_key_value
          primary_key = relation_primary_key(first, source: obj, was: was)
          conditions = primary_key_conditions(primary_key, foreign_key_value)
          klass.where(conditions).first
        end
      else
        obj
      end
      while !value.nil? && relation.size > 0
        value = value.send(relation.shift)
      end

      primary_key = relation_primary_key(original_relation, source: obj, was: was)
      Array.wrap(primary_key).map { |pk| value.try(pk&.to_sym) }.compact.presence
    end

    # gets the reflect object on the given relation and the model that defines this reflect
    #
    # relation: a symbol or array of symbols; specifies the relation
    #   that has the counter cache column
    def relation_reflect_and_model(relation)
      relation = relation.is_a?(Enumerable) ? relation.dup : [relation]

      # go from one relation to the next until we hit the last reflect object
      klass = model
      while relation.size > 0
        cur_relation = relation.shift
        reflect = klass.reflect_on_association(cur_relation)
        raise "No relation #{cur_relation} on #{klass.name}" if reflect.nil?

        if relation.size > 0
          # not necessary to do this at the last link because we won't use
          # klass again. not calling this avoids the following causing an
          # exception in the now-supported one-level polymorphic counter cache
          klass = reflect.klass
        end
      end

      return [reflect, klass]
    end


    # gets the reflect object on the given relation
    #
    # relation: a symbol or array of symbols; specifies the relation
    #   that has the counter cache column
    def relation_reflect(relation)
      relation_reflect_and_model(relation).first
    end

    # gets the class of the given relation
    #
    # relation: a symbol or array of symbols; specifies the relation
    #   that has the counter cache column
    # source [optional]: the source object,
    #   only needed for polymorphic associations,
    #   probably only works with a single relation (symbol, or array of 1 symbol)
    # was: boolean
    #   we're actually looking for the old value -- only can change for polymorphic relations
    def relation_klass(relation, source: nil, was: false)
      reflect = relation_reflect(relation)
      if reflect.options.key?(:polymorphic)
        raise "Can't work out relation's class without being passed object (relation: #{relation}, reflect: #{reflect})" if source.nil?
        raise "Can't work out polymorhpic relation's class with multiple relations yet" unless (relation.is_a?(Symbol) || relation.length == 1)
        # this is the column that stores the polymorphic type, aka the class name
        type_column = reflect.foreign_type.to_sym
        # so now turn that into the class that we're looking for here
        if was
          attribute_was(source, type_column).try(:constantize)
        else
          source.public_send(type_column).try(:constantize)
        end
      else
        reflect.klass
      end
    end

    def first_level_relation_changed?(instance)
      return true if attribute_changed?(instance, first_level_relation_foreign_key)
      if polymorphic?
        return true if attribute_changed?(instance, first_level_relation_foreign_type)
      end
      false
    end

    def attribute_changed?(obj, attr)
      if ACTIVE_RECORD_VERSION >= Gem::Version.new("5.1.0")
        obj.saved_changes[attr].present?
      else
        obj.send(:attribute_changed?, attr)
      end
    end

    def polymorphic?
      is_polymorphic = relation_reflect(relation).options.key?(:polymorphic)
      if is_polymorphic && !(relation.is_a?(Symbol) || relation.length == 1)
        raise "Polymorphic associations only supported with one level"
      end
      return is_polymorphic
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
    # source[optional]: the model instance that the relationship is linked from,
    #   only needed for polymorphic associations,
    #   probably only works with a single relation (symbol, or array of 1 symbol)
    # was: boolean
    #   we're actually looking for the old value -- only can change for polymorphic relations
    def relation_primary_key(relation, source: nil, was: false)
      reflect = relation_reflect(relation)
      klass = nil
      if reflect.options.key?(:polymorphic)
        raise "can't handle multiple keys with polymorphic associations" unless (relation.is_a?(Symbol) || relation.length == 1)
        raise "must specify source for polymorphic associations..." unless source

        return reflect.options[:primary_key] if reflect.options.key?(:primary_key)
        return relation_klass(relation, source: source, was: was).try(:primary_key)
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

    def first_level_relation_foreign_type
      return nil unless polymorphic?
      first_relation = relation.first if relation.is_a?(Enumerable)
      relation_reflect(first_relation).foreign_type
    end

    def previous_model(obj)
      prev = obj.dup

      changes_method = ACTIVE_RECORD_VERSION >= Gem::Version.new("5.1.0") ? :saved_changes : :changed_attributes
      obj.public_send(changes_method).each do |key, value|
        next unless obj.has_attribute?(key.to_s)

        old_value = ACTIVE_RECORD_VERSION >= Gem::Version.new("5.1.0") ? value.first : value
        # We set old values straight to AR @attributes variable to avoid
        # write_attribute callbacks from other gems (e.g. ArTransactionChanges)
        prev.instance_variable_get(:@attributes).write_from_user(key, old_value)
      end

      prev
    end

    def execute_now_or_after_commit(obj, &block)
      execute_after_commit = @execute_after_commit.is_a?(Proc) ? @execute_after_commit.call : @execute_after_commit

      if execute_after_commit
        obj.execute_after_commit(&block)
      else
        block.call
      end
    end

    private

    def attribute_was(obj, attr)
      changes_method =
        if ACTIVE_RECORD_VERSION >= Gem::Version.new("5.1.0")
          "_before_last_save"
        else
          "_was"
        end
      obj.public_send("#{attr}#{changes_method}")
    end

    # update associated object counter attribute
    def assign_to_associated_object(obj, relation, change_counter_column, operator, delta_magnitude)
      association_name = relation_reflect(relation).name

      association_object = association_object_for_assign(obj, association_name)
      return if association_object.blank? || association_object.frozen?

      association_object.assign_attributes(
        change_counter_column =>
          association_object_new_counter(association_object, change_counter_column, operator, delta_magnitude)
      )
      association_object_clear_change(association_object, change_counter_column)
    end

    def association_object_for_assign(obj, association_name)
      if obj.class.reflect_on_all_associations.
          find { |assoc| assoc.name.to_sym == association_name.to_sym }.
          blank?
        # This means that this isn't defined as an association; either it
        # doesn't exist at all, or it uses delegate. In either case, we can't
        # update the count this way.
        return
      end
      if !obj.association(association_name).loaded?
        # If the association isn't loaded, no need to update the count
        return
      end

      obj.public_send(association_name)
    end

    def association_object_clear_change(association_object, change_counter_column)
      if ACTIVE_RECORD_VERSION >= Gem::Version.new("6.1.0")
        association_object.public_send(:"clear_#{change_counter_column}_change")
      else
        association_object.send(:clear_attribute_change, change_counter_column)
      end
    end

    def association_object_new_counter(association_object, change_counter_column, operator, delta_magnitude)
      (association_object.public_send(change_counter_column) || 0).public_send(operator, delta_magnitude)
    end

    def primary_key_conditions(primary_key, fk_value)
      Array.wrap(primary_key)
          .zip(Array.wrap(fk_value))
          .to_h
    end

    # Builds an Arel expression for counter updates: COALESCE(col, 0) +/- delta
    # This is a class method so it can be called from CounterCulture.aggregate_counter_updates
    def self.build_arel_counter_expr(klass, column, delta, column_type)
      arel_column = klass.arel_table[column]
      arel_delta = Arel::Nodes.build_quoted(delta.abs)

      coalesce = if column_type == :money
        Arel::Nodes::NamedFunction.new(
          'COALESCE',
          [Arel::Nodes::NamedFunction.new('CAST', [arel_column.as('NUMERIC')]), 0]
        )
      else
        Arel::Nodes::NamedFunction.new('COALESCE', [arel_column, 0])
      end

      if delta > 0
        Arel::Nodes::Addition.new(coalesce, arel_delta)
      else
        Arel::Nodes::Subtraction.new(coalesce, arel_delta)
      end
    end

    def remember_counter_update(klass, id, column, delta, column_type)
      Thread.current[:aggregated_updates][klass] ||= {}
      Thread.current[:aggregated_updates][klass][id] ||= { counters: {}, timestamps: [] }
      Thread.current[:aggregated_updates][klass][id][:counters][column] ||= { delta: 0, type: column_type }

      Thread.current[:aggregated_updates][klass][id][:counters][column][:delta] += delta
    end

    def remember_timestamp_update(klass, id, column)
      Thread.current[:aggregated_updates][klass] ||= {}
      Thread.current[:aggregated_updates][klass][id] ||= { counters: {}, timestamps: [] }

      Thread.current[:aggregated_updates][klass][id][:timestamps] << column
    end
  end
end
