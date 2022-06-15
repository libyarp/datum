# frozen_string_literal: true

module Datum
  # Internal: DSN represents a DSN string broken into its components
  class DSN
    def self.query_parser
      @query_parser ||= ::Datum::DSNQueryParser.make_default(32)
    end

    attr_reader :type, :username, :password, :host, :port, :database_name, :options, :raw_database_name

    def initialize(uri)
      @type = uri.scheme
      @username, @password = uri.userinfo.split(":") unless uri.userinfo.nil?
      @host = uri.host
      @port = uri.port
      @raw_database_name = uri.path
      @database_name = @raw_database_name.gsub(%r{^/}, "")
      @options = self.class.query_parser.parse_query(uri.query)
    end
  end
end
