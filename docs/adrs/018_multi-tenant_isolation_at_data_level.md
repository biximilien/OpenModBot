# ADR-018: Multi-Tenant Isolation at Data Level

_Status_: Accepted
_Context_: If commercialized, multiple Discord servers (guilds) will use the system.

_Decision_:
All durable harassment-domain tables must include `guild_id`, and all application queries must be tenant-scoped by it.

_Implications_:

- Event, classification, job, and projection tables all carry `guild_id`
- Uniqueness constraints should be defined within tenant scope unless a value is guaranteed globally unique by contract
- Cross-guild joins and reads are forbidden by default
- Access-control checks must align with tenant scoping at the data layer

_Example additions_:

- `interaction_events.guild_id`
- `classification_records.guild_id`
- `relationship_edges.guild_id`

_Composite indexes_:

- `(guild_id, author_id, created_at)`
- `(guild_id, source_user_id, target_user_id)`
- `(guild_id, message_id, classifier_version)` for classification records

_Consequences_:

- Logical isolation between communities
- Cleaner access-control boundaries
- Requires disciplined query construction and review
