# frozen_string_literal: true

module Datum
  # Public: Migrations represents a single migration
  class Migration
    attr_reader :up, :down, :id, :name
    attr_accessor :status

    def initialize(root, id, name)
      @id = id
      @name = name
      @status = :unknown
      @up = root&.join("#{id}_#{name}.up.sql")
      @down = root&.join("#{id}_#{name}.down.sql")
    end

    # Public: Validates whether the migration is valid. Raises
    # AsymmetricalMigration in case an `up` or `down` file is missing.
    def validate!
      return unless !@up.exist? || !@down.exist?

      raise AsymmetricalMigration, "#{@name} is asymmetrical; " \
                                   "migrations must have a .up.sql, and .down.sql pair."
    end

    # Public: Returns whether this specific migration has been applied.
    def up?
      !down?
    end

    # Public: Returns whether this specific migration has not been applied.
    def down?
      status == :down
    end
  end
end
