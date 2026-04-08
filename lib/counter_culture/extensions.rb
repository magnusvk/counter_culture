module CounterCulture
  module Extensions
    extend ActiveSupport::Concern

    module ClassMethods
      # this holds all configuration data
      def after_commit_counter_cache
        config = @after_commit_counter_cache || []
        if superclass.respond_to?(:after_commit_counter_cache) && superclass.after_commit_counter_cache
          config = superclass.after_commit_counter_cache + config
        end
        config
      end

      # called to configure counter caches
      def counter_culture(relation, options = {})
        unless @after_commit_counter_cache
          # initialize callbacks only once
          after_create :_update_counts_after_create
          before_destroy :_update_counts_before_destroy
          after_update :_update_counts_after_update

          if respond_to?(:before_real_destroy) &&
              instance_methods.include?(:paranoia_destroyed?)
            before_real_destroy :_update_counts_before_real_destroy
          end

          if respond_to?(:before_restore)
            before_restore :_update_counts_before_restore
          end

          if defined?(Discard::Model) && include?(Discard::Model)
            before_discard :_update_counts_before_discard
            before_undiscard :_update_counts_before_undiscard
          end

          # we keep a list of all counter caches we must maintain
          @after_commit_counter_cache = []
        end

        if options[:column_names] && !(options[:column_names].is_a?(Hash) || options[:column_names].is_a?(Proc))
          raise ArgumentError.new(
            ":column_names must be a Hash of conditions and column names, " \
            "or a Proc that when called returns such a Hash"
          )
        end

        # add the counter to our collection
        @after_commit_counter_cache << Counter.new(self, relation, options)
      end

      # checks all of the declared counter caches on this class for correctnes based
      # on original data; if the counter cache is incorrect, sets it to the correct
      # count
      #
      # options:
      #   { :exclude => list of relations to skip when fixing counts,
      #     :only => only these relations will have their counts fixed,
      #     :column_name => only this column will have its count fixed
      #     :polymorphic_classes => specify the class(es) to update in polymorphic associations }
      # returns: a list of fixed record as an array of hashes of the form:
      #   { :entity => which model the count was fixed on,
      #     :id => the id of the model that had the incorrect count,
      #     :what => which column contained the incorrect count,
      #     :wrong => the previously saved, incorrect count,
      #     :right => the newly fixed, correct count }
      #
      def counter_culture_fix_counts(options = {})
        raise "No counter cache defined on #{name}" unless @after_commit_counter_cache

        options[:exclude] = Array(options[:exclude]) if options[:exclude]
        options[:exclude] = options[:exclude].try(:map) {|x| x.is_a?(Enumerable) ? x : [x] }
        options[:only] = [options[:only]] if options[:only] && !options[:only].is_a?(Enumerable)
        options[:only] = options[:only].try(:map) {|x| x.is_a?(Enumerable) ? x : [x] }

        @after_commit_counter_cache.flat_map do |counter|
          next if options[:exclude] && options[:exclude].include?(counter.relation)
          next if options[:only] && !options[:only].include?(counter.relation)

          reconciler_options = %i(context batch_size column_name db_connection_builder finish skip_unsupported start touch verbose where polymorphic_classes)

          reconciler = CounterCulture::Reconciler.new(counter, options.slice(*reconciler_options))
          reconciler.reconcile!
          reconciler.changes
        end.compact
      end

      def skip_counter_culture_updates
        return unless block_given?

        counter_culture_updates_was = Thread.current[:skip_counter_culture_updates]
        Thread.current[:skip_counter_culture_updates] = Array(counter_culture_updates_was) + [self]
        yield
      ensure
        Thread.current[:skip_counter_culture_updates] = counter_culture_updates_was
      end
    end

    private

    def _update_counts_after_create
      self.class.after_commit_counter_cache.each do |counter|
        counter.change_counter_cache(self, :increment => true)
      end
    end

    # before_destroy: For Paranoia models this is a soft-delete; for all others
    # (including Discard) it is a hard-destroy.
    def _update_counts_before_destroy
      # If destroy is called again on an already-destroyed record, don't double-decrement
      return if destroyed?

      if respond_to?(:paranoia_destroyed?)
        # Paranoia: destroy = soft-delete
        # If already soft-deleted, this is a redundant destroy call — don't decrement again
        return if paranoia_destroyed?
        _decrement_counters(skip_include_soft_deleted: true)
      elsif destroyed_for_counter_culture?
        # Discard: hard-destroy of already-discarded record
        _decrement_counters(only_include_soft_deleted: true)
      else
        # Regular model or undiscarded Discard: hard-destroy
        _decrement_counters
      end
    end

    # before_real_destroy (Paranoia only)
    def _update_counts_before_real_destroy
      if paranoia_destroyed?
        # Was already soft-deleted: only include_soft_deleted counters remain
        _decrement_counters(only_include_soft_deleted: true)
      else
        # Not soft-deleted: decrement all counters
        _decrement_counters
      end
    end

    # before_restore (Paranoia only)
    def _update_counts_before_restore
      # Only increment if the record is currently soft-deleted (idempotency guard)
      return unless deleted?
      _increment_counters(skip_include_soft_deleted: true)
    end

    # before_discard (Discard only)
    def _update_counts_before_discard
      # Only decrement if not already discarded (idempotency guard)
      return if discarded?
      _decrement_counters(skip_include_soft_deleted: true)
    end

    # before_undiscard (Discard only)
    def _update_counts_before_undiscard
      # Only increment if currently discarded (idempotency guard)
      return unless discarded?
      _increment_counters(skip_include_soft_deleted: true)
    end

    def _update_counts_after_update
      self.class.after_commit_counter_cache.each do |counter|
        # Don't update regular counters for soft-deleted records, but
        # include_soft_deleted counters must still track association changes
        next if destroyed_for_counter_culture? && !counter.include_soft_deleted

        counter_cache_name_was = counter.counter_cache_name_for(counter.previous_model(self))
        counter_cache_name = counter.counter_cache_name_for(self)

        if counter.first_level_relation_changed?(self) ||
            (counter.delta_column && counter.attribute_changed?(self, counter.delta_column)) ||
            counter_cache_name != counter_cache_name_was

          counter.change_counter_cache(self, :increment => true, :counter_column => counter_cache_name)
          counter.change_counter_cache(self, :increment => false, :was => true, :counter_column => counter_cache_name_was)
        end
      end
    end

    def _decrement_counters(skip_include_soft_deleted: false, only_include_soft_deleted: false)
      self.class.after_commit_counter_cache.each do |counter|
        next if skip_include_soft_deleted && counter.include_soft_deleted
        next if only_include_soft_deleted && !counter.include_soft_deleted
        counter.change_counter_cache(self, :increment => false)
      end
    end

    def _increment_counters(skip_include_soft_deleted: false)
      self.class.after_commit_counter_cache.each do |counter|
        next if skip_include_soft_deleted && counter.include_soft_deleted
        counter.change_counter_cache(self, :increment => true)
      end
    end

    def destroyed_for_counter_culture?
      if respond_to?(:paranoia_destroyed?)
        paranoia_destroyed?
      elsif defined?(Discard::Model) && self.class.include?(Discard::Model)
        discarded?
      else
        false
      end
    end

  end
end
