require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/module/attribute_accessors'
require_relative 'table_name_helpers'
require_relative 'relation_join'

module CounterCulture
  class Reconciler
    class Reconciliation
      include TableNameHelpers

      attr_reader :counter, :options, :relation_class

      delegate :model, :relation, :full_primary_key, :relation_reflect, :polymorphic?, to: :counter
      delegate :connection, to: :relation_class
      delegate :quote_table_name, to: :connection
      delegate(*CounterCulture::Counter::CONFIG_OPTIONS, to: :counter)

      def self.perform(counter, changes_holder, options, relation_class)
        new(counter, changes_holder, options, relation_class).perform
      end

      def initialize(counter, changes_holder, options, relation_class)
        @counter = counter
        @options = options
        @relation_class = relation_class
        @changes_holder = changes_holder
      end

      def perform
        # if we're provided a custom set of column names with conditions, use them; just use the
        # column name otherwise
        # which class does this relation ultimately point to? that's where we have to start
        counter_column_names = column_names || { nil => counter_cache_name }

        # iterate over all the possible counter cache column names
        counter_column_names.each do |where, column_name|
          # if the column name is nil, that means those records don't affect
          # counts; we don't need to do anything in that case. but we allow
          # specifying that condition regardless to make the syntax less
          # confusing
          next unless column_name

          # select join column and count (from above) as well as cache column ('column_name') for later comparison
          counts_query = relation_class.select(
            "#{relation_class_table_name}.#{relation_class.primary_key}, " \
            "#{relation_class_table_name}.#{relation_reflect(relation).association_primary_key(relation_class)}, " \
            "#{count_select} AS count, " \
            "MAX(#{relation_class_table_name}.#{column_name}) AS #{column_name}"
          )

          relation_joins(where).each do |join|
            # apply each join clause to the query
            counts_query = counts_query.joins(join.join_clause)
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

      def relation_class_table_name
        @relation_class_table_name ||= quote_table_name(relation_class.table_name)
      end

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

      def relation_joins(where)
        # we need to work our way back from the end-point of the relation to
        # this class itself; make a list of arrays pointing to the
        # second-to-last, third-to-last, etc.
        relation.length.downto(1).map do |chunk_size|
          RelationJoin.new(counter, relation_class, relation[0, chunk_size], where)
        end
      end

      class RelationJoin
        include TableNameHelpers

        attr_reader :counter, :reflection, :relation_class, :where, :cur_relation

        delegate :model, :relation_reflect, :polymorphic?, to: :counter
        delegate :connection, to: :relation_class
        delegate :quote_table_name, to: :connection

        def initialize(counter, relation_class, cur_relation, where)
          @counter = counter
          @relation_class = relation_class
          @where = where
          @cur_relation = cur_relation
          @reflection = relation_reflect(cur_relation)
        end

        def join_clause
          clauses = [
            basic_join_clause,
            sti_clause,
            polymorphic_clause
          ]

          if counting_join?
            clauses.push(
              where_clause, # conditions must be applied to the join on which we are counting
              paranoia_clause, # respect the deleted_at column if it exists
              discard_clause, # respect the discard column if it exists
            )
          end

          clauses.compact.join(' AND ')
        end

        private

        def counting_join?
          cur_relation.size == 1
        end

        def basic_join_clause
          "LEFT JOIN #{target_table} AS #{target_table_alias} "\
            "ON #{source_table}.#{source_table_key} = #{target_table_alias}.#{target_table_key}"
        end

        # adds 'type' condition to JOIN clause if the current model is a
        # child in a Single Table Inheritance
        def sti_clause
          return unless sti_child

          "#{target_table}.type IN ('#{model.name}')"
        end

        # adds 'type' condition to JOIN clause if the current model is a
        # polymorphic relation
        # NB only works for one-level relations
        def polymorphic_clause
          return unless polymorphic?

          "#{target_table}.#{foreign_type} = '#{relation_class.name}'"
        end

        def where_clause
          return unless where

          "(#{model.send(:sanitize_sql_for_conditions, where)})"
        end

        def paranoia_clause
          return unless using_paranoia?

          "#{target_table_alias}.deleted_at IS NULL"
        end

        def discard_clause
          return unless using_discard?

          "#{target_table_alias}.#{model.discard_column} IS NULL"
        end

        def using_paranoia?
          model.column_names.include?('deleted_at')
        end

        def using_discard?
          defined?(Discard::Model) &&
            model.include?(Discard::Model) &&
            model.column_names.include?(model.discard_column.to_s)
        end

        def sti_child
          reflection.active_record.column_names.include?('type') &&
            !model.descends_from_active_record?
        end

        def foreign_type
          polymorphic? && reflection.foreign_type
        end

        def source_table
          quote_table_name(
            if polymorphic?
              # NB: polymorphic only supports one level of relation (at present)
              relation_class.table_name
            else
              reflection.table_name
            end
          )
        end

        def target_table
          quote_table_name(reflection.active_record.table_name)
        end

        def target_table_alias
          table_alias = parameterize(target_table)

          if relation_class.table_name == reflection.active_record.table_name
            # join with alias to avoid ambiguous table name in
            # self-referential models
            table_alias += "_#{table_alias}"
          end

          table_alias
        end

        def association_primary_key
          # NB: polymorphic only supports one level of relation (at present)
          return reflection.association_primary_key(relation_class) if polymorphic?

          reflection.association_primary_key
        end

        def source_table_key
          return association_primary_key if reflection.belongs_to?

          reflection.foreign_key
        end

        def target_table_key
          return reflection.foreign_key if reflection.belongs_to?

          association_primary_key
        end
      end
    end
  end
end
