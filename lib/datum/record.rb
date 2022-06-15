# frozen_string_literal: true

module Datum
  # Record implements all basic logic for models; thus requiring all models to
  # inherit from it.
  class Record
    extend Datum::Queries
    extend Datum::Reflect
    extend Datum::Dirty
    include Datum::Lifecycle

    # Public: Convenience method that returns self.class.connection
    def connection
      self.class.connection
    end

    # Public: Initializes a new instance of a given model. Provided keyword
    # arguments are provided to fields if a field matching the key exists.
    def initialize(**kwargs)
      self.class.define_fields
      kwargs.each { |k, v| send("#{k}=", v) if respond_to? "#{k}=" }
    end

    def inspect
      values = self.class.columns.map { |c| "#{c.name}: #{send(c.name).inspect}" }
      "#<#{self.class.name}:#{format("0x%08x", object_id * 2)} #{values.join(", ")}>"
    end

    # Internal: Convenience method that returns self.class.primary_key
    def primary_key
      self.class.primary_key
    end

    class << self
      # Internal: Returns the table name for this model.
      def table_name
        Inflector.snakefy(Inflector.pluralize(find_record_subclass.name))
      end

      # Internal: Returns the name of the primary key for the table.
      def primary_key
        :id
      end

      protected

      # Internal: Iterates the hierarchy tree in order to find the closest
      # class inheriting from Record
      def find_record_subclass
        klass = self
        return self if self == Record

        while klass.superclass != Record
          klass = klass.superclass
          if klass == Object
            klass = nil
            break
          end
        end
        if klass.nil?
          raise InvalidHierarchyError, "Could not find a direct hierarchy between" \
                                       "#{self.class} and Datum::Record"
        end
        klass
      end
    end
  end
end
