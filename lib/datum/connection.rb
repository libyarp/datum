# frozen_string_literal: true

module Datum
  # Record implements all basic logic for models; thus requiring all models to
  # inherit from it.
  class Record
    @@config_for = {}

    def self.establish_connection(dsn = nil)
      if dsn.nil?
        establish_connection(Yarp::Runtime.application.config.database_url)
      else
        @@config_for[self] = parse_dsn(dsn)
      end
      true
    end

    def self.connection
      klass = find_record_subclass
      Thread.current[:active_connections] ||= {}
      return Thread.current[:active_connections][klass] if Thread.current[:active_connections][klass]
      raise ConnectionNotEstablished if @@config_for[self].nil? && self == Datum::Record
      return Datum::Record.connection if @@config_for[self].nil?

      Thread.current[:active_connections][klass] = Datum::Adapter.connect(@@config_for[self])
    end

    def self.parse_dsn(dsn)
      DSN.new(URI.parse(dsn))
    end

    def self.disconnect_all
      @@config_for = {}
      Thread.current[:active_connections] ||= {}
      Thread.current[:active_connections].each_value(&:disconnect)
      Thread.current[:active_connections] = {}
    end
  end
end
