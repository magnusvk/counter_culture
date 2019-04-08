#! /bin/bash

set -e

source /usr/local/share/chruby/chruby.sh

for RUBY_VERSION in "2.3.8" "2.4.6" "2.5.5" "2.6.2"; do
  chruby $RUBY_VERSION
  for RAILS_VERSION in "~> 4.2.0" "~> 5.0.0" "= 5.1.4" "= 5.1.5" "~> 5.1.6" "~> 5.2.0"; do
    echo "Ruby $RUBY_VERSION; Rails $RAILS_VERSION"
    if ( [ "$RAILS_VERSION" == "~> 4.2.0" ] ); then
      BUNDLE_VERSION='1.17.3'
    else
      BUNDLE_VERSION='2.0.1'
    fi
    export RAILS_VERSION
    gem install bundler -v "$BUNDLE_VERSION"
    if [ -f Gemfile.lock ]; then
      rm Gemfile.lock
    fi
    bundle _"$BUNDLE_VERSION"_ update
    bundle _"$BUNDLE_VERSION"_ exec rspec spec
  done
done

unset RAILS_VERSION
