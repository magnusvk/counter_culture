require 'after_commit_action'
require 'active_support/concern'

require 'counter_culture/helpers'
require 'counter_culture/counter'
require 'counter_culture/reconciler'

module CounterCulture
end

# extend ActiveRecord with our own code here
::ActiveRecord::Base.send :include, CounterCulture::Helpers
