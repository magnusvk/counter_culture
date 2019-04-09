require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/module/attribute_accessors'
require_relative 'table_name_helpers'

module CounterCulture
  class Reconciler
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
