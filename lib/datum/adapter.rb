# frozen_string_literal: true

module Datum
  # Internal: Module adapter provides internal mechanisms for registering and
  # initialising adapters.
  module Adapter
    def self.register_adapter(name:, base_class:, dependency:)
      begin
        require dependency
      rescue LoadError
        return
      end

      @adapters ||= {}
      @adapters[name.to_s] = base_class
      nil
    end

    def self.connect(config)
      @adapters ||= {}
      adapter = @adapters[config.type]
      if adapter.nil?
        raise Datum::UnavailableAdapter, "Adapter '#{config.type}' is unavailable. " \
                                         "This usually indicates that a required gem " \
                                         "is not available, or the application is " \
                                         "misconfigured. Check your Gemfile, " \
                                         "installed gems, and DSN."
      end

      adapter.new(config, Datum.logger)
    end
  end
end

require_relative "adapter/base"
require_relative "adapter/sqlite"
require_relative "adapter/postgres"
require_relative "adapter/mysql"
