# frozen_string_literal: true

module Datum
  # Internal: Lifecycle implements basic lifecycle methods for models.
  module Lifecycle
    # Public: Returns whether the current instance has already been saved to the
    # database.
    def persisted?
      @__persisted || !send(primary_key).nil?
    end

    # Public: Inserts or updates the current record as needed.
    def save
      klass = self.class

      if persisted?
        self.updated_at = Time.now if klass.has_timestamp_columns?

        to_update = changed_fields.filter_map do |k|
          col = klass.columns.find { |c| c.name == k }
          next unless col

          [k, connection.cast_to_adapter(send(k), col)]
        end.to_h

        connection.update_model(self, to_update)
        reset_changed_fields
      else
        if klass.has_timestamp_columns?
          self.created_at = Time.now if created_at.nil?
          self.updated_at = Time.now if updated_at.nil?
        end

        to_insert = changed_fields.filter_map do |k|
          col = klass.columns.find { |c| c.name == k }
          next unless col

          [k, connection.cast_to_adapter(send(k), col)]
        end.to_h
        to_return = to_insert.keys
        to_return += %i[created_at updated_at]
        to_return << klass.primary_key
        to_return.uniq!
        result = connection.insert(klass, to_insert, to_return)
        bulk_set_fields(result)
        reset_changed_fields
        @__persisted = true
      end
    end

    # Public: Sets the provided fields, and invokes #save.
    def update(**kwargs)
      kwargs.each do |k, v|
        send("#{k}=", v)
      end
      save
    end

    # Public: Deletes the current instance from the database.
    def delete
      connection.delete_model(self)
      @_persisted = false
      send("#{self.class.primary_key}=", nil)
      reset_changed_fields
    end
  end
end
