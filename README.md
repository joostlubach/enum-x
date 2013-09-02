# EnumX

Add an easy way to define a finite set of values for a certain field.

## Installation

Add this line to your application's Gemfile:

    gem 'enum-x'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install enum-x

## Usage

In the simplest form, you can use the `EnumX` class by itself:

    enum = EnumX.new(:my_enum, %w[ one two three ])
    my_variable = enum[:one]
    my_variable.class    # => EnumX::Value
    my_variable.to_s     # => 'one'
    my_variable == :one  # => true

Using the DSL, you can assign an enum to some attribute, much like most other enum-libraries:

    class Post < ActiveRecord::Base
      include EnumX::DSL

      enum :status, %w[ draft published ]
    end

If you wish to re-use enums, you can share them by defining them centrally, e.g.

**config/enums.yml:**

    post_statuses: [ draft, published ]

**app/models/post.rb:**

    class Post < ActiveRecord::Base
      include EnumX::DSL

      enum :status, :post_statuses
    end

If you don't provide a second argument, the plural form is used:

**config/enums.yml:**

    currencies: [ euro, dollar ]

**app/models/post.rb:**

    class Price < ActiveRecord::Base
      include EnumX::DSL

      enum :currency
      # => equivalent to 'enum :currency, :currencies'
    end

When using the DSL, a shortcut to the enum is created on the class. `Price.currencies` is a shortcut to `EnumX.currencies`, and `Post.statuses` is a shortcut to `EnumX.post_statuses`.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
