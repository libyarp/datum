# frozen_string_literal: true

require "uri"
require "date"
require "time"
require "benchmark"
require "logrb"

require_relative "datum/version"
require_relative "datum/inflector"
require_relative "datum/dsn"
require_relative "datum/dsn_query_parser"
require_relative "datum/errors"
require_relative "datum/queries"
require_relative "datum/dirty"
require_relative "datum/reflect"
require_relative "datum/lifecycle"
require_relative "datum/record_enumerator"
require_relative "datum/query_proxy"
require_relative "datum/record"
require_relative "datum/connection"
require_relative "datum/adapter"
require_relative "datum/column"
require_relative "datum/migrator"
require_relative "datum/migration"

# Module Datum provides all mechanisms required for creating and manipulating
# models.
module Datum
  # Public: Sets the default DSN to be used for Models that does not specify
  # one.
  # Also see: Datum::Record.establish
  def self.default_dsn=(value)
    @default_dsn = value
    Record.establish_connection(value)
  end

  # Internal: Returns the default configured DSN
  def self.default_dsn
    @default_dsn
  end

  # Public: Sets the path to a directory in which migrations are stored
  def self.migrations_path=(value)
    @migrations_path = value
  end

  # Internal: Returns the path to the directory in which migrations are stored
  def self.migrations_path
    @migrations_path
  end

  # Internal: Returns the default logger instance
  def self.default_logger
    @default_logger ||= Logrb.new($stdout)
  end

  # Public: Sets the default logger instance
  def self.default_logger=(value)
    @default_logger = value
  end

  # Internal: Returns a logger for the current calling thread, or obtains one
  # from #default_logger
  def self.logger
    Thread.current[:local_logger] ||= default_logger
  end
end
