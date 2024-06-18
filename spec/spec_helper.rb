require 'simplecov'
SimpleCov.start

require 'bundler/setup'
require 'counter_culture'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rails/all'

module PapertrailSupport
  def self.supported_here?
    true
  end
end

module DynamicAfterCommit
  def self.update_counter_cache_in_transaction(&block)
    Thread.current[:update_counter_cache_in_transaction] = true
    yield
  ensure
    Thread.current[:update_counter_cache_in_transaction] = nil
  end
end

require 'rspec'
require 'timecop'

if PapertrailSupport.supported_here?
  require 'paper_trail'
  require "paper_trail/frameworks/active_record"
  require 'paper_trail/frameworks/active_record/models/paper_trail/version'
  require 'paper_trail/frameworks/rspec'
end

case ENV['DB']
when 'postgresql'
  require 'pg'
when 'mysql2'
  require 'mysql2'
else
  require 'sqlite3'
end

CI_TEST_RUN = (ENV['TRAVIS'] && 'TRAVIS') \
                || (ENV['CIRCLECI'] && 'CIRCLE') \
                || ENV['CI'] \
                && 'CI'

DB_CONFIG = {
  defaults: {
    pool: 5,
    timeout: 5000,
    host: 'localhost',
    database: CI_TEST_RUN ? 'circle_test' : 'counter_culture_test',
  },
  sqlite3: {
    adapter: 'sqlite3',
    database: 'db/test.sqlite3',
  },
  mysql2: {
    adapter: 'mysql2',
    username: 'root',
    encoding: 'utf8',
    collation: 'utf8_unicode_ci',
    host: '127.0.0.1',
    port: '3306',
  },
  postgresql: {
    adapter: 'postgresql',
    username: CI_TEST_RUN ? 'postgres' : '',
    min_messages: 'ERROR',
  }
}.with_indifferent_access.freeze

if Gem::Version.new(Rails.version) < Gem::Version.new('5.0.0')
  ActiveRecord::Base.raise_in_transactional_callbacks = true
end

ActiveRecord::Base.establish_connection(
  DB_CONFIG[:defaults].merge(DB_CONFIG[ENV['DB'] || :sqlite3])
)

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

module DbRandom
  def db_random
    Arel.sql(ENV['DB'] == 'mysql2' ? 'rand()' : 'random()')
  end
end

# Spec for checking the number of queries executed within the block
def expect_queries(num = 1, filter: "", &block)
  queries = []

  callback = lambda do |_name, _start, _finish, _id, payload|
    next if payload[:sql].match?(/^SELECT a\.attname/)
    next unless payload[:sql].match?(/^SELECT|UPDATE|INSERT/)

    payload[:sql].gsub!(%Q{\"}, "`") # to remove differences between DB adaptors

    matches_filter = filter.is_a?(Regexp) ? payload[:sql].match?(filter) : payload[:sql] == filter
    next unless matches_filter

    queries.push(payload[:sql])
  end

  ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)

  expect(queries.size).to eq(num), "#{queries.size} instead of #{num} queries were executed. #{"\nQueries:\n#{queries.join("\n")}" unless queries.empty?}"
end

RSpec.configure do |config|
  config.include DbRandom
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
