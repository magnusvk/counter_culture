ENV['RAILS_ENV'] = 'test'
CI_TEST_RUN = (ENV['TRAVIS'] && 'TRAVIS') || (ENV['CIRCLECI'] && 'CIRCLE') || ENV['CI'] && 'CI'

require 'bundler/setup'
require 'rails_app/config/environment'
require 'pry'
require 'rspec'
require 'timecop'
require 'database_cleaner'
require 'paper_trail/frameworks/rspec'
require 'counter_culture'

DatabaseCleaner.strategy = :deletion

begin
  was, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false unless ENV['SHOW_MIGRATION_MESSAGES']
  load "#{File.dirname(__FILE__)}/schema.rb"
ensure
  ActiveRecord::Migration.verbose = was unless ENV['SHOW_MIGRATION_MESSAGES']
end

ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.logger.level = 1

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.fail_fast = true unless CI_TEST_RUN
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end
