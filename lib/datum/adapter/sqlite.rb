# frozen_string_literal: true

module Datum::Adapter
  class Sqlite < Base
    def connect
      path = Pathname.new(@config.raw_database_name)
      Dir.mkdir path.dirname if path.dirname.basename.to_s == ".local" && !path.dirname.exist?
      @config.raw_database_name = ":memory:" if @config.raw_database_name == "memory"
      @db = SQLite3::Database.new(@config.raw_database_name).tap do |db|
        db.results_as_hash  = true
        db.type_translation = false
      end
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
          "#{k} = ?"
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
        sql << "LIMIT ?"
        params << limit
      end

      unless skip.nil?
        sql << "OFFSET ?"
        params << skip
      end

      sql = sql.join(" ")

      log(sql, name: name, params: params) { @db.execute(sql, params) }
    end

    def insert(klass, values, _returns)
      table = klass.table_name
      sql = <<-SQL
        INSERT INTO #{table} (#{values.keys.join(", ")})
        VALUES (#{(["?"] * values.length).join(", ")})
      SQL

      log(sql, name: "#{klass.name} Insert", params: values) do
        @db.execute(sql, values.values)
        { klass.primary_key => @db.last_insert_row_id }
      end
    end

    def update(table, where:, values:, name: nil)
      sql = ["UPDATE #{table} SET"]
      setters = []
      params = []
      values.each do |k, v|
        setters << "#{k} = ?"
        params << cast_param(v)
      end

      sql << setters.join(", ")

      unless (condition = prepare_where(where, params)).nil?
        sql << "WHERE (#{condition})"
      end

      sql = sql.join(" ")

      log(sql, name: name, params: params) do
        @db.execute(sql, params)
      end
    end

    def count(table, name: nil, where: nil)
      sql = ["SELECT COUNT(*) FROM #{table}"]
      params = []
      unless (condition = prepare_where(where, params)).nil?
        sql << "WHERE (#{condition})"
      end

      sql = sql.join(" ")

      log(sql, name: name, params: params) { @db.get_first_value(sql, params) }
    end

    def columns_of(table_name)
      table_structure(table_name).each_with_object([]) do |field, cols|
        cols << Datum::Column.new(field["name"].to_sym, field["dflt_value"], type: field["type"])
      end
    end

    def table_structure(table_name)
      sql = "PRAGMA table_info(#{table_name});"
      @db.execute(sql)
    end

    def execute(sql, *values)
      @db.execute(sql, *values)
    end

    def prepare_migration_log
      @db.execute(<<-SQL)
        CREATE TABLE IF NOT EXISTS datum_metadata (mid TEXT);
        CREATE INDEX IF NOT EXISTS metadata_mid ON datum_metadata (mid);
      SQL
    end

    def register_migration(id)
      @db.execute("INSERT INTO datum_metadata VALUES (?)", id)
    end

    def tx_begin
      return if @db.transaction_active?

      @db.transaction
    end

    def tx_commit
      @db.commit
    end

    def tx_rollback
      @db.rollback
    end

    def execute_ddl(sql)
      @db.execute_batch(sql)
    end

    def cast_to_model(value, column)
      return value == 1 if column.type == :boolean

      super
    end

    def cast_to_adapter(value, column)
      return value ? 1 : 0 if column.type == :boolean

      super
    end

    def cast_param(value)
      return (value ? 1 : 0) if value.is_a?(TrueClass) || value.is_a?(FalseClass)

      super
    end
  end
end

Datum::Adapter.register_adapter name: :sqlite,
                                base_class: Datum::Adapter::Sqlite,
                                dependency: "sqlite3"
