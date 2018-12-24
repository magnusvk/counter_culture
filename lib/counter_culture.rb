require 'after_commit_action'
require 'active_support/concern'
require 'active_support/lazy_load_hooks'

require 'counter_culture/extensions'
require 'counter_culture/counter'
require 'counter_culture/reconciler'
require 'counter_culture/active_record/associations/has_many_association'

module CounterCulture
  mattr_accessor :batch_size
  self.batch_size = 1000

  def self.config
    yield(self) if block_given?
    self
  end
end

# extend ActiveRecord with our own code here
ActiveSupport.on_load(:active_record) do
  include CounterCulture::Extensions
  ActiveRecord::Associations::HasManyAssociation.send :prepend, CounterCulture::ActiveRecord::Associations::HasManyAssociation
end
