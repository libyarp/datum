# frozen_string_literal: true

module Datum
  # Internal: QueryProxy provides a simple proxy that allows queries to be
  # conveniently created by chaining methods. This class does not intend to
  # replace SQL; in order to perform complex queries, SQL is required.
  class QueryProxy
    # Internal: Creates a new instance of the proxy for a given class
    def initialize(klass)
      @klass = klass
    end

    # Public: Filters records through provided fields, or by a provided query
    # and bindings.
    #
    # For example:
    #
    #   User.where(active: true).count
    #   # => SELECT COUNT(*) FROM users WHERE active = true
    #   User.where("active = ? OR email = ?", true, "email@example.com").count
    #   # => SELECT COUNT(*) FROM users WHERE (active = ? OR email = 'email@example.com')
    #
    # Returns the same QueryProxy object
    def where(*args, **kwargs)
      @where = if !args.empty? && !kwargs.empty?
                 raise ArgumentError, "#where supports either arguments, or keyword arguments; not both"
               elsif args.empty? && kwargs.empty?
                 nil
               elsif !args.empty?
                 if args.last.is_a? Hash
                   raise ArgumentError,
                         "#where supports either arguments, or keyword arguments; not both"
                 end

                 { kind: :sql, sql: args.first, args: args[1...] }
               elsif args.empty?
                 { kind: :conditions, conditions: kwargs }
               end
      self
    end

    # Public: Orders records by provided columns and ordering methods.
    #
    # For example:
    #
    #   User.order_by(created_at: :desc)
    #   # => SELECT * FROM users ORDER BY created_at DESC
    #
    # Returns the same QueryProxy object
    def order_by(**columns)
      @order = columns.empty? ? nil : columns
      self
    end

    # Public: Limits returned values by a given number
    #
    # by - Maximum number of records to return
    #
    # Returns the same QueryProxy object
    def limit(by)
      @limit = if by.nil? || by.is_a?(Integer)
                 by
               else
                 raise ArgumentError, "Invalid value for #limit; expected an integer"
               end
      self
    end

    # Public: Skips a given amount of records. This usually sets an OFFSET
    # clause on generated queries, and MUST be used together with #limit
    #
    # amount - Amount to skip
    #
    # Returns the same QueryProxy object
    def skip(amount)
      @skip = if amount.nil? || amount.is_a?(Integer)
                amount
              else
                raise ArgumentError, "Invalid value for #skip; expected an integer"
              end
      self
    end

    # Public: When used together with enumerations, defines how many records
    # should be loaded per iteration.
    #
    # Returns the same QueryProxy object
    def in_batches_of(qty)
      @batches = qty
      self
    end

    # -------------------------------------------------------------------

    # Internal: Executes the query with information from this instance.
    def do_select
      @klass.connection.select(
        @klass.table_name,
        name: "#{@klass.name} Load",
        where: @where,
        order: @order,
        limit: @limit,
        skip: @skip
      )
    end

    # Internal: Raises a RecordNotFound exception based on conditions provided
    # to this instance.
    def not_found!
      raise RecordNotFound, ErrorMessages.generic_no_query(@klass) if @where.nil?

      raise RecordNotFound, ErrorMessages.find_by_not_found(@klass, @where)
    end

    # Public: Returns the first N results from the query
    #
    # limit - Optional amount of records to return. Defaults to 1
    #
    # Returns an array of model instances in case limit is greater than one,
    # or a single instance otherwise. This method generates and executes
    # database queries.
    def first(limit = 1)
      limit ||= 1
      return [] if limit&.zero?

      @limit = limit
      @batches = nil
      @klass.cast_results(do_select, single: limit == 1)
    end

    # Public: Returns the first result from the query, or raises RecordNotFound
    # in case no results are obtained.
    #
    # Returns a single model instance. This method generates and executes
    # database queries.
    def first!
      first.tap do |i|
        not_found! if i.nil?
      end
    end

    # Public: Returns the last N results from the query
    #
    # limit - Optional amount of records to return. Defaults to 1
    #
    # Returns an array of model instances in case limit is greater than one,
    # or a single instance otherwise. This method generates and executes
    # database queries.
    def last(limit = 1)
      limit ||= 1
      return [] if limit&.zero?

      @order = { @klass.primary_key => :desc }
      @limit = limit
      @batches = nil
      @klass.cast_results(do_select, single: limit == 1)
    end

    # Public: Returns the last result from the query, or raises RecordNotFound
    # in case no results are obtained.
    #
    # Returns a single model instance. This method generates and executes
    # database queries.
    def last!
      last.tap do |i|
        not_found! if i.nil?
      end
    end

    # Public: Deletes all objects that matches provided conditions.
    # Raises ArgumentError in case #limit, #order, or #in_batches_of has been
    # set.
    #
    # Returns nothing. This method generates and executes database queries.
    def delete
      raise ArgumentError("Cannot use #delete with #limit") if @limit
      raise ArgumentError("Cannot use #delete with #order") if @order
      raise ArgumentError("Cannot use #delete with #in_batches_of") if @batches

      @klass.connection.delete(@klass.table_name,
                               name: "#{@klass.name} Delete",
                               where: @where)
    end

    # Public: Updates all objects that matches provided conditions with values
    # provided through keyword arguments.
    # Raises ArgumentError in case #limit, #order, or #in_batches_of has been
    # set.
    #
    # Returns nothing. This method generates and executes database queries.
    def update(**values)
      raise ArgumentError("Cannot use #update with #limit") if @limit
      raise ArgumentError("Cannot use #update with #order") if @order
      raise ArgumentError("Cannot use #update with #in_batches_of") if @batches

      values[:updated_at] = Time.now.utc if @klass.has_timestamp_columns? && !values.key?(:updated_at)

      values = values.filter_map do |k, v|
        col = @klass.columns.find { |c| c.name == k }
        next nil if col.nil?

        [k, @klass.connection.cast_to_adapter(v, col)]
      end.to_h

      @klass.connection.update(@klass.table_name,
                               name: "#{@klass.name} Update",
                               where: @where,
                               values: values)
    end

    # Public: Returns the number of records matching provided conditions with
    # values provided through keyword arguments.
    # Raises ArgumentError in case #limit, #order, or #in_batches_of has been
    # set.
    #
    # Returns nothing. This method generates and executes database queries.
    def count
      raise ArgumentError("Cannot use #count with #limit") if @limit
      raise ArgumentError("Cannot use #count with #order") if @order
      raise ArgumentError("Cannot use #count with #in_batches_of") if @batches

      @klass.connection.count(@klass.table_name,
                              name: "#{@klass.name} Count",
                              where: @where)
    end

    # Public: Returns the amount of records returned by the query. This method
    # is a convenience method for #to_a.length.
    #
    # This method generates and executes database queries.
    def length
      to_a.length
    end

    # Enumerator-ish

    # Public: Returns all records matching specified criteria as an array of
    # model instances.
    #
    # This method generates and executes database queries.
    def to_a
      @batches = nil
      @klass.cast_results(do_select)
    end

    alias all to_a

    # Public: Executes the provided block for each record matching the specified
    # criteria.
    def each(&block)
      to_enum.each(&block)
    end

    # Public: Executes the provided block for each record matching the specified
    # criteria, returning an array of values returned by such block.
    def map(&block)
      to_enum.map(&block)
    end

    # Public: Returns a RecordEnumerator instance for specified criteria.
    def to_enum
      RecordEnumerator.new(@klass,
                           where: @where,
                           order: @where,
                           limit: @limit,
                           batches: @batches)
    end

    def inspect
      to_a.inspect
    end
  end
end
