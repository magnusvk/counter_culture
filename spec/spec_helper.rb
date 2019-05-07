require 'bundler/setup'
require 'counter_culture'

ENV['RAILS_ENV'] = 'test'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'paper_trail'
require 'rails_app/config/environment'

require 'rspec'
require 'timecop'
require 'paper_trail/frameworks/rspec'

CI_TEST_RUN = (ENV['TRAVIS'] && 'TRAVIS') || (ENV['CIRCLECI'] && 'CIRCLE') || ENV["CI"] && 'CI'

begin
  was, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false unless ENV['SHOW_MIGRATION_MESSAGES']
  load "#{File.dirname(__FILE__)}/schema.rb"
ensure
  ActiveRecord::Migration.verbose = was unless ENV['SHOW_MIGRATION_MESSAGES']
end

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = 1

RSpec.configure do |config|
  config.fail_fast = true unless CI_TEST_RUN
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
