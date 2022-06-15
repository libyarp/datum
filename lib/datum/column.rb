# frozen_string_literal: true

module Datum
  # Public: Column represents a single column from a database
  class Column
    attr_reader :name, :default, :type, :limit

    def initialize(name, default, type: nil, limit: nil)
      @name = name
      @default = default
      @type = simplify_type(type)
      @limit = limit
      @limit = extract_limit(type) if @limit.nil? && !type.nil?
    end

    def simplify_type(field_type)
      case field_type
      when /tinyint/i # FFS MySQL.
        extract_limit(field_type) == 1 ? :boolean : :integer
      when /(big)?int/i
        :integer
      when /float|double|decimal|numeric|real|money/i
        :float
      when /datetime/i, /timestamp with time zone/i, /time/i
        :datetime
      when /date/i, /timestamp without time zone/i
        :date
      when /(c|b)lob/i, /text/i
        :text
      when /char/i, /string/i, /interval/i
        :string
      when /bool(ean)?/i
        :boolean
      end
    end

    def extract_limit(sql_type)
      Regexp.last_match(1).to_i if sql_type =~ /\((.*)\)/
    end
  end
end
