source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in counter_culture.gemspec
gemspec

rails_version = ENV['RAILS_VERSION'].to_s

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development, :test do
  if rails_version == 'master'
    gem 'rails', github: 'rails/rails'
  elsif rails_version != ''
    gem 'rails', rails_version
  end

  # Both the paranoia and discard integrations require Rails > 4.2
  # Actually parsing the resolved rails version is complicated, so
  # we're basing this on the incompatible Rails version strings from
  # .travis.yml
  unless ['~> 3.2.0', '~> 4.0.0', '~> 4.1.0'].include?(rails_version)
    gem 'discard'
    gem 'paranoia'
  end

  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3.0')
    gem 'paper_trail', '< 9.0.0'
  else
    gem 'paper_trail'
  end
end
