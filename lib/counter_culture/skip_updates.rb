module CounterCulture
  module SkipUpdates
    private

    %i[
      _update_counts_after_create
      _update_counts_after_destroy
      _update_counts_after_update
      _update_counts_after_real_destroy
      _update_counts_after_restore
      _update_counts_after_discard
      _update_counts_after_undiscard
    ].each do |method_name|
      define_method(method_name) do
        unless Array(Thread.current[:skip_counter_culture_updates]).include?(self.class)
          super()
        end
      end
    end
  end
end
