# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'counter_culture/version'

Gem::Specification.new do |spec|
  spec.name          = 'counter_culture'
  spec.version       = CounterCulture::VERSION
  spec.authors       = ['Magnus von Koeller']
  spec.email         = ['magnus@vonkoeller.de']

  spec.summary       = 'Rails counter cache on steroids'
  spec.description   = %q{counter_culture provides turbo-charged counter caches
    that are kept up-to-date not just on create and destroy, that support
    multiple levels of indirection through relationships, allow dynamic column
    names and that avoid deadlocks by updating in the after_commit callback.}
  spec.homepage      = 'https://github.com/magnusvk/counter_culture'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activerecord', '>= 3.0.0'
  spec.add_runtime_dependency 'activesupport', '>= 3.0.0'
  spec.add_runtime_dependency 'after_commit_action', '~> 1.0'

  spec.add_development_dependency 'bundler', '~> 1.0'
  spec.add_development_dependency 'pry-byebug', '~> 3.6'
  spec.add_development_dependency 'rails', '>= 3.1.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'timecop', '>= 0'
  spec.add_development_dependency 'sqlite3', '>= 0'
  spec.add_development_dependency 'database_cleaner', '>= 1.1.1'
end
