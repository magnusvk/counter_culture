require 'database_cleaner'

DatabaseCleaner.strategy = :deletion

RSpec.configure do |config|
  config.before(:each) do
    DatabaseCleaner.clean
  end
end
