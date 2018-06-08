# counter_culture [![Build Status](https://travis-ci.org/magnusvk/counter_culture.svg)](https://travis-ci.org/magnusvk/counter_culture)

Turbo-charged counter caches for your Rails app. Huge improvements over the Rails standard counter caches:

* Updates counter cache when values change, not just when creating and destroying
* Supports counter caches through multiple levels of relations
* Supports dynamic column names, making it possible to split up the counter cache for different types of objects
* Can keep a running count, or a running total

Tested against Ruby 2.2.5 and 2.3.1 and against the latest patch releases of Rails 3.2, 4.0, 4.1, 4.2, 5.0 and 5.1.

## Installation

Add counter_culture to your Gemfile:

```ruby
gem 'counter_culture', '~> 1.8'
```

Then run `bundle install`

## Database Schema

You must create the necessary columns for all counter caches. You can use counter_culture's generator to create a skeleton migration:

```
rails generate counter_culture Category products_count
```

Which will generate a migration with code like the following:
```ruby
add_column :categories, :products_count, :integer, null: false, default: 0
```
Note that the column must be ```NOT NULL``` and have a default of zero for this gem to work correctly.

If you are adding counter caches to existing data, you must add code to [manually populate their values](#manually-populating-counter-cache-values) to the generated migration.

## Usage

### Simple counter-cache

```ruby
class Product < ActiveRecord::Base
  belongs_to :category
  counter_culture :category
end

class Category < ActiveRecord::Base
  has_many :products
end
```

Now, the ```Category``` model will keep an up-to-date counter-cache in the ```products_count``` column of the ```categories``` table.

### Multi-level counter-cache

```ruby
class Product < ActiveRecord::Base
  belongs_to :sub_category
  counter_culture [:sub_category, :category]
end

class SubCategory < ActiveRecord::Base
  has_many :products
  belongs_to :category
end

class Category < ActiveRecord::Base
  has_many :sub_categories
end
```

Now, the ```Category``` model will keep an up-to-date counter-cache in the ```products_count``` column of the ```categories``` table. This will work with any number of levels.

If you want to have a counter-cache for each level of your hierarchy, then you must add a separate counter cache for each level.  In the above example, if you wanted a count of products for each category and sub_category you would change the Product class to:

```ruby
class Product < ActiveRecord::Base
  belongs_to :sub_category
  counter_culture [:sub_category, :category]
  counter_culture [:sub_category]
end
```

### Customizing the column name

```ruby
class Product < ActiveRecord::Base
  belongs_to :category
  counter_culture :category, column_name: "products_counter_cache"
end

class Category < ActiveRecord::Base
  has_many :products
end
```

Now, the ```Category``` model will keep an up-to-date counter-cache in the ```products_counter_cache``` column of the ```categories``` table. This will also work with multi-level counter caches.

### Dynamic column name

```ruby
class Product < ActiveRecord::Base
  belongs_to :category
  counter_culture :category, column_name: proc {|model| "#{model.product_type}_count" }
  # attribute product_type may be one of ['awesome', 'sucky']
end

class Category < ActiveRecord::Base
  has_many :products
end
```

### Delta Magnitude

```ruby
class Product < ActiveRecord::Base
  belongs_to :category
  counter_culture :category, column_name: :weight, delta_magnitude: proc {|model| model.product_type == 'awesome' ? 2 : 1 }
end

class Category < ActiveRecord::Base
  has_many :products
end
```

Now the `Category` model will keep the `weight` column up to date: `awesome` products will affect it by a magnitude of 2, others by a magnitude of 1.

You can also use a static multiplier as the `delta_magnitude`:
```ruby
class Product < ActiveRecord::Base
  belongs_to :category
  counter_culture :category, column_name: :weight, delta_magnitude: 3
end

class Category < ActiveRecord::Base
  has_many :products
end
```

Now adding a `Product` will increase the `weight` column in its `Category` by 3; deleting it will decrease it by 3.

### Conditional counter cache

```ruby
class Product < ActiveRecord::Base
  belongs_to :category
  counter_culture :category, column_name: proc {|model| model.special? ? 'special_count' : nil }
end

class Category < ActiveRecord::Base
  has_many :products
end
```

Now, the ```Category``` model will keep the counter cache in ```special_count``` up-to-date. Only products where ```special?``` returns true will affect the special_count.

### Totaling instead of counting

Instead of keeping a running count, you may want to automatically track a running total.
In that case, the target counter will change by the value in the totaled field instead of changing by exactly 1 each time.
Use the ```:delta_column``` option to specify that the counter should change by the value of a specific field in the counted object.
For example, suppose the Product model table has a field named ```weight_ounces```, and you want to keep a running
total of the weight for all the products in the Category model's ```product_weight_ounces``` field:

```ruby
class Product < ActiveRecord::Base
  belongs_to :category
  counter_culture :category, column_name: 'product_weight_ounces', delta_column: 'weight_ounces'
end

class Category < ActiveRecord::Base
  has_many :products
end
```

Now, the ```Category``` model will keep the counter cache in ```product_weight_ounces``` up-to-date.
The value in the counter cache will be the sum of the ```weight_ounces``` values in each of the associated Product records.

The ```:delta_column``` option supports all numeric column types, not just ```:integer```. Specifically, ```:float``` is supported and tested.

### Dynamically over-writing affected foreign keys

```ruby
class Product < ActiveRecord::Base
  belongs_to :category
  counter_culture :category, foreign_key_values:
      proc {|category_id| [category_id, Category.find_by_id(category_id).try(:parent_category).try(:id)] }
end

class Category < ActiveRecord::Base
  belongs_to :parent_category, class_name: 'Category', foreign_key: 'parent_id'
  has_many :children, class_name: 'Category', foreign_key: 'parent_id'

  has_many :products
end
```

Now, the ```Category``` model will keep an up-to-date counter-cache in the ```products_count``` column of the ```categories``` table. Each product will affect the counts of both its immediate category and that category's parent. This will work with any number of levels.

### Updating timestamps when counts change

By default, counter_culture does not update the timestamp of models when it updates their counter caches. If you would like every change in the counter cache column to result in an updated timestamp, simply set the touch option to true:
```ruby
  counter_culture :category, touch: true
```

This is useful when you require your caches to get invalidated when the counter cache changes.

### Custom timestamp column

You may also specify a custom timestamp column that gets updated only when a particular counter cache changes:
```ruby
  counter_culture :category, touch: 'category_count_changed'
```

With this option, any time the `category_counter_cache` changes both the `category_count_changed` and `updated_at` columns will get updated.

### Executing counter cache updates after commit

By default, counter_culture will run counter cache updates inside of the same ActiveRecord transaction that triggered it. (Note that this bevavior [changed from version 0.2.3 to 1.0.0](CHANGELOG.md#100-november-15-2016).) If you would like to run counter cache updates outside of that transaction, for example because you are experiencing [deadlocks with older versions of PostgreSQL](http://mina.naguib.ca/blog/2010/11/22/postgresql-foreign-key-deadlocks.html), you can enable that behavior:
```ruby
  counter_culture :category, execute_after_commit: true
```

Please note that using `execute_after_commit` in conjunction with transactional
fixtures will lead to your tests no longer seeing updated counter values.

### Manually populating counter cache values

You will sometimes want to populate counter-cache values from primary data. This is required when adding counter-caches to existing data. It is also recommended to run this regularly (at BestVendor, we run it once a week) to catch any incorrect values in the counter caches.

```ruby
Product.counter_culture_fix_counts
# will automatically fix counts for all counter caches defined on Product

Product.counter_culture_fix_counts exclude: :category
# will automatically fix counts for all counter caches defined on Product, except for the :category relation

Product.counter_culture_fix_counts only: :category
# will automatically fix counts only on the :category relation on Product

# :exclude and :only also accept arrays of one level relations
# if you want to fix counts on a more than one level relation you need to use convention below:

Product.counter_culture_fix_counts only: [[:subcategory, :category]]
# will automatically fix counts only on the two-level [:subcategory, :category] relation on Product

# :except and :only also accept arrays
```

The ```counter_culture_fix_counts``` counts method uses batch processing of records to keep the memory consumption low. The default batch size is 1000 but is configurable like so
```ruby
# In an initializer
CounterCulture.config.batch_size = 100
```
or by passing the :batch_size option to the method call

```ruby
Product.counter_culture_fix_counts batch_size: 100
```

```counter_culture_fix_counts``` returns an array of hashes of all incorrect values for debugging purposes. The hashes have the following format:

```ruby
{ entity: which model the count was fixed on,
  id: the id of the model that had the incorrect count,
  what: which column contained the incorrect count,
  wrong: the previously saved, incorrect count,
  right: the newly fixed, correct count }
```

```counter_culture_fix_counts``` is optimized to minimize the number of queries and runs very quickly.

Similarly to `counter_culture`, it is possible to update the records' timestamps, when fixing counts. If you would like to update the default timestamp field, pass `touch: true` option:

```ruby
Product.counter_culture_fix_counts touch: true
```

If you have specified a custom timestamps column, pass its name as the value for the `touch` option:

```ruby
Product.counter_culture_fix_counts touch: category_count_changed
```

#### Handling dynamic column names

Manually populating counter caches with dynamic column names requires additional configuration:

```ruby
class Product < ActiveRecord::Base
  belongs_to :category
  counter_culture :category,
      column_name: proc {|model| "#{model.product_type}_count" },
      column_names: {
          ["products.product_type = ?", 'awesome'] => 'awesome_count',
          ["products.product_type = ?", 'sucky'] => 'sucky_count'
      }
  # attribute product_type may be one of ['awesome', 'sucky']
end
```

If you would like to avoid this configuration and simply skip counter caches with
dynamic column names, while still fixing those counters on the model that are not
dynamic, you can pass `skip_unsupported`:

```ruby
Product.counter_culture_fix_counts skip_unsupported: true
```

#### Handling over-written, dynamic foreign keys

Manually populating counter caches with dynamically over-written foreign keys (```:foreign_key_values``` option) is not supported. You will have to write code to handle this case yourself.

### Soft-deletes with `paranoia` or `discard`

This gem will keep counters correctly updated in Rails 4.2 or later when using
[paranoia](https://github.com/rubysherpas/paranoia) or
[discard](https://github.com/jhawthorn/discard) for soft-delete support.
However, to ensure that counts are incremented after a restore you have
to make sure to set up soft deletion (via `acts_as_paranoid` or
`include Discard::Model`) before the call to `counter_culture` in your model:

#### Paranoia

```ruby
class SoftDelete < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :company
  counter_culture :company
end
```

#### Discard

```ruby
class SoftDelete < ActiveRecord::Base
  include Discard::Model

  belongs_to :company
  counter_culture :company
end
```

### PaperTrail integration

If you are using the [`paper_trail` gem](https://github.com/airblade/paper_trail)
and would like new versions to be created when the counter cache columns are
changed by counter_culture, you can set the `with_papertrail` option:

```ruby
class Review < ActiveRecord::Base
  counter_culture :product, with_papertrail: true
end

class Product < ActiveRecord::Base
  has_paper_trail
end
```

#### Polymorphic associations

counter_culture now supports polymorphic associations of one level only.

## Contributing to counter_culture

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2012-2013 BestVendor, Magnus von Koeller. See LICENSE.txt for further details.
