#! /bin/bash

set -e
source /usr/local/share/chruby/chruby.sh

for RUBY_VERSION in 2.3.8 2.4.6 2.5.5 2.6.2; do
  chruby $RUBY_VERSION
  ruby --version

  (bundle check > /dev/null || bundle install)
  gem install appraisal
  bundle exec appraisal install

  for DB in mysql2 postgresql sqlite3; do
    echo "RUBY $RUBY_VERSION; DB $DB"
    DB=$DB bundle exec appraisal rspec spec/counter_culture_spec.rb
  done
done
