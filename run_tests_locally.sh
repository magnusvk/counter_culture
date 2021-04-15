#! /bin/bash

set -e
source /usr/local/share/chruby/chruby.sh

for RUBY_VERSION in 2.5.9 2.6.7 2.7.3 3.0.1; do
  chruby $RUBY_VERSION
  ruby --version

  gem install bundler -v '1.17.3'

  (bundle _1.17.3_ check > /dev/null || bundle _1.17.3_ install)
  gem install appraisal
  bundle exec appraisal install

  for DB in mysql2 postgresql sqlite3; do
    echo "RUBY $RUBY_VERSION; DB $DB"
    DB=$DB bundle exec appraisal rspec spec/counter_culture_spec.rb
  done
done
