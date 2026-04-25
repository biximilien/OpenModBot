require_relative "../plugin"
require_relative "../harassment/read_model"

module ModerationGPT
  module Plugins
    class HarassmentPlugin < Plugin
      attr_reader :read_model

      def initialize(read_model: Harassment::ReadModel.new)
        @read_model = read_model
      end

      def record_classification(event:, record:)
        @read_model.ingest(event:, record:)
      end

      def get_user_risk(user_id)
        @read_model.get_user_risk(user_id)
      end

      def get_pair_relationship(user_a, user_b)
        @read_model.get_pair_relationship(user_a, user_b)
      end

      def recent_incidents(channel_id, limit: 10)
        @read_model.recent_incidents(channel_id, limit:)
      end
    end
  end
end
