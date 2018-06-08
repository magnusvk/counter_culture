require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/module/attribute_accessors'

module CounterCulture
  class Reconciler
    ACTIVE_RECORD_VERSION = Gem.loaded_specs["activerecord"].version

    attr_reader :counter, :options, :changes

    delegate :model, :relation, :full_primary_key, :relation_reflect, :polymorphic?, :to => :counter
    delegate *CounterCulture::Counter::CONFIG_OPTIONS, :to => :counter

    def initialize(counter, options={})
      @counter, @options = counter, options

      @changes = []
      @reconciled = false
    end

    def reconcile!
      return false if @reconciled

      if options[:skip_unsupported]
        return false if (foreign_key_values || (counter_cache_name.is_a?(Proc) && !column_names) || delta_magnitude.is_a?(Proc))
      else
        raise "Fixing counter caches is not supported when using :foreign_key_values; you may skip this relation with :skip_unsupported => true" if foreign_key_values
        raise "Must provide :column_names option for relation #{relation.inspect} when :column_name is a Proc; you may skip this relation with :skip_unsupported => true" if counter_cache_name.is_a?(Proc) && !column_names
        raise "Fixing counter caches is not supported when :delta_magnitude is a Proc; you may skip this relation with :skip_unsupported => true" if delta_magnitude.is_a?(Proc)
      end

      associated_model_classes.each do |associated_model_class|
        Reconciliation.new(counter, changes, options, associated_model_class).perform
      end

      @reconciled = true
    end

    private

    def associated_model_classes
      if polymorphic?
        polymorphic_associated_model_classes
      else
        [associated_model_class]
      end
    end

    def polymorphic_associated_model_classes
      foreign_type_field = relation_reflect(relation).foreign_type
      model.pluck(Arel.sql("DISTINCT #{foreign_type_field}")).compact.map(&:constantize)
    end

    def associated_model_class
      counter.relation_klass(counter.relation)
    end

    class Reconciliation
      attr_reader :counter, :options, :relation_class

      delegate :model, :relation, :full_primary_key, :relation_reflect, :polymorphic?, :to => :counter
      delegate *CounterCulture::Counter::CONFIG_OPTIONS, :to => :counter

      def initialize(counter, changes_holder, options, relation_class)
        @counter, @options, = counter, options
        @relation_class = relation_class
        @changes_holder = changes_holder
      end

      def perform
        # if we're provided a custom set of column names with conditions, use them; just use the
        # column name otherwise
        # which class does this relation ultimately point to? that's where we have to start

        scope = relation_class

        counter_column_names = column_names || {nil => counter_cache_name}

        # iterate over all the possible counter cache column names
        counter_column_names.each do |where, column_name|
          # if the column name is nil, that means those records don't affect
          # counts; we don't need to do anything in that case. but we allow
          # specifying that condition regardless to make the syntax less
          # confusing
          next unless column_name

          relation_class_table_name = quote_table_name(relation_class.table_name)

          # select join column and count (from above) as well as cache column ('column_name') for later comparison
          counts_query = scope.select("#{relation_class_table_name}.#{relation_class.primary_key}, #{relation_class_table_name}.#{relation_reflect(relation).association_primary_key(relation_class)}, #{count_select} AS count, #{relation_class_table_name}.#{column_name}")

          # we need to join together tables until we get back to the table this class itself lives in
          join_clauses(where).each do |join|
            counts_query = counts_query.joins(join)
          end

          # iterate in batches; otherwise we might run out of memory when there's a lot of
          # instances and we try to load all their counts at once
          batch_size = options.fetch(:batch_size, CounterCulture.config.batch_size)

          counts_query.group(full_primary_key(relation_class)).find_in_batches(batch_size: batch_size) do |records|
            # now iterate over all the models and see whether their counts are right
            update_count_for_batch(column_name, records)
          end
        end
      end

      private

      def update_count_for_batch(column_name, records)
        ActiveRecord::Base.transaction do
          records.each do |record|
            count = record.read_attribute('count') || 0
            next if record.read_attribute(column_name) == count

            track_change(record, column_name, count)

            updates = []
            # this updates the actual counter
            updates << "#{column_name} = #{count}"
            # and here we update the timestamp, if so desired
            if options[:touch]
              current_time = record.send(:current_time_from_proper_timezone)
              timestamp_columns = record.send(:timestamp_attributes_for_update_in_model)
              timestamp_columns << options[:touch] if options[:touch] != true
              timestamp_columns.each do |timestamp_column|
                updates << "#{timestamp_column} = '#{current_time.to_formatted_s(:db)}'"
              end
            end

            relation_class.where(relation_class.primary_key => record.send(relation_class.primary_key)).update_all(updates.join(', '))
          end
        end
      end

      # keep track of what we fixed, e.g. for a notification email
      def track_change(record, column_name, count)
        @changes_holder << {
          :entity => relation_class.name,
          relation_class.primary_key.to_sym => record.send(relation_class.primary_key),
          :what => column_name,
          :wrong => record.send(column_name),
          :right => count
        }
      end

      def count_select
        # if a delta column is provided use SUM, otherwise use COUNT
        return @count_select if @count_select
        if delta_column
          @count_select = "SUM(COALESCE(#{self_table_name}.#{delta_column},0))"
        else
          @count_select = "COUNT(#{self_table_name}.#{model.primary_key})*#{delta_magnitude}"
        end
      end

      def self_table_name
        return @self_table_name if @self_table_name

        @self_table_name = parameterize(model.table_name)
        if relation_class.table_name == model.table_name
          @self_table_name = "#{@self_table_name}_#{@self_table_name}"
        end
        @self_table_name = quote_table_name(@self_table_name)
        @self_table_name
      end

      def join_clauses(where)
        # we need to work our way back from the end-point of the relation to
        # this class itself; make a list of arrays pointing to the
        # second-to-last, third-to-last, etc.
        reverse_relation = (1..relation.length).to_a.reverse.
          inject([]) { |a, i| a << relation[0, i]; a }

        # store joins in an array so that we can later apply column-specific
        # conditions
        join_clauses = reverse_relation.each_with_index.map do |cur_relation, index|
          reflect = relation_reflect(cur_relation)

          target_table = quote_table_name(reflect.active_record.table_name)
          target_table_alias = parameterize(target_table)
          if relation_class.table_name == reflect.active_record.table_name
            # join with alias to avoid ambiguous table name in
            # self-referential models
            target_table_alias += "_#{target_table_alias}"
          end

          if polymorphic?
            # NB: polymorphic only supports one level of relation (at present)
            association_primary_key = reflect.association_primary_key(relation_class)
            source_table = relation_class.table_name
          else
            association_primary_key = reflect.association_primary_key
            source_table = reflect.table_name
          end
          source_table = quote_table_name(source_table)

          source_table_key = association_primary_key
          target_table_key = reflect.foreign_key
          if !reflect.belongs_to?
            # a has_one relation flips the location of the keys on the tables
            # around
            (source_table_key, target_table_key) =
              [target_table_key, source_table_key]
          end

          joins_sql = "LEFT JOIN #{target_table} AS #{target_table_alias} "\
            "ON #{source_table}.#{source_table_key} = #{target_table_alias}.#{target_table_key}"
          # adds 'type' condition to JOIN clause if the current model is a
          # child in a Single Table Inheritance
          if reflect.active_record.column_names.include?('type') &&
              !model.descends_from_active_record?
            joins_sql += " AND #{target_table}.type IN ('#{model.name}')"
          end
          if polymorphic?
            # adds 'type' condition to JOIN clause if the current model is a
            # polymorphic relation
            # NB only works for one-level relations
            joins_sql += " AND #{target_table}.#{reflect.foreign_type} = '#{relation_class.name}'"
          end
          if index == reverse_relation.size - 1
            # conditions must be applied to the join on which we are counting
            if where
              joins_sql += " AND (#{model.send(:sanitize_sql_for_conditions, where)})"
            end
            # respect the deleted_at column if it exists
            if model.column_names.include?('deleted_at')
              joins_sql += " AND #{target_table_alias}.deleted_at IS NULL"
            end

            # respect the discard column if it exists
            if defined?(Discard::Model) &&
               model.include?(Discard::Model) &&
               model.column_names.include?(model.discard_column.to_s)

              joins_sql += " AND #{target_table_alias}.#{model.discard_column} IS NULL"
            end
          end
          joins_sql
        end
      end

      # This is only needed in relatively unusal cases, for example if you are
      # using Postgres with schema-namespaced tables. But then it's required,
      # and otherwise it's just a no-op, so why not do it?
      def quote_table_name(table_name)
        relation_class.connection.quote_table_name(table_name)
      end

      def parameterize(string)
        if ACTIVE_RECORD_VERSION < Gem::Version.new("5.0")
          string.parameterize('_')
        else
          string.parameterize(separator: '_')
        end
      end
    end
  end
end
