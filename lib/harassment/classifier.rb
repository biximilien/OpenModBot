module Harassment
  class Classifier
    def classify(_event:, _classifier_version:, context: nil, classified_at: Time.now.utc)
      raise NotImplementedError, "#{self.class} must implement #classify"
    end

    def cache_identity
      { classifier_class: self.class.name }
    end
  end
end
