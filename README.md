# counter_culture

Turbo-charged counter caches for your Rails app. Huge improvements over the Rails standard counter caches:

* Updates counter cache when values change, not just when creating and destroying 
* Supports counter caches through multiple levels of relations
* Supports dynamic column names, making it possible to split up the counter cache for different types of objects
* Executes counter updates after the commit, avoiding [deadlocks](http://mina.naguib.ca/blog/2010/11/22/postgresql-foreign-key-deadlocks.html)

## Installation

Add counter_culture to your Gemfile:

```ruby
gem 'counter_culture', '~> 0.1.4'
```

Then run ```bundle update ```

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

class SubCategory < ActiveRecord::Base
  has_many :sub_categories
end
```

Now, the ```Category``` model will keep an up-to-date counter-cache in the ```products_count``` column of the ```categories``` table. This will work with any number of levels.

### Customizing the column name

```ruby
class Product < ActiveRecord::Base
  belongs_to :category
  counter_culture :category, :column_name => "products_counter_cache"
end

class Category < ActiveRecord::Base
  has_many :products
end
```

Now, the ```Category``` model will keep an up-to-date counter-cache in the ```products_counter_cache``` column of the ```categories``` table. This will also work with multi-level counter caches.

## Contributing to counter_culture
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2012 BestVendor. See LICENSE.txt for further details.
