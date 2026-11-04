# Multi-tenancy (any stack)

## When to use it

Use it when **one deployment holds data for several customers/organizations who must never see each other's data** (SaaS, white-label platforms, one service per market). Users belong to a tenant, they don't replace it. A separate deployment and database per customer is single-tenant, repeated, and needs none of this.

If unsure, ask the user: "Will one running instance hold data for several customers who must never see each other's data?"

## Kernel changes

Apply the "Multi-tenant variant" from `kernel.md`: a `TenantId` value object, the tenant in `UseCaseContext`, `getTenantId()` on commands and queries, the tenant on every domain event (kept by `toUseCaseContext()`), and the tenant in handler logs.

## The rules

1. **The tenant is resolved once, in the driving adapter**, then only travels inside `UseCaseContext`. HTTP adapters take it from the route (`/{tenantId}/...`), a header, or the verified token. Event handlers take it from the event. Handlers and domain code never read it from a global, a thread-local or async-local storage, or the request object.
2. **With authentication, the tenant comes from the verified token**, or a client-supplied tenant is checked against it. Never trust a client-supplied tenant id alone.
3. **Every tenant-owned aggregate is scoped**: either the entity has a `tenantId`, or every port method takes a `TenantId`. Pick one style per project.
4. **Every read and write filters by tenant**, in the real adapter *and* in the in-memory twin. A record from another tenant is reported as **not found** (404), never as forbidden, so ids don't leak between tenants.
5. **Every event carries the tenant.** Consumers rebuild the context from the event. Events leaving the service carry it in the payload or a message header.
6. **Global data is explicit**: shared reference data lives in tables without `tenant_id`, behind ports without `TenantId`, and is named so it's obviously global.
7. **No `if tenant == "x"`.** Tenant-specific behavior comes from a `TenantSettingsPort` and strategies (G23).

## Persistence

- Every tenant-owned table has `tenant_id VARCHAR(64) NOT NULL`. Unique constraints include it (`UNIQUE (tenant_id, order_number)`), and composite indexes start with it.
- Every SQL statement has `WHERE tenant_id = $1`. Consider Postgres row-level security as defense in depth (`SET app.tenant_id` per transaction), but keep the explicit filter anyway.
- Schema-per-tenant or database-per-tenant are only for real requirements (regulation, very large tenants). Keep that routing inside `infrastructure/`, behind the same ports.

## Tests

- The context builder has `withTenantId(...)`, a default tenant (`tenant-a`), and another one (`tenant-b`).
- Every reading slice gets an isolation unit test ("should not find an order of another tenant" → `ORDER.NOT_FOUND`), and one E2E isolation test runs through the real database adapter.
- Every event assertion checks the tenant.
- A contract test covers an invalid tenant id (400 `TENANT_ID.INVALID`).
