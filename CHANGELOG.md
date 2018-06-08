## 1.12.0 (June 8, 2018)

Improvements:
  - Adds support for the [Discard](https://github.com/jhawthorn/discard) soft-delete gem (#220)

## 1.11.0 (May 4, 2018)

Bugfixes:
  - Fix `with_papertrail` behavior while still addressing the deprecation warning, and actually recording the correct counts (#218, see [airblade/paper_trail#1076](https://github.com/airblade/paper_trail/issues/1076))

## 1.10.1 (April 20, 2018)

Improvements:
  - Added the ability to update timestamps while fixing count by passing `touch: true` to `counter_culture_fix_counts` (#212)

## 1.9.2 (April 13, 2018)

Bugfixes:
  - When using paranoia, call increment / decrement only once when calling destroy or restore on the same model multiple times

Improvements:
  - Address deprecation warning when enabling paper_trail touch in paper_trail version 9.0
  - Address `Arel` deprecation warnings in Rails 5.2

Changes:
  - Test against Ruby 2.2 through 2.5, Rails 3.2 through 5.2
  - Don't test Rails 3.2 through 4.1 against Ruby 2.4 or 2.5 as those versions of Rails will not work with those versions of Ruby
  - Avoid various deprecation warnings being triggered in the test

## 1.9.1 (March 1, 2018)

Bugfixes:
  - Address an edge-case test regression caused by Rails 5.1.5 that was causing counts to be off when saving changes from an `after_create` callback

## 1.9.0 (November 29, 2017)

Improvements:
  - Switch generated migration files to use new hash syntax
  - Support for Rails 5 migration file format for generated migrations

## 1.8.2 (September 27, 2017)

Bugfixes:
  - Actually use `batch_size` parameter in `counter_culture_fix_counts` (#200)

## 1.8.1 (September 5, 2017)

Improvements:
  - Use ActiveRecord version, not Rails version, in `Reconciler`, makeing it possible to use `counter_culture_fix_counts` without Rails

## 1.8.0 (August 30, 2017)

Improvements:
  - Quote all table names to work correctly with PostgreSQL schemata
  - Use ActiveRecord version, not Rails version, to make things work for projects that use ActiveRecord but not Rails

## 1.7.0 (June 12, 2017)

Improvements:
  - Support for creating `paper_trail` versions when counters change

## 1.6.2 (April 26, 2017)

Bugfixes:
  - Restore compatibility with older Rails versions

## 1.6.1 (April 26, 2017)

Bugfixes:
  - Fix `counter_culture_fix_counts` for a multi-level relation where an intermediate link is `has_one`, rather than `belongs_to`

## 1.6.0 (April 24, 2017)

Improvements:
  - Keeps counts updated correctly when using the paranoia gem and restoring soft-deleted records

## 1.5.1 (April 17, 2017)

Bugfixes:
  - Support for `nil` values in polymorphic relationships

## 1.5.0 (March 21, 2017)

New features:
  - Support for counter caches on one-level polymorphic relationships

## 1.4.0 (March 21, 2017)

Improvements:
  - Avoid Rails 5.1 deprecation warnings

## 1.3.1 (February 23, 2017)

Bugfixes:
  - Removed requirement for Rails 5 added by mistake (in fact, this gem supports and tests Rails versions as far back as Rails 3.2 now)

## 1.3.0 (February 21, 2017)
Removed features:
  - Removed support for `has_one`; this did not work properly. If you need this, consider adding the `counter_culture` call on the model with the `belongs_to` instead.

## 1.2.0 (February 21, 2017)

New features:
  - Add support for custom timestamp column with `touch` option

## 1.1.1 (January 13, 2017)

Bugfixes:
  - Don't blow up if the `column_names` hash contains a `nil` column name

## 1.1.0 (December 23, 2016)

Improvements:
  - Support for `has_one` associations

## 1.0.0 (November 15, 2016)

Breaking changes:
  - By default, counter_culture will now update counts inside the same transaction that triggered it. In older versions, counter cache updates happened outside of that transaction. To preserve the old behavior, use the new [`execute_after_commit` option](README.md#executing-counter-cache-updates-after-commit).

## 0.2.3 (October 18, 2016)

Improvements:
  - When running `fix_counts` on a table, wrap each batch in a transaction because that is faster on large tables.

## 0.2.2 (July 11, 2016)

Bugfixes:
  - Use `ActiveSupport.on_load` for better Rails 5 compatibility (see [rails/rails#23589](https://github.com/rails/rails/issues/23589))

## 0.2.1 (June 15, 2016)

Improvements:
  - Add [`:delta_magnitude` option](https://github.com/magnusvk/counter_culture#dynamic-delta-magnitude)

## 0.2.0 (April 22, 2016)

Improvments:
  - Major refactor of the code that reduces ActiveRecord method pollution. Documented API is unchanged, but behind the scenes a lot has changed.
  - Ability to configure batch size of `counter_culture_fix_size`

## 0.1.34 (October 27, 2015)

Bugfixes:
  - Fixes an issue when using a default scope that adds a join in conjunction with counter_culture

## 0.1.33 (April 2, 2015)

Bugfixes:
  - Fixes an issue with STI classes and inheritance

## 0.1.32 (March 16, 2015)

Improvements:
  - Restores compatibility with Rails 3.2 (fixes #100)

## 0.1.31 (March 7, 2015)

Bugfixes:
  - Avoid issue with has_and_belongs_to_many and transactions by using new after_commit_action version (fixes #88)

## 0.1.30 (February 10, 2015)

Bugfixes:
  - Correctly use custom relation primary keys (fixes #93)

## 0.1.29 (December 25, 2014)

Bugfixes:
  - Fix fixing counts with multi-level STI models

## 0.1.28 (December 7, 2014)

Bugfixes:
  - fixes development and test dependencies

## 0.1.27 (November 13, 2014)

Bugfixes:
  - re-add after_commit_action as a dependency, that had gone missing in 0.1.26

## 0.1.26 (November 12, 2014)

Bugfixes:
  - makes fix_counts work correctly with self-referential tables

## 0.1.25 (July 30, 2014)

Bugfixes:
  - makes fix_counts work correctly with custom primary keys

## 0.1.24 (June 27, 2014)

Bugfixes:
  - correctly uses custom primary keys when incrementing / decrementing counts

## 0.1.23 (May 24, 2014)

Bugfixes:
  - fixes problems fixing conditional counter caches with batching

## 0.1.22 (May 24, 2014)

Improvements:
  - support for single-table inheritance in counter_culture_fix_counts

## 0.1.21 (May 24, 2014)

Bugfixes:
  - makes the migration generator compatible with Rails 4.1

## 0.1.20 (May 14, 2014)

Bugfixes:
  - counter_culture_fix counts now supports float values, where it forced integer values previously

## 0.1.19 (January 29, 2014)

Bugfixes:
  - Use correct date / time formatting for touch option (fixes a problem with MySQL databases)

## 0.1.18 (October 16, 2013)

Bugfixes:
  - Correctly fix counter caches, even when there are no dependent records

## 0.1.17 (October 7, 2013)

Bugfixes:
  - Avoid Rails 4 deprecation warning

## 0.1.16 (October 5, 2013)

Features:
  - Added support for touch option that updates timestamps when updating counter caches

## 0.1.15 (October 5, 2013)

Features:
  - Added a simple migration generator to simplify adding counter cache columns

Improvements:
  - delta_column now supports float values

Bugfixes:
  - Prevent running out of memory when running counter_culture_fix_counts in large tables
