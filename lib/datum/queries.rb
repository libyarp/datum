# frozen_string_literal: true

module Datum
  # Internal: Queries implements simple query functions for Records.
  module Queries
    def self.extended(base)
      instance_methods.each do |met|
        base.define_method(met) do |*args, **kwargs, &block|
          base.send(met, *args, **kwargs, &block)
        end
      end
    end

    # Public: Returns records with provided IDs.
    #
    # ids - IDs to be loaded from the database.
    #
    # Returns a single Model instance in case ids is composed by a single ID,
    # otherwise, returns an array with objects found. Returns nil, in case a
    # single ID is provided and no record with such ID exists. Returns an empty
    # array in case no record matches provided IDs. Otherwise, returns only
    # records found.
    def find(*ids)
      ids.flatten!
      return nil if ids.length.zero?

      where = { primary_key => ids.length == 1 ? ids.first : ids }
      rt = connection.select(table_name, name: "#{name} Load", where: where)
      cast_results(rt, single: ids.length == 1)
    end

    # Public: find! acts like #find, but raises RecordNotFound in case one or
    # more records cannot be found.
    def find!(*ids)
      rt = find(*ids)
      # CAVEAT: after this point, ids will have been flattened by #find

      if rt.nil? || (rt.is_a?(Array) && rt.length != ids.length)
        raise RecordNotFound, ErrorMessages.find_not_found(self, ids, 0)
      end

      rt
    end

    # Public: Returns the first record matching provided criteria, or nil, in
    # case none is found.
    def find_by(**conditions)
      rt = connection.select(table_name, name: "#{name} Load", where: conditions)
      cast_results(rt, single: true)
    end

    # Public: Acts like #find_by, but raises RecordNotFound in case no record is
    # found.
    def find_by!(**conditions)
      find_by(**conditions).tap do |ret|
        raise RecordNotFound, ErrorMessages.find_by_not_found(self, conditions) if ret.nil?
      end
    end

    # Public: Returns the first N records from the database.
    #
    # limit - Optional amount of records to return. Defaults to 1
    #
    # Returns an array of model instances in case limit is greater than one,
    # or a single instance otherwise. This method generates and executes
    # database queries.
    def first(limit = nil)
      where.first(limit)
    end

    # Public: Acts like #first, but raises RecordNotFound in case no records can
    # be found.
    def first!
      where.first!
    end

    # Public: Returns the last N records from the database.
    #
    # limit - Optional amount of records to return. Defaults to 1
    #
    # Returns an array of model instances in case limit is greater than one,
    # or a single instance otherwise. T
    def last(limit = nil)
      where.last(limit)
    end

    # Public: Acts like #last, but raises RecordNotFound in case no records can
    # be found.
    def last!
      where.order_by(primary_key => :desc).last!
    end

    # Public: Returns the first record matching the provided SQL WHERE clause
    # and bindings, or nil, in case none can be found.
    def find_by_sql(sql, *args)
      where(*([sql] + args)).first
    end

    # Public: Acts like #find_by_sql, but raises RecordNotFound in case no
    # records can be found.
    def find_by_sql!(sql, *args)
      where(*([sql] + args)).first!
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
    # Returns a new QueryProxy object
    def where(*args, **kwargs)
      QueryProxy.new(self).where(*args, **kwargs)
    end

    # Public: Executes the provided block within a SQL transaction. Exceptions
    # raised from the block causes the transaction to be rolled-back; if no
    # exception is raised, the transaction is committed, and the value returned
    # from the block is returned by this method.
    def transaction(&block)
      connection.transaction(&block)
    end

    def respond_to_missing?(name, include_private = false)
      QueryProxy.new(self).respond_to?(name, include_private) || super
    end

    def method_missing(name, *args, **kwargs, &block)
      return where.send(name, *args, **kwargs, &block) if QueryProxy.new(self).respond_to?(name)

      super
    end

    # Internal: casts results from a database query to instances of this class.
    def cast_results(items, single: false)
      if single
        i = items&.first
        return nil if i.nil?

        return synthetize(i, connection)
      end

      items&.map { |item| synthetize(item, connection) }
    end
  end
end
