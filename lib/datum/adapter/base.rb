# frozen_string_literal: true

module Datum
  module Adapter
    # Internal: Implements stubs for methods meant to be overriden by concrete
    # implementations of an Adapter.
    # Implementations must override the following methods:
    # select_all
    # select_one
    # columns_of
    # insert
    # update
    # delete
    # tx_begin
    # tx_commit
    # tx_rollback
    class Base
      include Benchmark

      def time_format
        "%H:%M:%S%z"
      end

      def date_format
        "%Y-%m-%d"
      end

      def timestamp_format
        "#{date_format}T#{time_format}"
      end

      def initialize(config, logger)
        @config = config
        @logger = logger
        connect
      end

      def prepare_order(pairs)
        return nil if pairs.nil? || pairs.empty?

        pairs.map { |k, v| "#{k} #{v.name.upcase}" }.join(", ")
      end

      def delete(table, name: nil, where: nil)
        sql = ["DELETE FROM #{table}"]
        params = []
        if (condition = prepare_where(where, params))
          sql << "WHERE (#{condition})"
        end
        sql = sql.join(" ")
        log(sql, name: name, params: params) { execute(sql, *params) }
      end

      # Returns an array of record hashes with the column names as a keys and fields as values.
      def select(table, name: nil, where: nil, order: nil, limit: nil, skip: nil) end
      def update(table, where:, values:, name: nil) end
      # Returns an array of Column objects for the table specified by table_name.
      def columns_of(table_name, name: nil) end

      # Inserts a given model into the database, updating its internal
      # values to reflect the operation.
      def insert(klass, values, returns) end

      # Updates a given model in the database, updating its internal
      # values to reflect the operation.
      def update_model(model, to_update)
        update(model.class.table_name,
               name: "#{model.class.name} Update",
               where: { model.primary_key => model.send(model.primary_key) },
               values: to_update)
      end

      # Deltes a model from the database
      def delete_model(model)
        delete(model.class.table_name,
               name: "#{model.class.name} Delete",
               where: { kind: :conditions, conditions: { model.primary_key => model.send(model.primary_key) } })
      end

      # Begins the transaction (and turns off auto-committing).
      def tx_begin; end

      # Commits the transaction (and turns on auto-committing).
      def tx_commit; end

      # Rollbacks the transaction (and turns on auto-committing). Must be done if the transaction block
      # raises an exception or returns false.
      def tx_rollback; end

      def transaction
        tx_begin
        result = yield
        tx_commit
        result
      rescue Exception # rubocop:disable Lint/RescueException
        tx_rollback
        raise
      end

      def normalize_value(value)
        case value
        when Array
          value.map { |v| normalize_value(v) }
        when Record
          value.send(value.class.primary_key)
        else
          value
        end
      end

      def make_log_params(params)
        return {} if params.nil?

        { params: params.map { |d| d.is_a?(Array) ? [d.first, d.last] : d } }
      end

      def load_migration_log
        sql = "SELECT * FROM datum_metadata"
        execute(sql)
      end

      def cast_to_adapter(value, column)
        case column.type
        when :integer
          value.to_i

        when :float
          value.to_f

        when :datetime
          value = value.to_time if value.is_a? Date
          value = value.utc.strftime(timestamp_format) if value.is_a? Time
          value

        when :time
          value = value.to_time if value.is_a? Date
          value = value.utc.strftime(time_format) if value.is_a? Time
          value

        when :date
          value = value.to_time if value.is_a? Date
          value = value.utc.strftime(date_format) if value.is_a? Time
          value

        when :text, :string
          value.to_s

        when :boolean
          value ? 1 : 0

        else
          value
        end
      end

      def cast_to_model(value, column)
        return nil if value.nil?

        case column.type
        when :integer
          value.to_i

        when :float
          value.to_f

        when :datetime
          return value.to_time.utc if value.is_a? DateTime
          return value.utc if value.is_a? Time

          DateTime.strptime(value, timestamp_format).to_time.utc

        when :time
          return value if value.is_a? Time

          Time.strptime(value, time_format).utc

        when :date
          return value if value.is_a? Date

          Date.strptime(value, date_format)

        when :text, :string
          value.to_s

        when :boolean
          [1, "t", true].include? value

        else
          value
        end
      end

      def cast_param(value)
        value
      end

      protected

      def log(sql, **opts)
        return yield if @logger.nil?

        result = nil
        bench = measure do
          result = [:ok, yield]
        rescue Exception => e # rubocop:disable Lint/RescueException
          result = [:error, e]
        end

        params = opts.fetch(:conditions, nil) || opts.fetch(:params, nil)
        duration = bench.real.round(2)
        res, val = result
        sql = sql.gsub(/\s+/, " ").strip
        logger = Thread.current[:logger]&.with(component: "Datum") || @logger
        log_opts = { sql: sql, duration: duration }.merge(make_log_params(params))
        name = opts.fetch(:name, "SQL")
        if res == :error
          logger.error(name, val, **log_opts)
          raise val
        else
          logger.info(name, **log_opts)
        end
        val
      end
    end
  end
end
