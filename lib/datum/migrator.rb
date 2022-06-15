# frozen_string_literal: true

module Datum
  # Public: Migrator implements basic logic to handle database migrations.
  class Migrator
    PATTERN = /(\d+)_([^.]+)\.(up|down)\.sql$/i.freeze

    # Public: Returns the root path for migrations, or raises
    # MigrationDirectoryNotSet in case it is not set.
    def root
      return @path unless @path.nil?

      @path = Datum.migrations_path.tap do |path|
        raise MigrationDirectoryNotSet, "Migration directory not set" if path.nil?
      end
    end

    # Public: Enumerates all migrations present on disk, returning a Migration
    # instance for each of them.
    def enumerate_migrations
      migrations = {}
      root_path = Pathname.new(root)
      Dir[Pathname.new(root_path).join("*.sql")].each do |path|
        full_path = Pathname.new(path).cleanpath
        file_name = full_path.relative_path_from root_path
        next unless file_name.basename.to_s =~ PATTERN

        id = Regexp.last_match(1)
        name = Regexp.last_match(2)
        next if migrations.key? id

        migrations[id] = Migration.new(root_path, id, name).tap(&:validate!)
      end
      migrations.values
    end

    # Public: Returns a list of Migration records with #status set to reflect
    # the current database schema.
    def migration_status
      Record.connection.prepare_migration_log
      applied = Record.connection.load_migration_log.map { |i| i.fetch("mid", i.fetch(:mid, nil)) }

      status_items = []

      enumerate_migrations.each do |mig|
        mig.status = applied.include?(mig.id) ? :up : :down
        status_items << mig
      end

      applied
        .filter { |i| status_items.find { |s| s.id == i }.nil? }
        .each do |id|
          status_items << Migration.new(nil, id, "missing")
                                   .tap { |i| i.status = :up }
        end

      status_items.sort_by(&:id)
    end

    # Public: Applies all missing migrations.
    def move_forward
      to_apply = migration_status.filter(&:down?)
      return if to_apply.empty?

      puts "About to apply #{to_apply.length} migration#{to_apply.length > 1 ? "s" : ""}"
      conn = Record.connection

      conn.tx_begin
      to_apply.each do |mig|
        puts "  Apply #{mig.id}_#{mig.name}"
        mig.up.readlines.each do |l|
          puts "    #{l}"
        end
        conn.execute_ddl(mig.up.read.to_s)
        conn.register_migration(mig.id)
      end
      conn.tx_commit
    end

    # Public: Rollbacks a given amount of migrations.
    def rollback(steps: 1)
      to_apply = migration_status.filter(&:up?).reverse.take(steps)
      return if to_apply.empty?

      puts "About to revert #{to_apply.length} migration#{to_apply.length > 1 ? "s" : ""}"
      conn = Record.connection

      conn.tx_begin
      to_apply.each do |mig|
        puts "  Revert #{mig.id}_#{mig.name}"
        mig.down.readlines.each do |l|
          puts "    #{l}"
        end
        conn.execute_ddl(mig.down.read.to_s)
      end
      conn.tx_commit
    end
  end
end
