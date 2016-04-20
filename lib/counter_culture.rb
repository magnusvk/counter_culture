require 'after_commit_action'
require 'active_support/concern'

require 'counter_culture/extensions'
require 'counter_culture/counter'
require 'counter_culture/reconciler'

module CounterCulture
  mattr_accessor :batch_size
  self.batch_size = 1000
end

# extend ActiveRecord with our own code here
::ActiveRecord::Base.send :include, CounterCulture::Extensions
