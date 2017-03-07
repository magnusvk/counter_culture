module CounterCulture
  class Collection
    include Enumerable

    def initialize(arr=Array.new)
      @arr = arr
    end

    def fix_counts(options={})
      options[:exclude] = [options[:exclude]] if options[:exclude] && !options[:exclude].is_a?(Enumerable)
      options[:exclude] = options[:exclude].try(:map) {|x| x.is_a?(Enumerable) ? x : [x] }
      options[:only] = [options[:only]] if options[:only] && !options[:only].is_a?(Enumerable)
      options[:only] = options[:only].try(:map) {|x| x.is_a?(Enumerable) ? x : [x] }

      flat_map do |counter|
        next if options[:exclude] && options[:exclude].include?(counter.relation)
        next if options[:only] && !options[:only].include?(counter.relation)

        reconciler = CounterCulture::Reconciler.new(counter, options.slice(:skip_unsupported))
        reconciler.reconcile!
        reconciler.changes
      end.compact
    end

    def increment_counters(obj)
      each { |counter| counter.change_counter_cache(obj, :increment => true) }
    end

    def decrement_counters(obj)
      each { |counter| counter.change_counter_cache(obj, :increment => false) }
    end

    def update_counters(obj)
      each { |counter| 
        # figure out whether the applicable counter cache changed (this can happen
        # with dynamic column names)
        counter_cache_name_was = counter.counter_cache_name_for(counter.previous_model(obj))
        counter_cache_name = counter.counter_cache_name_for(obj)

        if obj.send("#{counter.first_level_relation_foreign_key}_changed?") ||
          (counter.delta_column && obj.send("#{counter.delta_column}_changed?")) ||
          counter_cache_name != counter_cache_name_was

          # increment the counter cache of the new value
          counter.change_counter_cache(obj, :increment => true, :counter_column => counter_cache_name)
          # decrement the counter cache of the old value
          counter.change_counter_cache(obj, :increment => false, :was => true, :counter_column => counter_cache_name_was)
        end
      }
    end

    def each(&block)
      @arr.each(&block) if block_given?
    end

    def <<(v)
      @arr << v
    end

    def +(y)
      raise unless y.is_a?(self.class)

      self.class.new(@arr + y.values)
    end

    protected

    def values
      @arr
    end
  end
end