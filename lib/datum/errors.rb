# frozen_string_literal: true

module Datum
  class Error < StandardError; end
  class RecordNotFound < Error; end
  class InvalidHierarchyError < Error; end
  class ConnectionNotEstablished < Error; end
  class UnavailableAdapter < Error; end
  class UnsupportedValue < Error; end
  class InvalidStatement < Error; end
  class UnsupportedKeywordArguments < Error; end
  class MigrationDirectoryNotSet < Error; end
  class AsymmetricalMigration < Error; end

  # ErrorMessages provides formatters and utility methods for composing error
  # messages.
  module ErrorMessages
    FIND_NOT_FOUND_SINGLE = "Could not find %s with %s='%s'"
    FIND_NOT_FOUND_MULTIPLE = "Could not find all %s records with %s=(%s) " \
                              "(obtained %s results, but expected %s)"
    FIND_BY_NOT_FOUND = "Could not find %s with %s"
    LOAD_GENERIC = "Could not find %s"

    def self.find_not_found(type, ids, have)
      if ids.length == 1
        format(FIND_NOT_FOUND_SINGLE, type.name, type.primary_key, ids.first)
      else
        format(FIND_NOT_FOUND_MULTIPLE, type.name, type.primary_key, ids.join(", "), have, ids.length)
      end
    end

    def self.dump_value(val)
      case val
      when String
        val.dump
      when TrueClass
        "'t'"
      when FalseClass
        "'f'"
      when Integer, Float
        val.to_s
      else
        dump_value(val.to_s)
      end
    end

    def self.find_by_not_found(type, conditions)
      components = conditions
                   .map { |k, v| [k, type.connection.normalize_value(v)] }
                   .map do |k, v|
        ["'#{k}'", if v.is_a?(Array)
                     " IN (#{v.map { |val| dump_value(val) }.join(", ")})"
                   else
                     " = #{dump_value(v)}"
                   end]
      end
                   .map(&:join)
      format(FIND_BY_NOT_FOUND, type.name, components.join(", "))
    end

    def self.generic_no_query(type)
      LOAD_GENERIC % type.name
    end
  end
end
