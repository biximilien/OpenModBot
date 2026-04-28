require "harassment/risk/composite_signal_analyzer"
require "harassment/risk/decay_policy"
require "harassment/risk/read_model"

describe Harassment::CompositeSignalAnalyzer do
  subject(:analyzer) { described_class.new(read_model: read_model) }

  let(:read_model) { Harassment::ReadModel.new(decay_policy: Harassment::DecayPolicy.new(lambda_value: 0.0)) }


  def build_event(message_id:, author_id:, target_user_ids:, classified_at:, severity_score:, confidence:, channel_id: 789)
    event = Harassment::InteractionEvent.build(
      message_id: message_id,
      server_id: 456,
      channel_id: channel_id,
      author_id: author_id,
      target_user_ids: target_user_ids,
      raw_content: "message #{message_id}",
    )
    record = Harassment::ClassificationRecord.build(
      server_id: "456",
      message_id: message_id,
      classifier_version: "harassment-v1",
      model_version: "gpt-4o-2024-08-06",
      prompt_version: "harassment-prompt-v1",
      classification: { intent: "aggressive", target_type: "individual" },
      severity_score: severity_score,
      confidence: confidence,
      classified_at: classified_at,
    )
    read_model.ingest(event:, record:)
  end

  it "computes explicit composite signals and a bounded harassment score" do
    build_event(message_id: 1, author_id: 321, target_user_ids: [654], classified_at: Time.utc(2026, 4, 25, 15, 57, 0), severity_score: 0.8, confidence: 0.8)
    build_event(message_id: 2, author_id: 321, target_user_ids: [654], classified_at: Time.utc(2026, 4, 25, 15, 59, 0), severity_score: 0.7, confidence: 0.9)
    build_event(message_id: 3, author_id: 321, target_user_ids: [999], classified_at: Time.utc(2026, 4, 25, 12, 0, 0), severity_score: 0.4, confidence: 0.5)
    build_event(message_id: 4, author_id: 654, target_user_ids: [321], classified_at: Time.utc(2026, 4, 25, 15, 58, 0), severity_score: 0.2, confidence: 0.5)

    analysis = analyzer.analyze_user("456", "321", as_of: Time.utc(2026, 4, 25, 16, 0, 0))

    expect(analysis[:relationship_count]).to eq(2)
    expect(analysis[:signals][:asymmetry]).to be > 0.0
    expect(analysis[:signals][:persistence]).to be > 0.0
    expect(analysis[:signals][:burst_intensity]).to be > 0.0
    expect(analysis[:signals][:target_concentration]).to be_within(0.0001).of(2.0 / 3.0)
    expect(analysis[:signals][:average_severity]).to be > 0.0
    expect(analysis[:harassment_score]).to be_between(0.0, 1.0)
  end

  it "uses the read model score version when the user has no relationships" do
    read_model = Harassment::ReadModel.new(score_version: "harassment-score-v2")
    analyzer = described_class.new(read_model: read_model)

    analysis = analyzer.analyze_user("456", "321", as_of: Time.utc(2026, 4, 25, 16, 0, 0))

    expect(analysis[:score_version]).to eq("harassment-score-v2")
    expect(analysis[:relationship_count]).to eq(0)
  end
end
