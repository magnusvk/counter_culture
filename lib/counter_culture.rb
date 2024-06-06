require 'active_support/concern'
require 'active_support/lazy_load_hooks'

require 'counter_culture/version'
require 'counter_culture/extensions'
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

    # aggregate the updates for each target record and execute SQL queries
    Thread.current[:aggregated_updates].each do |klass, attrs|
      attrs.each do |rec_id, updates|
        updated_columns = updates.map do |operation, value|
          value = value.call if value.is_a?(Proc)
          %Q{#{operation} #{value.is_a?(String) ? "'#{value}'" : value}} unless value == 0
        end.compact

        if updated_columns.any?
          klass
            .where(Thread.current[:primary_key_map][klass] => rec_id)
            .update_all(updated_columns.join(', '))
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
