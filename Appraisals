%w[
  5.2
  6.0
  6.1
  7.0
  7.1
].each do |rails_version|
  appraise "rails-#{rails_version}" do
    gem 'rails', "~> #{rails_version}.0"
    if Gem::Version.new(rails_version) < Gem::Version.new("7.2")
      gem 'sqlite3', "~> 1.4"
    end
  end
end
