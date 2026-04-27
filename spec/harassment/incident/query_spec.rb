require "harassment/incident/query"
require "harassment/repositories/in_memory_classification_record_repository"
require "harassment/repositories/in_memory_interaction_event_repository"

describe Harassment::IncidentQuery do
  let(:interaction_events) { Harassment::Repositories::InMemoryInteractionEventRepository.new }
  let(:classification_records) { Harassment::Repositories::InMemoryClassificationRecordRepository.new }

  subject(:query) do
    described_class.new(
      interaction_events: interaction_events,
      classification_records: classification_records,
    )
  end

  before do
    interaction_events.save(
      Harassment::InteractionEvent.build(
        message_id: 123,
        server_id: 456,
        channel_id: 789,
        author_id: 321,
        target_user_ids: [654],
        raw_content: "hello there",
        classification_status: Harassment::ClassificationStatus::CLASSIFIED,
        timestamp: Time.utc(2026, 4, 25, 16, 0, 0),
      ),
    )
    classification_records.save(
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
      ),
    )
  end

  it "reconstructs recent incidents from stored events and classification records" do
    incidents = query.recent_incidents("456", "789")

    expect(incidents.length).to eq(1)
    expect(incidents.first.intent).to eq("aggressive")
    expect(incidents.first.author_id).to eq("321")
  end

  it "reconstructs incidents for author-based signal analysis" do
    incidents = query.incidents_for_author("456", "321")

    expect(incidents.map(&:message_id)).to eq(["123"])
  end

  it "skips classified events that are missing a stored classification record" do
    interaction_events.save(
      Harassment::InteractionEvent.build(
        message_id: 124,
        server_id: 456,
        channel_id: 789,
        author_id: 321,
        target_user_ids: [999],
        raw_content: "missing record",
        classification_status: Harassment::ClassificationStatus::CLASSIFIED,
        timestamp: Time.utc(2026, 4, 25, 16, 1, 0),
      ),
    )

    incidents = query.recent_incidents("456", "789")

    expect(incidents.map(&:message_id)).to eq(["123"])
  end

  it "asks the event repository for scoped classified events" do
    interaction_events = instance_double("InteractionEventRepository")
    classification_records = instance_double("ClassificationRecordRepository", latest_for_message: nil)
    query = described_class.new(interaction_events:, classification_records:)

    allow(interaction_events).to receive(:list_classified_for_server).and_return([])

    query.recent_incidents("456", "789", limit: 3, since: Time.utc(2026, 4, 25, 15, 0, 0))

    expect(interaction_events).to have_received(:list_classified_for_server).with(
      "456",
      channel_id: "789",
      author_id: nil,
      since: Time.utc(2026, 4, 25, 15, 0, 0),
      limit: nil,
    )
  end
end
