# frozen_string_literal: true

module Datum::Adapter
  class MySQL < Base
    def timestamp_format
      "#{date_format} #{time_format}"
    end

    def time_format
      "%H:%M:%S%:z"
    end

    def connect
      @db = Mysql2::Client.new(**{
        host: @config.host,
        port: @config.port,
        username: @config.username,
        password: @config.password,
        database: @config.database_name,
        database_timezone: :utc,
        application_timezone: :utc
      }.merge(@config.options))
      @db.query_options.merge!(symbolize_keys: true)
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

      log(sql, name: name, params: params) { execute(sql, *params) }
    end

    def insert(klass, values, _returns)
      table = klass.table_name
      sql = <<-SQL
        INSERT INTO #{table} (#{values.keys.join(", ")})
        VALUES (#{(["?"] * values.length).join(", ")})
      SQL

      log(sql, name: "#{klass.name} Insert", params: values) do
        execute(sql, *values.values)
        { klass.primary_key => @db.last_id }
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
        execute(sql, *params)
      end
    end

    def count(table, name: nil, where: nil)
      sql = ["SELECT COUNT(*) FROM #{table}"]
      params = []
      unless (condition = prepare_where(where, params)).nil?
        sql << "WHERE (#{condition})"
      end

      sql = sql.join(" ")

      log(sql, name: name, params: params) { execute(sql, *params).first.values.first }
    end

    def columns_of(table_name)
      table_structure(table_name).each_with_object([]) do |field, cols|
        cols << Datum::Column.new(field[:Field].to_sym, field[:Default], type: field[:Type])
      end
    end

    def table_structure(table_name)
      execute(<<-SQL)
        SHOW FIELDS FROM #{table_name}
      SQL
    end

    def execute(sql, *values)
      stmt = @db.prepare(sql)
      stmt.execute(*values).to_a
    end

    def prepare_migration_log
      @db.query(<<-SQL)
        CREATE TABLE IF NOT EXISTS datum_metadata (mid TEXT, INDEX(mid));
      SQL
    end

    def register_migration(id)
      execute("INSERT INTO datum_metadata VALUES (?)", id)
    end

    def tx_begin
      @db.query("START TRANSACTION;")
    end

    def tx_commit
      @db.query("COMMIT;")
    end

    def tx_rollback
      @db.query("ROLLBACK;")
    end

    def execute_ddl(sql)
      @db.query(sql)
    end

    def cast_to_adapter(value, column)
      val = super
      val.gsub!(/(-|\+)00:00$/, "") if %i[datetime time date].include? column.type
      val
    end
  end
end

Datum::Adapter.register_adapter name: :mysql,
                                base_class: Datum::Adapter::MySQL,
                                dependency: "mysql2"
