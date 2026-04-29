# Architecture Decision Records

ADR numbers are stable identifiers. Superseded ADR files are kept in place so older links, commits, and discussions continue to resolve. New ADRs should use the next unused number.

## Active ADRs

- [ADR-001: Represent User Interactions as Append-Only Events](./001_represent_user_interactions_events.md)
- [ADR-002: Use LLM for Semantic Classification Only](./002_use_llm_for_semantic_classification_only.md)
- [ADR-003: Model Relationships as Directed Edges](./003_model_relationships_as_directed_edges.md)
- [ADR-004: Apply Time Decay to Interaction Scores](./004_apply_time_decay_to_interaction_scores.md)
- [ADR-006: Detect Harassment via Composite Signals](./006_detect_harassment_via_composite_signals.md)
- [ADR-007: Plugin Implements Its Own Read Model](./007_plugin_implements_its_own_read_model.md)
- [ADR-008: Process Classification and Heavy Work Asynchronously](./008_asynchronous_classification_pipeline.md)
- [ADR-009: Context-Aware Classification](./009_context-aware_classification.md)
- [ADR-010: No Automated Enforcement Initially](./010_no_automated_enforcement_initially.md)
- [ADR-011: Privacy and Data Handling Transparency](./011_privacy_and_data_handling_transparency.md)
- [ADR-012: Classification Pipeline Delivery Semantics](./012_classification_pipeline_delivery_semantics.md)
- [ADR-013: Support Postgres as Durable Harassment Store with JSONB for Classification](./013_use_postgres_as_primary_store_with_jsonb_for_classification.md)
- [ADR-015: Version LLM Prompts and Outputs](./015_version_llm_prompts_and_outputs.md)
- [ADR-016: Enforce Strict JSON Schema for LLM Output](./016_enforce_strict_json_schema_for_llm_output.md)
- [ADR-017: Support Reclassification Pipelines](./017_support_reclassification_pipelines.md)
- [ADR-018: Multi-Tenant Isolation at Data Level](./018_multi-tenant_isolation_at_data_level.md)
- [ADR-019: Single Database with Logical Isolation](./019_single_database_with_logical_isolation.md)
- [ADR-020: Rate-Limit and Cache LLM Calls](./020_rate-limit_and_cache_llm_calls.md)
- [ADR-023: Expose Moderation Insights via Read API](./023_expose_moderation_insights_via_read_api.md)
- [ADR-024: Keep Scoring Logic Deterministic and Versioned](./024_keep_scoring_logic_deterministic_and_versioned.md)
- [ADR-025: Use Optional Infrastructure Plugins for Shared Services](./025_optional_infrastructure_plugins.md)
- [ADR-026: Optional Admin Notifications for Moderator Attention](./026_optional_admin_notifications.md)

## Superseded ADRs

- [ADR-005: Separate Event Storage from Aggregated State](./005_separate_event_storage_from_aggregated_state.md), folded into ADR-001
- [ADR-014: Maintain Append-Only Event Store](./014_maintain_append-only_event_store.md), folded into ADR-001
- [ADR-021: Use Background Workers for All Heavy Processing](./021-use_background_workers_for_all_heavy_processing.md), folded into ADR-008
- [ADR-022: Store Minimal Necessary Message Content](./022_store_minimal_necessary_message_content.md), folded into ADR-011
