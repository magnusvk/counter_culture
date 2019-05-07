[
  '4.2',
  '5.0',
  '5.1',
  '5.2',
].each do |rails_version|
  appraise "rails-#{rails_version}" do
    gem 'rails', "~> #{rails_version}.0"

    gem 'pg'
    gem 'mysql2'
  end
end
