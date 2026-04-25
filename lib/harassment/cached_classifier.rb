require "digest"
require "json"
require_relative "classifier"
require_relative "classification_record"
require_relative "classifier_version"

module Harassment
  class CachedClassifier < Classifier
    def initialize(delegate:, cache_repository:, ttl_seconds:)
      @delegate = delegate
      @cache_repository = cache_repository
      @ttl_seconds = Integer(ttl_seconds)
    end

    def classify(event:, classifier_version:, context: nil, classified_at: Time.now.utc)
      cache_key = cache_key_for(event:, classifier_version:, context:)
      cached_record = @cache_repository.fetch(cache_key, at: classified_at)
      return cached_record if cached_record

      record = @delegate.classify(
        event: event,
        classifier_version: classifier_version,
        context: context,
        classified_at: classified_at,
      )
      @cache_repository.store(cache_key, record, expires_at: classified_at + @ttl_seconds)
      record
    end

    def cache_identity
      @delegate.cache_identity
    end

    private

    def cache_key_for(event:, classifier_version:, context:)
      payload = {
        server_id: event.server_id,
        classifier_version: normalize_classifier_version(classifier_version),
        classifier_identity: deep_sort(@delegate.cache_identity),
        message: {
          raw_content: event.raw_content,
          target_count: event.target_user_ids.length,
        },
        context: deep_sort(context || {}),
      }

      "harassment-cache:#{Digest::SHA256.hexdigest(JSON.generate(payload))}"
    end

    def normalize_classifier_version(value)
      case value
      when ClassifierVersion then value.value
      else ClassifierVersion.build(value).value
      end
    end

    def deep_sort(value)
      case value
      when Hash
        value.keys.map(&:to_s).sort.each_with_object({}) do |key, sorted|
          original_key = value.key?(key) ? key : value.keys.find { |candidate| candidate.to_s == key }
          sorted[key] = deep_sort(value.fetch(original_key))
        end
      when Array
        value.map { |item| deep_sort(item) }
      else
        value
      end
    end
  end
end
