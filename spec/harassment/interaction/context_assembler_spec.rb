require "harassment/interaction/context_assembler"
require "harassment/repositories/in_memory_interaction_event_repository"

describe Harassment::ContextAssembler do
  subject(:assembler) { described_class.new(interaction_events: interaction_events, channel_limit: 2, pair_limit: 2) }

  let(:interaction_events) { Harassment::Repositories::InMemoryInteractionEventRepository.new }

  let(:current_event) do
    Harassment::InteractionEvent.build(
      message_id: 200,
      server_id: 456,
      channel_id: 789,
      author_id: 321,
      target_user_ids: [654],
      timestamp: Time.utc(2026, 4, 25, 16, 5, 0),
      raw_content: "leave them alone",
    )
  end

  before do
    [
      Harassment::InteractionEvent.build(
        message_id: 101,
        server_id: 456,
        channel_id: 789,
        author_id: 999,
        target_user_ids: [321],
        timestamp: Time.utc(2026, 4, 25, 16, 1, 0),
        raw_content: "calm down",
      ),
      Harassment::InteractionEvent.build(
        message_id: 102,
        server_id: 456,
        channel_id: 789,
        author_id: 654,
        target_user_ids: [321],
        timestamp: Time.utc(2026, 4, 25, 16, 2, 0),
        raw_content: "what's your problem?",
      ),
      Harassment::InteractionEvent.build(
        message_id: 103,
        server_id: 456,
        channel_id: 790,
        author_id: 321,
        target_user_ids: [654],
        timestamp: Time.utc(2026, 4, 25, 16, 3, 0),
        raw_content: "back off",
      ),
      Harassment::InteractionEvent.build(
        message_id: 104,
        server_id: 999,
        channel_id: 789,
        author_id: 321,
        target_user_ids: [654],
        timestamp: Time.utc(2026, 4, 25, 16, 4, 0),
        raw_content: "wrong server",
      ),
    ].each { |event| interaction_events.save(event) }
  end

  it "builds bounded transient context with pseudonymous labels" do
    context = assembler.build_for(current_event)

    expect(context[:participant_labels]).to eq(
      "321" => "author",
      "654" => "target_1",
    )
    expect(context[:recent_channel_messages].map { |entry| entry[:content] }).to eq([
                                                                                      "calm down",
                                                                                      "what's your problem?",
                                                                                    ])
    expect(context[:recent_channel_messages].map { |entry| entry[:author_label] }).to eq(%w[
                                                                                           participant_3
                                                                                           target_1
                                                                                         ])
    expect(context[:recent_pair_interactions].map { |entry| entry[:content] }).to eq([
                                                                                       "what's your problem?",
                                                                                       "back off",
                                                                                     ])
  end
end
