# frozen_string_literal: true

module Datum::Adapter
  class Postgres < Base
    def timestamp_format
      "#{date_format} #{time_format}"
    end

    def connect
      opts = {
        host: @config.host,
        port: @config.port,
        dbname: @config.database_name,
        user: @config.username,
        password: @config.password
      }.to_a.compact.to_h.merge(@config.options)

      @db = PG::Connection.new(opts)
    end

    def disconnect
      @db.close
    end

    def prepare_where(obj, params)
      return nil if obj.nil?

      case obj[:kind]
      when :sql
        obj[:args].each { |param| params << cast_param(param) }
        obj[:sql]
      when :conditions
        obj[:conditions].map do |k, v|
          params << cast_param(v)
          "#{k} = $#{params.length}"
        end.join(" AND ")
      end
    end

    def select(table, name: nil, where: nil, order: nil, limit: nil, skip: nil)
      sql = ["SELECT * FROM #{table}"]
      params = []
      unless (condition = prepare_where(where, params)).nil?
        sql << "WHERE (#{condition})"
      end

      unless (order = prepare_order(order)).nil?
        sql << "ORDER BY #{order}"
      end

      unless limit.nil?
        params << limit
        sql << "LIMIT $#{params.length}"
      end

      unless skip.nil?
        params << skip
        sql << "OFFSET $#{params.length}"
      end

      sql = sql.join(" ")

      log(sql, name: name, params: params) { @db.exec_params(sql, params).to_a }
    end

    def insert(klass, values, returns)
      table = klass.table_name
      params = []
      sql_values = values.map do |v|
        params << v
        "$#{params.length}"
      end

      sql = <<-SQL
        INSERT INTO #{table} (#{values.keys.join(", ")})
        VALUES (#{sql_values.join(", ")})
        RETURNING #{returns.join(", ")}
      SQL

      log(sql, name: "#{klass.name} Insert", params: values) do
        @db.exec_params(sql, values.values).first
      end
    end

    def update(table, where:, values:, name: nil)
      sql = ["UPDATE #{table} SET"]
      setters = []
      params = []
      values.each do |k, v|
        params << cast_param(v)
        setters << "#{k} = $#{params.length}"
      end

      sql << setters.join(", ")

      unless (condition = prepare_where(where, params)).nil?
        sql << "WHERE (#{condition})"
      end

      sql = sql.join(" ")

      log(sql, name: name, params: params) do
        @db.exec_params(sql, params)
      end
    end

    def count(table, name: nil, where: nil)
      sql = ["SELECT COUNT(*) FROM #{table}"]
      params = []
      unless (condition = prepare_where(where, params)).nil?
        sql << "WHERE (#{condition})"
      end

      sql = sql.join(" ")

      log(sql, name: name, params: params) { @db.exec_params(sql, params).first.values.first.to_i }
    end

    def columns_of(table_name)
      table_structure(table_name).each_with_object([]) do |field, cols|
        cols << Datum::Column.new(field["column_name"].to_sym, infer_default_value(field["column_default"]),
                                  type: field["data_type"],
                                  limit: field["character_maximum_length"])
      end
    end

    def table_structure(table_name)
      @db.exec_params(<<-SQL, [@config.database_name, table_name])
        SELECT column_name, column_default, character_maximum_length, data_type
          FROM information_schema.columns
          WHERE table_catalog = $1
          AND table_name = $2
      SQL
    end

    def execute(sql, *values)
      @db.exec_params(sql, values)
    end

    def prepare_migration_log
      @db.exec(<<-SQL)
        CREATE TABLE IF NOT EXISTS datum_metadata (mid TEXT);
        CREATE INDEX IF NOT EXISTS metadata_mid ON datum_metadata (mid);
      SQL
    end

    def register_migration(id)
      @db.exec_params(<<-SQL, [id])
        INSERT INTO datum_metadata (mid) VALUES ($1)
      SQL
    end

    def tx_begin
      execute("BEGIN")
    end

    def tx_commit
      execute("COMMIT")
    end

    def tx_rollback
      execute("ROLLBACK")
    end

    def execute_ddl(sql)
      @db.exec(sql)
    end

    def infer_default_value(value)
      return true if /true/i.match?(value)
      return false if value =~ /false/i

      # Strings
      return Regexp.last_match(1) if value =~ /^'(.*)'::(bpchar|text|character varying)$/

      # Numbers
      return value.to_i if /^[0-9]+$/.match?(value)
      return value.to_f if /^[0-9]+(\.[0-9]*)$/.match?(value)

      nil
    end
  end
end

Datum::Adapter.register_adapter name: :postgres,
                                base_class: Datum::Adapter::Postgres,
                                dependency: "pg"
