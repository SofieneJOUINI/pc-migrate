# Review checklist

Go through this list before saying a task is done. Fix every "no" or explain why it doesn't apply. The codes (G5, F3...) refer to https://sofienejouini.github.io/docs/code-smells.html.

## Tests
- [ ] Every behavior was driven by a test written first. There's no production branch without a test (T1, T2).
- [ ] Unit tests use in-memory adapters and fakes, with no Spring context and no mocks of domain collaborators.
- [ ] Every error the handler can raise has a unit test. Every error reachable over HTTP has a REST contract test.
- [ ] Boundaries are covered: empty collections, zero or negative amounts, date edges, duplicates, concurrency/lock (T5).
- [ ] Test names read as sentences (`should...When...`), with Given / When / Then and one concept per test.
- [ ] `mvn test` is green. `mvn verify` (with containers) is green, or it was reported that Docker wasn't available.
- [ ] No `@Disabled` tests or skipped assertions (G4, T4 only with an explicit question).

## Architecture
- [ ] `domain/` imports nothing from Spring, R2DBC, Jackson, `adapters/`, `database/`, or `infrastructure/`.
- [ ] Handlers depend only on ports, domain types, and kernel classes.
- [ ] Every new port has a real adapter (`@Component`) and an in-memory twin that behave the same way (LSP).
- [ ] Ports are narrow and named after what the client needs (ISP).
- [ ] Controllers contain no business logic and only translate HTTP or events into commands and queries.
- [ ] One slice = one package. No cycles between packages (ADP).
- [ ] New tables were added to the test init SQL and to `TABLES_TO_CLEAN` in `IntegrationTest`.
- [ ] New events are documented (name, payload, producer, consumers) in the README or an AsyncAPI document.

## Multi-tenancy (only for multi-tenant projects)
- [ ] The tenant comes only from the driving adapter (path, or the verified token) and travels in `UseCaseContext`. Nothing reads it from a global.
- [ ] Every port method on tenant-owned data is scoped by `TenantId`, in both the real and the in-memory adapter.
- [ ] Every tenant-owned table has `tenant_id NOT NULL`, and every SQL query filters on it. Indexes start with `tenant_id`.
- [ ] Another tenant's record is reported as not found (404). There's a unit and an E2E isolation test.
- [ ] Event controllers build the context from the event (`toUseCaseContext()`), and events published to a broker carry the tenant.
- [ ] No `if`/`switch` on a specific tenant. Tenant differences come from a settings port or a strategy.

## Clean Code
- [ ] Names are intention-revealing, pronounceable, searchable, and consistent (one word per concept) (N1–N7).
- [ ] Functions are small, do one thing, and have 0–2 arguments. No flag arguments or output arguments (F1–F3, G30).
- [ ] No magic numbers or strings. Constants for error codes, event names, and config keys (G25).
- [ ] No duplication (G5). No dead code or unused parameters (G9, F4). No commented-out code (C5).
- [ ] Conditionals are encapsulated and positive (G28, G29). A switch on type became polymorphism (G23).
- [ ] No chains like `a.getB().getC()` (G36). No feature envy (G14).
- [ ] Value objects replace primitives with business meaning, and they validate themselves.
- [ ] Errors are typed with stable codes. Nothing is swallowed. Infrastructure errors are mapped at the adapter.
- [ ] Time and ids come through ports. No `Instant.now()` or `UUID.randomUUID()` inside handlers or entities.
- [ ] No `block()` in production code.
- [ ] Comments only state constraints the code can't express (C1–C4).

## Delivery
- [ ] README explains the purpose, how to build, run and test, and the endpoints and events.
- [ ] Configuration keys have sensible defaults in `application.properties` and local overrides in `application-local.properties`.
- [ ] The summary to the user lists the created slices, ports, adapters and tests, plus anything left undone.
