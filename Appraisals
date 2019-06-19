[
  4.2,
  5.0,
  5.1,
  5.2,
].each do |rails_version|
  appraise "rails-#{rails_version}" do
    gem 'rails', "~> #{rails_version}.0"

    gem 'pg', rails_version < 5 ? '~> 0.15' : '~> 1.0'
    gem 'mysql2'
    gem 'sqlite3', rails_version < 5.2 ? '~> 1.3.0' : '~> 1.4'
  end
end
