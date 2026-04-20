require "digest"
require_relative "../../environment"

module Telemetry
  module Anonymizer
    module_function

    def hash(value)
      Digest::SHA256.hexdigest("#{Environment.telemetry_hash_salt}:#{value}")[0, 16]
    end
  end
end
