module Harassment
  class CompositeSignalAnalyzer
    BURST_WINDOW_SECONDS = 5 * 60
    PERSISTENCE_WINDOW_SECONDS = 24 * 60 * 60

    WEIGHTS = {
      asymmetry: 0.3,
      persistence: 0.2,
      burst_intensity: 0.2,
      target_concentration: 0.15,
      average_severity: 0.15,
    }.freeze

    def initialize(read_model:, incident_query: read_model)
      @read_model = read_model
      @incident_query = incident_query
    end

    def analyze_user(server_id, user_id, as_of: Time.now.utc)
      incidents = @incident_query.incidents_for_author(server_id, user_id)
      outgoing_edges = @read_model.outgoing_relationships(server_id, user_id, as_of:)
      incoming_edges = @read_model.incoming_relationships(server_id, user_id, as_of:)

      signals = {
        asymmetry: asymmetry_score(outgoing_edges:, incoming_edges:),
        persistence: persistence_score(incidents:, as_of:),
        burst_intensity: burst_intensity_score(incidents:, as_of:),
        target_concentration: target_concentration_score(incidents:),
        average_severity: average_severity_score(incidents:),
      }

      {
        score_version: outgoing_edges.first&.score_version || incoming_edges.first&.score_version || read_model_score_version,
        signals: signals,
        harassment_score: weighted_score(signals),
        relationship_count: outgoing_edges.length,
      }
    end

    private

    def read_model_score_version
      return @read_model.score_version if @read_model.respond_to?(:score_version)

      raise ArgumentError, "read model must expose score_version when no relationships are available"
    end

    def asymmetry_score(outgoing_edges:, incoming_edges:)
      outgoing = outgoing_edges.sum(&:hostility_score)
      incoming = incoming_edges.sum(&:hostility_score)
      total = outgoing + incoming
      return 0.0 if total.zero?

      clamp01((outgoing - incoming) / total)
    end

    def persistence_score(incidents:, as_of:)
      recent_weight = incidents_in_window(incidents, as_of:, window_seconds: PERSISTENCE_WINDOW_SECONDS)
                      .sum { |incident| incident.severity_score * incident.confidence }
      clamp01(recent_weight / 3.0)
    end

    def burst_intensity_score(incidents:, as_of:)
      burst_weight = incidents_in_window(incidents, as_of:, window_seconds: BURST_WINDOW_SECONDS)
                     .sum { |incident| incident.severity_score * incident.confidence }
      clamp01(burst_weight / 2.0)
    end

    def target_concentration_score(incidents:)
      target_counts = Hash.new(0)
      total_targeted_incidents = 0

      incidents.each do |incident|
        next if incident.target_user_ids.empty?

        total_targeted_incidents += 1
        incident.target_user_ids.each { |target_user_id| target_counts[target_user_id] += 1 }
      end

      return 0.0 if total_targeted_incidents.zero?

      target_counts.values.max.to_f / total_targeted_incidents
    end

    def average_severity_score(incidents:)
      return 0.0 if incidents.empty?

      incidents.sum { |incident| incident.severity_score * incident.confidence } / incidents.length
    end

    def incidents_in_window(incidents, as_of:, window_seconds:)
      window_start = as_of.utc - window_seconds
      incidents.select { |incident| incident.classified_at >= window_start && incident.classified_at <= as_of.utc }
    end

    def weighted_score(signals)
      clamp01(
        signals.sum { |signal, value| WEIGHTS.fetch(signal) * value },
      )
    end

    def clamp01(value)
      [[value.to_f, 0.0].max, 1.0].min
    end
  end
end
