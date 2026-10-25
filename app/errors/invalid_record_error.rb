# the caller sent bad data; the record carries the errors
class InvalidRecordError < ApplicationError
  attr_reader :record

  def initialize(record)
    @record = record
    super(record.errors.full_messages.to_sentence)
  end
end
