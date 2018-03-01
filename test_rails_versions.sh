#! /bin/bash

set -e

for RAILS_VERSION in "~> 3.2.0" "~> 4.0.0" "~> 4.1.0" "~> 4.2.0" "~> 5.0.0" "= 5.1.4" "= 5.1.5" "~> 5.1.5"
do
  export RAILS_VERSION
  echo "Rails $RAILS_VERSION"
  bundle update
  bundle exec rspec spec
done

unset RAILS_VERSION
