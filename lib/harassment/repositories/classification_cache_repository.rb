module Harassment
  module Repositories
    class ClassificationCacheRepository
      def fetch(_cache_key, at: Time.now.utc)
        raise NotImplementedError, "#{self.class} must implement #fetch"
      end

      def store(_cache_key, _record, expires_at:)
        raise NotImplementedError, "#{self.class} must implement #store"
      end
    end
  end
end
