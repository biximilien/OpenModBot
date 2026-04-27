module FakePostgres
  module TimeHelpers
    private

    def parse_utc(value)
      Time.parse(value).utc
    end
  end
end
