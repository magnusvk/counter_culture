require 'active_support/concern'
require 'active_support/lazy_load_hooks'

require 'counter_culture/version'
require 'counter_culture/extensions'
require 'counter_culture/configuration'
require 'counter_culture/counter'
require 'counter_culture/reconciler'
require 'counter_culture/skip_updates'

module CounterCulture
  mattr_accessor :batch_size
  self.batch_size = 1000

  def self.config
    yield(self) if block_given?
    self
  end

  def self.aggregate_counter_updates
    return unless block_given?

    Thread.current[:aggregate_counter_updates] = true
    Thread.current[:aggregated_updates] = {}
    Thread.current[:primary_key_map] = {}

    result = yield

    # aggregate the updates for each target record and execute SQL queries using Arel
    Thread.current[:aggregated_updates].each do |klass, attrs|
      attrs.each do |rec_id, updates|
        arel_updates = {}

        # Build counter updates
        updates[:counters].each do |column, info|
          next if info[:delta] == 0
          arel_updates[column] = Counter.build_arel_counter_expr(klass, column, info[:delta], info[:type])
        end

        # Build timestamp updates (compute timestamp at execution time)
        if updates[:timestamps].any?
          current_time = klass.send(:current_time_from_proper_timezone)
          updates[:timestamps].each do |column|
            arel_updates[column] = current_time
          end
        end

        if arel_updates.any?
          primary_key = Thread.current[:primary_key_map][klass]

          conditions =
            Array.wrap(primary_key)
                .zip(Array.wrap(rec_id))
                .to_h

          klass.where(conditions).update_all(arel_updates)
        end
      end
    end

    result
  ensure
    Thread.current[:aggregate_counter_updates] = false
    Thread.current[:aggregated_updates] = nil
    Thread.current[:primary_key_map] = nil
  end
end

# extend ActiveRecord with our own code here
ActiveSupport.on_load(:active_record) do
  include CounterCulture::Extensions
  include CounterCulture::SkipUpdates
end
