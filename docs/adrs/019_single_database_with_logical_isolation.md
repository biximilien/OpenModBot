# ADR-019: Single Database with Logical Isolation (Initial Phase)

_Status_: Accepted
_Context_: Early-stage system does not justify full physical isolation per tenant.

_Decision_:
Use a single Postgres instance in the initial phase, with logical tenant isolation enforced through `guild_id` and application/query discipline.

_Clarifications_:

- This ADR is about physical deployment strategy, not the logical tenant model itself
- `guild_id` scoping rules are defined by ADR-018
- Declarative partitioning may be introduced later for operational or performance reasons, but is not required by this decision
- Message identifiers should be treated as tenant-scoped unless a stronger global uniqueness contract is explicitly adopted

_Future options_:

- Add table partitioning by tenant or time window
- Migrate high-volume tenants to separate databases or schemas if scale or compliance requires it

_Consequences_:

- Lower operational overhead in the initial phase
- Easier migrations and shared operational tooling
- Risk of noisy-neighbor and blast-radius effects if tenant growth is uneven
