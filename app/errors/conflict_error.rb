# the request clashes with the record's current state (e.g. it was archived or changed by another request)
class ConflictError < ApplicationError; end
