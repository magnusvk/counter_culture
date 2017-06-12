source "https://rubygems.org"
# Add dependencies required to use your gem here.
# Example:
#   gem "activesupport", ">= 2.3.5"

gem "after_commit_action", "~> 1.0"
gem "activerecord", ">= 3.0.0"
gem "activesupport", ">= 3.0.0"

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development, :test do
  gem "rake"

  rails = case ENV["RAILS_VERSION"]
  when "master"
    {github: "rails/rails"}
  when nil, ""
    ">= 3.1.0"
  else
    "~> #{ENV["RAILS_VERSION"]}"
  end
  gem "rails", rails

  gem "rspec", "~> 3.0"
  gem "awesome_print"
  gem "timecop"

  # to test the integration
  gem "paranoia"
  gem "paper_trail"
end

group :development do
  gem "rdoc", "~> 3.12"
  gem "bundler", ">= 1.2.0"
  gem "jeweler", "~> 2.1"
end

group :test do
  gem "sqlite3"
  gem "rspec-extra-formatters"
  gem "database_cleaner", ">= 1.1.1"
end
