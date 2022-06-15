# frozen_string_literal: true

module Datum
  # RecordEnumerator implements a simple Enumerable providing mechanisms like
  # batch-loading, filtering, and mapping.
  class RecordEnumerator
    include Enumerable

    def initialize(klass, where:, order:, limit:, batches:)
      @klass = klass
      @where = where
      @order = order
      @limit = limit
      @batches = batches
      @cursor = nil
    end

    def each
      loop do
        items = @klass.connection.select(
          @klass.table_name,
          where: @where,
          order: @where,
          limit: @batches || @limit,
          skip: @cursor
        )
        break if items.empty?

        @cursor ||= 0

        @klass.cast_results(items)
              .each do |record|
          break if @batches && @limit && @cursor >= @limit

          @cursor += 1
          yield(record)
        end
        break if @batches.nil? || (@batches && @limit && @cursor >= @limit)
      end
    end
  end
end
