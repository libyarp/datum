# Datum

Datum provides a small Data Layer for Ruby through an interface that resembles
ActiveRecord, but without ActiveRecord! It is intended for small Ruby services
(perhaps using [Yarp](https://github.com/libyarp/yarp.rb)?).

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add yarp-datum

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install yarp-datum

## Usage

Datum provides support for PostgreSQL, SQLite, and MySQL. Make sure to install
the driver to the database you intend to use:

| Database   | Driver |
|------------|--------|
| PostgreSQL | [`pg`](https://github.com/ged/ruby-pg) |
| SQLite     | [`sqlite3`](https://github.com/sparklemotion/sqlite3-ruby) |
| MySQL      | [`mysql2`](https://github.com/brianmario/mysql2) |

Then, `require` Datum:

```ruby
require 'datum'
```

Datum by itseld doesn't do much. First, you may want to create a directory to
contain your migration files, and another one for your models. Then, create a
new migration:

> **ProTip™**: You don't need to use migrations and models. One may use only one
> of those facilities, as one deems fit.

```sql
-- db/migrations/0001_create_users.up.sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    active BOOL NOT NULL,
    created_at TIMESTAMPTZ DEFAULT 'NOW()',
    updated_at TIMESTAMPTZ DEFAULT 'NOW()'
);
```

```sql
-- db/migrations/0001_create_users.down.sql
DROP TABLE users;
```

In order to maintain migrations in your database, we will need a `Migrator`
instance. Notice that Datum does not provide CLI tools.

In order to have a `Migrator` (or to use models), we must first connect to our
database. For this example, I'm using a PostgreSQL database:

```ruby
Datum::Record.establish_connection("postgres://postgres:postgres@localhost:5432/datum?sslmode=disable")
# => true
```

That URI (or DSN) is composed by those components:

```
ADAPTER://[USERNAME[:PASSWORD]]@HOST[:PORT]/DATABASE_NAME[?[OPTION=VALUE[&OPTION=VALUE...]]
```

For `ADAPTER`, we can provide `postgres`, `sqlite`, or `mysql`.

Back to migrations. Once `establish_connection` is invoked, we must then
indicate where our migration files are. This is done by setting `Datum.migrations_path`:

```ruby
Datum.migrations_path = "/sample/db/migrations"
# => "/sample/db/migrations"
```

And finally initializing our `Migrator`:

```ruby
m = Datum::Migrator.new
m.migration_status
# => [#<Datum::Migration:0x0000000106ce2280 @id="0001", @name="create_users", @status=:down, @up=#<Pathname:/sample/db/migrations/0001_create_users.up.sql>, @down=#<Pathname:/sample/db/migrations/0001_create_users.down.sql>>]

m.move_forward
# About to apply 1 migration
#  Apply 0001_create_users
# [SNIP]
```

Once the database contains our table, we can create a new `User` class:

```ruby
class User < Datum::Record
end
```

And use it:

```ruby
u = User.new(name: "Paul Appleseed", email: "paul@example.org", active: false)
# => #<User:0x00001950 id: nil, email: nil, name: nil, active: nil, created_at: nil, updated_at: nil>

u.save
# INFO: log: User Insert {:sql=>"INSERT INTO users (name, email, active, created_at, updated_at) VALUES [SNIP]
# => true

u.id
# => 1

user = User.find(1)
# #<User:0x000019a0 id: 1, email: "paul@example.org", name: "Paul Appleseed", active: false, [SNIP]

user.update(active: true)
# INFO: log: User Update {:sql=>"UPDATE users SET active = ?, updated_at = ?", [SNIP]
# => true
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/libyarp/yarp-datum. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/libyarp/yarp-datum/blob/master/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the Yarp::Datum project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/libyarp/yarp-datum/blob/master/CODE_OF_CONDUCT.md).
