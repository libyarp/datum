# frozen_string_literal: true

module Datum
  # Internal: Reflect provides reflection utilities for classes inheriting
  # Datum::Record.
  module Reflect
    def self.extended(base)
      base.include InstanceMethods
    end

    # Public: Returns a list of columns for the receiving class. Values returned
    # from this method are memoized.
    def columns
      @columns ||= connection.columns_of(table_name)
    end

    # Internal: Defines fields for the receiving class. This method is not
    # intended for use outside Datum.
    def define_fields
      return if @fields_defined

      @fields_defined = true

      columns.each { |c| define_field(c) }
    end

    # Internal: Initializes a new instance of the receiving class using provided
    # data and adapter.
    #
    # data    - A hash containing values for the model's fields
    # adapter - Adapter instance that requested the class initialisation
    #
    # Returns a new instance of the receiving class, with fields set by data.
    def synthetize(data, adapter)
      return nil if data.nil?

      new.tap do |model|
        model.send(:bulk_set_fields, data, adapter: adapter)
        model.reset_changed_fields
        model.instance_variable_set :@__persisted, true
      end
    end

    # Internal: Indicates whether the receiving class uses timestamp columns
    # created_at and updated_at.
    def has_timestamp_columns?
      %i[created_at updated_at].all? { |n| columns.any? { |c| c.name == n } }
    end

    # Methods implemented as instance methods for classes extending this module
    module InstanceMethods
      protected

      # Internal: Sets fields from data, casting them through a provided adapter
      #
      # data     - Hash-like object providing values for each of the model's
      #            columns
      # adapter: - Adapter from which data is being set from.
      #
      # Returns nothing
      def bulk_set_fields(data, adapter: connection)
        data.each do |k, v|
          k = k.to_sym unless k.is_a? Symbol
          col = self.class.columns.find { |c| c.name == k }
          next if col.nil?

          send("#{k}=", adapter.cast_to_model(v, col))
        end
      end
    end
  end
end
