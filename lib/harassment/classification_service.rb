require_relative "classifier_definition"
require_relative "read_model"
require_relative "score_definition"
require_relative "../../environment"

module Harassment
  class ClassificationService
    attr_accessor :read_model

    def initialize(
      read_model: ReadModel.new(score_version: ScoreDefinition::VERSION),
      classifier_definition: ClassifierDefinition.new
    )
      @read_model = read_model
      @classifier_definition = classifier_definition
    end

    def record(event:, record:)
      @read_model.ingest(event:, record:)
    end

    def classifier_version
      @classifier_definition.classifier_version
    end

    def prompt_version
      @classifier_definition.prompt_version
    end

    def build_classifier(client:, model: Environment.harassment_classifier_model)
      @classifier_definition.build(client:, model:)
    end
  end
end
