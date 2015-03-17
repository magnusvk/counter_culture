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
