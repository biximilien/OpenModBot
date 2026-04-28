require "harassment/relationship/edge_rebuilder"
require "harassment/repositories/in_memory_classification_record_repository"
require "harassment/repositories/in_memory_interaction_event_repository"
require "harassment/repositories/in_memory_relationship_edge_repository"

describe Harassment::RelationshipEdgeRebuilder do
  subject(:rebuilder) do
    described_class.new(
      interaction_events: interaction_events,
      classification_records: classification_records,
      relationship_edges: relationship_edges,
      score_version: "harassment-score-v1",
      server_id: server_id,
    )
  end

  let(:interaction_events) { Harassment::Repositories::InMemoryInteractionEventRepository.new }
  let(:classification_records) { Harassment::Repositories::InMemoryClassificationRecordRepository.new }
  let(:relationship_edges) { Harassment::Repositories::InMemoryRelationshipEdgeRepository.new }


  let(:server_id) { nil }
  let(:classified_event) do
    Harassment::InteractionEvent.build(
      message_id: 123,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      raw_content: "hello there",
      classification_status: Harassment::ClassificationStatus::CLASSIFIED,
      timestamp: Time.utc(2026, 4, 25, 16, 0, 0),
    )
  end
  let(:classified_record) do
    Harassment::ClassificationRecord.build(
      server_id: 456,
      message_id: 123,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "aggressive", target_type: "individual" },
      severity_score: 0.8,
      confidence: 0.5,
      classified_at: Time.utc(2026, 4, 25, 16, 0, 5),
    )
  end

  before do
    interaction_events.save(classified_event)
    classification_records.save(classified_record)
  end

  it "rebuilds relationship edges from classified events and latest records" do
    summary = rebuilder.run

    expect(summary).to eq(
      rebuilt: 1,
      skipped_missing_record: 0,
      skipped_server_scope: 0,
    )
    edge = relationship_edges.find(
      server_id: "456",
      source_user_id: "321",
      target_user_id: "654",
      score_version: "harassment-score-v1",
    )
    expect(edge.hostility_score).to eq(0.4)
    expect(edge.interaction_count).to eq(1)
  end

  it "clears existing edges for the score version before rebuilding" do
    relationship_edges.save(
      Harassment::RelationshipEdge.build(
        server_id: 456,
        source_user_id: 321,
        target_user_id: 654,
        score_version: "harassment-score-v1",
        hostility_score: 9.9,
        interaction_count: 99,
        last_interaction_at: Time.utc(2026, 4, 25, 15, 0, 0),
      ),
    )

    rebuilder.run

    edge = relationship_edges.find(
      server_id: "456",
      source_user_id: "321",
      target_user_id: "654",
      score_version: "harassment-score-v1",
    )
    expect(edge.hostility_score).to eq(0.4)
    expect(edge.interaction_count).to eq(1)
  end

  it "skips classified events that have no matching classification record" do
    interaction_events.save(
      Harassment::InteractionEvent.build(
        message_id: 124,
        server_id: 456,
        channel_id: 789,
        author_id: 999,
        target_user_ids: [111],
        raw_content: "missing record",
        classification_status: Harassment::ClassificationStatus::CLASSIFIED,
        timestamp: Time.utc(2026, 4, 25, 16, 1, 0),
      ),
    )

    summary = rebuilder.run

    expect(summary[:skipped_missing_record]).to eq(1)
  end

  context "with server scoping" do
    let(:server_id) { "456" }

    it "rebuilds only the requested server" do
      interaction_events.save(
        Harassment::InteractionEvent.build(
          message_id: 125,
          server_id: 999,
          channel_id: 888,
          author_id: 777,
          target_user_ids: [666],
          raw_content: "other server",
          classification_status: Harassment::ClassificationStatus::CLASSIFIED,
          timestamp: Time.utc(2026, 4, 25, 16, 2, 0),
        ),
      )
      classification_records.save(
        Harassment::ClassificationRecord.build(
          server_id: 999,
          message_id: 125,
          classifier_version: "harassment-v1",
          model_version: "gpt-4o-2024-08-06",
          prompt_version: "harassment-prompt-v1",
          classification: { intent: "abusive", target_type: "individual" },
          severity_score: 0.5,
          confidence: 0.5,
          classified_at: Time.utc(2026, 4, 25, 16, 2, 5),
        ),
      )

      summary = rebuilder.run

      expect(summary[:rebuilt]).to eq(1)
      expect(summary[:skipped_server_scope]).to eq(1)
      expect(
        relationship_edges.find(
          server_id: "999",
          source_user_id: "777",
          target_user_id: "666",
          score_version: "harassment-score-v1",
        ),
      ).to be_nil
    end
  end
end
