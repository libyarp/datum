# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "spec/"
  add_filter "lib/datum/dsn_query_parser.rb"
end

require "datum"
require "byebug"
require "timecop"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  Datum.default_logger = Logrb.new(StringIO.new)
end
