ENV['RAILS_ENV'] = 'test'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require "rails_app/config/environment"

require 'rspec'
require 'counter_culture'

load "#{File.dirname(__FILE__)}/schema.rb"

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = 1

RSpec.configure do |config|
  config.fail_fast = true
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end
