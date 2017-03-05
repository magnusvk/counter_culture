#! /bin/bash

set -e

for RAILS_VERSION in "3.2.0" "4.0.0" "4.1.0" "5.0.0"
do
  bundle update
  bundle exec rspec spec
done
