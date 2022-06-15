# frozen_string_literal: true

module Datum
  # Internal: Dirty implements methods for handling model states
  module Dirty
    def self.extended(base)
      base.include(InstanceMethods)
    end

    def define_field(col)
      class_exec do
        define_method(col.name.to_s) { instance_variable_get("@#{col.name}") }

        define_method("#{col.name}=") do |val|
          @state ||= {}
          @dirty ||= {}
          return val if val == @state[col.name]

          instance_variable_set("@#{col.name}", val)
          @dirty[col.name] = true
          return val
        end

        define_method("#{col.name}_changed?") { @dirty.include? col.name }
      end
    end

    # Methods implemented as instance methods for classes extending this module
    module InstanceMethods
      # Public: Returns a list of fields changed
      def changed_fields
        @dirty.keys
      end

      # Internal: Resets all dirty status for fields on this instance
      def reset_changed_fields
        @dirty = {}
        @state.each_key { |k| @state[k] = send(k) }
      end
    end
  end
end
