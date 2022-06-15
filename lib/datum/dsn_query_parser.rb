# frozen_string_literal: true

module Datum
  # Stolen from Rack (https://github.com/rack/rack)
  #
  # Copyright (C) 2007-2021 Leah Neukirchen <http://leahneukirchen.org/infopage.html>
  #
  # Permission is hereby granted, free of charge, to any person obtaining a copy
  # of this software and associated documentation files (the "Software"), to
  # deal in the Software without restriction, including without limitation the
  # rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  # sell copies of the Software, and to permit persons to whom the Software is
  # furnished to do so, subject to the following conditions:
  #
  # The above copyright notice and this permission notice shall be included in
  # all copies or substantial portions of the Software.
  #
  # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
  # THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
  # IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
  # CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

  class DSNQueryParser
    DEFAULT_SEP = /& */n.freeze
    COMMON_SEP = { ";" => /; */n, ";," => /[;,] */n, "&" => /& */n }.freeze

    # ParameterTypeError is the error that is raised when incoming structural
    # parameters (parsed by parse_nested_query) contain conflicting types.
    class ParameterTypeError < TypeError; end

    # InvalidParameterError is the error that is raised when incoming structural
    # parameters (parsed by parse_nested_query) contain invalid format or byte
    # sequence.
    class InvalidParameterError < ArgumentError; end

    # ParamsTooDeepError is the error that is raised when params are recursively
    # nested over the specified limit.
    class ParamsTooDeepError < RangeError; end

    def self.make_default(param_depth_limit)
      new(Params, param_depth_limit)
    end

    attr_reader :param_depth_limit

    def initialize(params_class, param_depth_limit)
      @params_class = params_class
      @param_depth_limit = param_depth_limit
    end

    # Stolen from Mongrel, with some small modifications:
    # Parses a query string by breaking it up at the '&'.  You can also use this
    # to parse cookies by changing the characters used in the second parameter
    # (which defaults to '&').
    def parse_query(query, separator = nil, &unescaper)
      unescaper ||= method(:unescape)

      params = make_params

      (query || "").split(separator ? (COMMON_SEP[separator] || /[#{separator}] */n) : DEFAULT_SEP).each do |p|
        next if p.empty?

        k, v = p.split("=", 2).map!(&unescaper)

        if (cur = params[k])
          if cur.instance_of?(Array)
            params[k] << v
          else
            params[k] = [cur, v]
          end
        else
          params[k] = v
        end
      end

      params.to_h
    end

    # parse_nested_query expands a query string into structural types. Supported
    # types are Arrays, Hashes and basic value types. It is possible to supply
    # query strings with parameters of conflicting types, in this case a
    # ParameterTypeError is raised. Users are encouraged to return a 400 in this
    # case.
    def parse_nested_query(query, separator = nil)
      params = make_params

      unless query.nil? || query.empty?
        (query || "").split(separator ? (COMMON_SEP[separator] || /[#{separator}] */n) : DEFAULT_SEP).each do |p|
          k, v = p.split("=", 2).map! { |s| unescape(s) }

          _normalize_params(params, k, v, 0)
        end
      end

      params.to_h
    rescue ArgumentError => e
      raise InvalidParameterError, e.message, e.backtrace
    end

    # normalize_params recursively expands parameters into structural types. If
    # the structural types represented by two different parameter names are in
    # conflict, a ParameterTypeError is raised.  The depth argument is deprecated
    # and should no longer be used, it is kept for backwards compatibility with
    # earlier versions of rack.
    def normalize_params(params, name, v, _depth = nil)
      _normalize_params(params, name, v, 0)
    end

    def _normalize_params(params, name, v, depth)
      raise ParamsTooDeepError if depth >= param_depth_limit

      if !name
        # nil name, treat same as empty string (required by tests)
        k = after = ""
      elsif depth.zero?
        # Start of parsing, don't treat [] or [ at start of string specially
        if (start = name.index("[", 1))
          # Start of parameter nesting, use part before brackets as key
          k = name[0, start]
          after = name[start, name.length]
        else
          # Plain parameter with no nesting
          k = name
          after = ""
        end
      elsif name.start_with?("[]")
        # Array nesting
        k = "[]"
        after = name[2, name.length]
      elsif name.start_with?("[") && (start = name.index("]", 1))
        # Hash nesting, use the part inside brackets as the key
        k = name[1, start - 1]
        after = name[start + 1, name.length]
      else
        # Probably malformed input, nested but not starting with [
        # treat full name as key for backwards compatibility.
        k = name
        after = ""
      end

      return if k.empty?

      v ||= +""

      if after == ""
        return [v] if k == "[]" && depth != 0

        params[k] = v
      elsif after == "["
        params[name] = v
      elsif after == "[]"
        params[k] ||= []
        unless params[k].is_a?(Array)
          raise ParameterTypeError,
                "expected Array (got #{params[k].class.name}) for param `#{k}'"
        end

        params[k] << v
      elsif after.start_with?("[]")
        # Recognize x[][y] (hash inside array) parameters
        unless after[2] == "[" &&
               after.end_with?("]") &&
               (child_key = after[3, after.length - 4]) &&
               !child_key.empty? &&
               !child_key.index("[") &&
               !child_key.index("]")
          # Handle other nested array parameters
          child_key = after[2, after.length]
        end
        params[k] ||= []
        unless params[k].is_a?(Array)
          raise ParameterTypeError,
                "expected Array (got #{params[k].class.name}) for param `#{k}'"
        end

        if params_hash_type?(params[k].last) && !params_hash_has_key?(params[k].last, child_key)
          _normalize_params(params[k].last, child_key, v, depth + 1)
        else
          params[k] << _normalize_params(make_params, child_key, v, depth + 1)
        end
      else
        params[k] ||= make_params
        unless params_hash_type?(params[k])
          raise ParameterTypeError,
                "expected Hash (got #{params[k].class.name}) for param `#{k}'"
        end

        params[k] = _normalize_params(params[k], after, v, depth + 1)
      end

      params
    end

    private :_normalize_params

    def make_params
      @params_class.new
    end

    def new_depth_limit(param_depth_limit)
      self.class.new @params_class, param_depth_limit
    end

    private

    def params_hash_type?(obj)
      obj.is_a?(@params_class)
    end

    def params_hash_has_key?(hash, key)
      return false if /\[\]/.match?(key)

      key.split(/[\[\]]+/).inject(hash) do |h, part|
        next h if part == ""
        return false unless params_hash_type?(h) && h.key?(part)

        h[part]
      end

      true
    end

    def unescape(str)
      ::URI.decode_www_form_component(str, Encoding::UTF_8)
    end

    class Params
      def initialize
        @size   = 0
        @params = {}
      end

      def [](key)
        @params[key]
      end

      def []=(key, value)
        @params[key] = value
      end

      def key?(key)
        @params.key?(key)
      end

      # Recursively unwraps nested `Params` objects and constructs an object
      # of the same shape, but using the objects' internal representations
      # (Ruby hashes) in place of the objects. The result is a hash consisting
      # purely of Ruby primitives.
      #
      #   Mutation warning!
      #
      #   1. This method mutates the internal representation of the `Params`
      #      objects in order to save object allocations.
      #
      #   2. The value you get back is a reference to the internal hash
      #      representation, not a copy.
      #
      #   3. Because the `Params` object's internal representation is mutable
      #      through the `#[]=` method, it is not thread safe. The result of
      #      getting the hash representation while another thread is adding a
      #      key to it is non-deterministic.
      #
      def to_h
        @params.each do |key, value|
          case value
          when self
            # Handle circular references gracefully.
            @params[key] = @params
          when Params
            @params[key] = value.to_h
          when Array
            value.map! { |v| v.is_a?(Params) ? v.to_h : v }
          end
        end
        @params
      end
      alias to_params_hash to_h
    end
  end
end
