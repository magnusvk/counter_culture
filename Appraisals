%w[
  4.2
  5.0
  5.1
  5.2
  6.0
  6.1
].each do |rails_version|
  gem_rails_version = Gem::Version.new(rails_version)
  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.5.0') &&
      gem_rails_version >= Gem::Version.new('6.0.0.beta')

    # Rails 6 requires Ruby >= 2.5
    next
  end
  appraise "rails-#{rails_version}" do
    gem 'rails', "~> #{rails_version}.0"

    if gem_rails_version < Gem::Version.new('5.0')
      gem 'pg',  '~> 0.15'
    else
      gem 'pg'
    end
    gem 'mysql2'
    if gem_rails_version < Gem::Version.new('5.2')
      gem 'sqlite3', '~> 1.3.0'
    else
      gem 'sqlite3'
    end
    if gem_rails_version < Gem::Version.new('5.0')
      gem 'bigdecimal', '~> 1.3.5'
    end
  end
end
