module CounterCulture
  module Extensions
    extend ActiveSupport::Concern
    
    module ClassMethods
      # this holds all configuration data
      def after_commit_counter_cache
        config = @after_commit_counter_cache || Collection.new
        if superclass.respond_to?(:after_commit_counter_cache) && superclass.after_commit_counter_cache
          config = superclass.after_commit_counter_cache + config
        end
        config
      end

      # called to configure counter caches
      def counter_culture(relation, options = {})
        unless @after_commit_counter_cache
          include AfterCommitAction unless include?(AfterCommitAction)

          # initialize callbacks only once
          after_create :_update_counts_after_create
          after_destroy :_update_counts_after_destroy
          after_update :_update_counts_after_update

          # we keep a list of all counter caches we must maintain
          @after_commit_counter_cache = Collection.new
        end

        if options[:column_names] && !options[:column_names].is_a?(Hash)
          raise ":column_names must be a Hash of conditions and column names" 
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
      #     :only => only these relations will have their counts fixed }
      # returns: a list of fixed record as an array of hashes of the form:
      #   { :entity => which model the count was fixed on,
      #     :id => the id of the model that had the incorrect count,
      #     :what => which column contained the incorrect count,
      #     :wrong => the previously saved, incorrect count,
      #     :right => the newly fixed, correct count }
      #
      def counter_culture_fix_counts(options = {})
        raise "No counter cache defined on #{name}" unless @after_commit_counter_cache

        @after_commit_counter_cache.fix_counts(options)
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
        self.class.after_commit_counter_cache.increment_counters(self)
      end
    end

    # called by after_destroy callback
    def _update_counts_after_destroy
      _wrap_in_counter_culture_active do
        self.class.after_commit_counter_cache.decrement_counters(self)
      end
    end

    # called by after_update callback
    def _update_counts_after_update
      _wrap_in_counter_culture_active do
        self.class.after_commit_counter_cache.update_counters(self)
      end
    end

  end
end