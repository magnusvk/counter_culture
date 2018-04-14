#! /bin/bash

set -e

source /usr/local/share/chruby/chruby.sh

for RUBY_VERSION in "2.2.10" "2.3.7" "2.4.4" "2.5.1"; do
  chruby $RUBY_VERSION
  for RAILS_VERSION in "~> 3.2.0" "~> 4.0.0" "~> 4.1.0" "~> 4.2.0" "~> 5.0.0" "= 5.1.4" "= 5.1.5" "~> 5.1.6" "~> 5.2.0"; do
    echo "Ruby $RUBY_VERSION; Rails $RAILS_VERSION"
    if ( [ "$RUBY_VERSION" == "2.2.10" ] && ( [ "$RAILS_VERSION" == "= 5.1.4" ] || [ "$RAILS_VERSION" == "= 5.1.5" ] ) ) || \
        ( ( [ "$RUBY_VERSION" == "2.4.4" ] || ( [ "$RUBY_VERSION" == "2.5.1" ] ) && ( [ "$RAILS_VERSION" == "~> 3.2.0" ] || [ "$RAILS_VERSION" == "~> 4.0.0" ] || [ "$RAILS_VERSION" == "~> 4.1.0" ] ) ) ); then
      echo "Skipping"
      continue
    fi
    export RAILS_VERSION
    type bundle > /dev/null || gem install bundler
    bundle update
    bundle exec rspec spec
  done
done

unset RAILS_VERSION
