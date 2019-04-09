require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/module/attribute_accessors'
require_relative 'reconciler/reconciliation'

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
  end
end
