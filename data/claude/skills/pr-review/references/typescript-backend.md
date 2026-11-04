# TypeScript backend (NestJS first; Express/Fastify-friendly) — review rules

Distilled from ~3,300 real review comments on a large NestJS API (2022-2026). Apply to added/changed lines only; read `general.md` first. Rules marked **(if X)** apply only when the repo has X: never assume a convention the repo lacks. Project-specific names/conventions come from a profile fragment (if one exists) or from the "Discover" checklist.

Counts = approximate comments in the source reviews. Severity: blocker = reviewers blocked the PR; major = functional/contract risk, always requested; minor = requested, not blocking; nit = style. In Express/Fastify read "controller" as route handler, "decorator" as middleware/schema, "DTO" as request/response schema (zod/joi/TypeBox/JSON schema).

## Discover in the repo before reviewing
- Layout and path aliases (`@app/...`, tsconfig `paths`, barrel files); layering folders (domain / handlers or services / adapters / database).
- Shared kernel: base entities, value objects, Result/Either types, shared DTOs (money, pagination, ids), shared exceptions.
- Outbound HTTP client wrapper and per-upstream config service (base URL, timeouts).
- Auth: decorators/guards/middleware, where roles/permissions are defined, and where they are provisioned (IdP config repo, migrations, IaC).
- Error classes, base exception types, error-code format, and where codes are catalogued.
- Test doubles (in-memory repos/gateways, fake clock, fake id generator), builders/fixtures, failure-injection helpers.
- E2E/mock setup (supertest, BDD features, mock servers, contract stubs, route files).
- Coverage thresholds (jest config, sonar exclusions) and lint/format config.
- Env example files, config schemas, deployment values (helm/compose/terraform) per environment.
- Conventions for routes, DTO suffixes, error naming; the OpenAPI setup (plugin vs explicit decorators).

---

## A. Layering and architecture

### TS-01 Business rules belong in the domain, not in handlers/gateways (major, ~30)
- Check: business checks (date ordering, thresholds, status transitions, "is applicable") in handlers/services/controllers/gateways. Move to entity method or value object validating in its constructor; handlers orchestrate only.
- Why: feature envy; duplicated checks; entity-level validation runs on every save.
- Ex: `if (qty < MIN) throw` in handler -> `new Quantity(qty)` throws; `order.isDiscountApplicable(f)` not an inline loop.
- Say: "this is domain logic, move it into the entity/value object."

### TS-02 Validate input before any I/O, only when present (minor-major, ~22)
- Check: argument validation (ids, date formats, ranges, page size) must run before any repository/gateway call. Validators are named for what they check, return `void`, are not `async`; optional values validated only when provided (guard at call site, not early-return inside the validator).
- Why: avoids useless DB hits and misleading `Promise<void>` signatures.
- Ex: `await repo.find(); validateDate(q.date)` -> validate first.

### TS-03 Ports/adapters boundaries (major, ~15)
- Check: domain and port files must not mention queues, brokers, SSM/secret stores, URLs, HTTP clients or ORM/transport types. Ports expose intention-revealing, domain-shaped methods; adapters adapt (return `number`, not the raw secret-store payload). Domain events/entities must not carry transport DTOs.
- Ex: queue-name map in a domain port file -> infrastructure/messaging enum.
- Say: "this is infra, not domain."

### TS-04 Repositories only for aggregate roots (if the repo uses DDD aggregates) (major, ~8)
- Check: no repository/factory/unit-of-work for a plain entity or a read-only/ETL-backed concept; repository ports restricted to aggregate roots. Add a method to the owning aggregate's repository, never to an unrelated or generic one.
- Ex: `InvoiceLineRepositoryPort` -> removed ("not an aggregate root"); line query added to the invoice repository.

### TS-05 One gateway per upstream module; reuse before adding (major, ~18)
- Check: before adding a gateway/DTO/port search for an existing one for that upstream or concept and extend it; no near-duplicate `XxxModuleGateway` or re-declared shared DTO (money, pagination, ids). A gateway lives in the owning bounded context and is named after the upstream.
- Say: "no need for a new gateway, use the existing one."

### TS-06 Request/response DTOs are owned by the use case, not the domain (minor-major, ~8)
- Check: each command/query/controller owns its request and response types; domain must not depend on response types; no importing DTOs from another use case's folder; no mapping a DTO to an identical DTO.

### TS-07 Outbound HTTP/gateway rules (major; nit for async style; ~30)
- Check: use the project's shared HTTP client wrapper, not raw axios/fetch per adapter **(if one exists)**; build URLs from the upstream config service, not literals; paths kebab-case plural; verify path/method/payload against the upstream contract; pass the command/query object (or spread its parameters) instead of re-mapping every field; send only the needed identity (username/id), not the whole auth object; handle upstream errors/timeouts explicitly; `await` consistently inside `async` methods.
- Ex: `/${base}/matchedPaymentOrders` -> `/${base}/matched-payment-orders`.
- Say: "this is not the right path"; "did you test this locally against the upstream?"

### TS-08 Domain events vs integration events (major, ~12)
- Check **(if events exist)**: domain events stay inside the bounded context with typed value objects; cross-context messages are integration events with primitive payloads. Event/queue enum names follow one convention and order; registering a new event type also updates the publisher/queue mapping; new integration-event fields must be handled by every consumer.

### TS-09 No duplicated logic across handlers (minor, ~14)
- Check: identical blocks repeated in handlers/event handlers/controllers (id mapping, notification calls) -> extract a private method or shared service.
- Say: "this is duplicated N times, extract it."

---

## B. Controllers, routes, OpenAPI, authorization

### TS-10 Document every real error and only those (major, ~110, most frequent class)
- Check: each endpoint documents success (response type correct: array vs object) and every error it can actually return (400 invalid/empty id or filter, 401/403, 404, 409, 422). Cross-check handler/domain exceptions against the docs; remove statuses it cannot return; list multiple 400 reasons in one description. Business-rule violations are 422 (or 409), not 404/400/406.
- Why: front-end and QA build on the OpenAPI spec.
- Ex: only 200+404 documented -> add 400 "when the id is invalid" and 422 "when the order is already shipped"; `type: [OrderResponse]` on a get-by-id -> `type: OrderResponse`.
- Say: "please add the missing errors"; "we don't return this, remove it."

### TS-11 OpenAPI text accuracy and quality (nit-minor, ~140)
- Check: summary/description/example describe this endpoint (not copy-pasted from a sibling); error descriptions read "when ..."; realistic, enum-valid examples (real id format, codes); units stated (seconds, minutes); correct grammar; no template literals for plain strings.
- Ex: `example: 'SDF5F44GSDF'` for a currency -> `'EUR'`; `'Timeout'` -> `'Timeout in seconds'`.

### TS-12 Group endpoints by resource tag (nit, ~40)
- Check **(if tags are used)**: the tag is the owning resource, same as sibling endpoints; no new tag per feature.

### TS-13 Authorization: least privilege, endpoint-specific permission (major, ~55)
- Check: every endpoint declares authorization; the permission/role is named after the endpoint's own resource and action (not copied from another controller or a front-end view role); least privilege (read vs manage split); a new permission must be created where the identity-provider/permission config lives, in the same release; tests use a user holding exactly that permission. No new unauthenticated route without explicit justification.
- Ex: `roles: ['sales-read']` on a deleted-sales endpoint -> `'deleted-sales-read'`.
- Say: "fix the role and create it in the identity-provider config."

### TS-14 REST route conventions (minor-major, ~45)
- Check: paths declared in one place per module (reuse the existing routes file/constants; no second route object for the same module); roots plural kebab-case nouns; no verbs or implementation words in URLs; constant names consistent and lowerCamelCase; static routes registered before `/:id`, also in mock route files; file name matches content.
- Ex: `/fxratesource` -> `/fx-rate-sources`; `${root}/extract` -> reuse root.
- Say: "convention here is kebab-case + plural."

### TS-15 HTTP status semantics (minor-major, ~22)
- Check: creating POST -> 201; command/update with no body result -> 204; documented status equals the status set in code; no 406 for business errors; no request-body class or `@Body` when the body is empty or data is in path params.

### TS-16 Path params, user and tenant extraction (major, ~22)
- Check: path params named consistently (`:orderId`); use the project's user/tenant decorators or request-context middleware **(if present)**, never hand-built identity objects or controller getters reading raw props; never accept identity-bearing fields (userId, deletedBy, ids already in the path) from the body.
- Say: "map the user from the authenticated context into the command."

### TS-17 Naming of controllers, methods, use cases (minor, ~65)
- Check: names follow `<Verb><Entity><Qualifier>` across class/method/query/handler/response/file; collections are `list*`, single items `get*ById`; the method name matches its action (no leftover sibling name); lowerCamelCase methods; request DTO `<Action><Entity>Request`, not a bare verb.

### TS-18 Pagination and filters on list endpoints (major, ~18)
- Check: list endpoints paginate (cursor `afterId/beforeId` or `page/size`), validated (positive, max size); reused pagination in one shared request type; both cursors together -> 400 documented; optional filters marked optional, mandatory ones required; range filters `...From/...To`; use DB `COUNT`, never load everything to count.
- Say: "add pagination parameters"; "validate the page size."

### TS-19 Backward compatibility (major, ~15)
- Check: renaming/removing a field, endpoint, enum value, error code or message must keep the old one (deprecate with `@deprecated` + removal version) or have the consumer's change confirmed; do not reshape existing responses for a new feature's needs.
- Say: "this will break the already-validated front-end part."

---

## C. DTOs, typing, validation

### TS-20 Required vs optional must match reality (major, ~85)
- Check: optional (`?`, optional doc flag, `required: false`) only if the value can really be absent; mandatory fields (id, status, currency, amount, range dates) must not be optional/nullable in commands, queries, DTOs, responses, builders; prefer `?:` over `T | undefined` / `| null`; drop `required: false` on always-present fields; an optional field must also be handled downstream.
- Ex: `currency?: string` in `MoneyResponse` -> `currency: string`; `endDate: string` for an optional field -> `endDate?: string`.
- Say: "why is it optional?"

### TS-21 Types match the payload (major, ~40)
- Check: `number` for numerics, arrays for multi-valued filters (and their `isArray`/transform in the DTO), enum types not `string`, objects not stringified, id types where ids have a format; outbound-port DTOs use plain primitives, not VOs/enums.
- Say: "it's an array"; "it should be a number."

### TS-22 DTO naming and file layout (nit-minor, ~40)
- Check **(if the repo has a convention)**: suffix casing and file naming (`*.dto.ts`, `*.request.dto.ts`, `*.response.dto.ts`) are uniform; class name matches file; singular/plural consistent with folder; coverage/sonar exclusions often rely on the suffix.

### TS-23 Reuse shared DTOs/value objects (minor, ~18)
- Check: money, rate, pagination, id and date types come from the shared kernel instead of being re-declared; a type used by 2+ modules moves to shared code.

### TS-24 Request validation matches the business ask (major, ~25)
- Check: add range/format validation the domain needs (percentage 0..100, amount >= 0, page size > 0, positive durations) with a test per bound; remove invented validations nobody asked for (length limits on ids, referential keys). With class-validator/zod ensure decorators/schemas match the TS type (required, nested `@Type`, array `each`).
- Say: "add a 0..100 check + test"; "this validation is not needed."

### TS-25 Same concept, same name across layers (minor, ~40)
- Check: entity, ORM column, DTO, event, mock and spec use one name for a concept; boolean prefixes `is/has`; domain terms spelled as the business spells them; no renames of existing fields unless the ticket asks.

---

## D. Errors and exceptions

### TS-26 Pick the right exception type (major, ~18)
- Check: not-found -> NotFound (404); invalid argument -> BadRequest/ArgumentInvalid; missing argument -> BadRequest; business-rule/state violation -> Unprocessable (422) or Conflict (409). Not NotFound for "parent inactive"; not out-of-range for size limits. Never return 200 with an error body; never swallow errors or throw bare `Error` from the HTTP layer.

### TS-27 Error naming and code format (minor, ~45)
- Check **(if the repo defines a convention)**: file `entity-reason.error.ts`, class `EntityReasonError`, a stable machine code in one format (e.g. `ENTITY.REASON_CODE`) whose entity is the one being validated; no ad-hoc strings; codes are part of the contract (see TS-19).
- Ex: `'ORDER.INVALID.PAGINATION'` -> `'ORDER.INVALID_PAGINATION'`.

### TS-28 Empty results are not errors (minor-major, ~7)
- Check: list/query handlers return `[]` when nothing matches (user in no team, filter matches nothing); no 404 on a list because a filter id does not exist unless the ticket says so.
- Say: "empty has no error meaning here."

---

## E. Persistence, SQL, config

### TS-29 ORM/SQL queries (major, ~30)
- Check: right table/column for the field; equality (not `LIKE`) for ids/status/document numbers unless asked; select only needed columns/joins; status/flag filters match the column's meaning; partial update via targeted update, not full save; one batch query (`IN (...)`) instead of a loop (N+1); `COUNT` in the DB; parameterized queries (no string-built SQL, injection risk); indexes/migration for new filter columns; `SELECT` before `WHERE` for readability.
- Say: "this attribute is in the other table"; "run a count query on the DB."

### TS-30 In-memory/fake repository parity with the real adapter (major, ~18)
- Check **(if in-memory doubles exist)**: every filter, sort and pagination rule added to the ORM repository is added to the double; one `.filter()` per condition, `.map` not `.forEach`; same not-found/error behavior; deterministic; check emptiness before indexing.
- Why: otherwise unit tests pass while production differs.

### TS-31 ORM entity and mapper details (major, ~10)
- Check: column naming per project convention (snake_case), timestamps with time zone; no manual `version`/auto-managed columns set on create; mapper assigns every field; no needless number parsing; column rename/migration confirmed by the ticket and reversible.

### TS-32 Config and environment completeness (major, ~20)
- Check: any new env/secret/config key is added to every place the project lists them (env example file, config schema/validation, e2e env, deployment values for every environment/tenant); host/protocol/port come from config services; constants for module names/magic strings; no duplicated config definitions; no secrets committed.
- Say: "add this param to the env example."

---

## F. Naming, readability, hygiene

### TS-33 Remove debug and dead code (minor, ~85)
- Check: no `console.log`, commented-out code, stale TODOs, unused imports/variables/methods/classes/files/injected dependencies; no wrong auto-imports (`aws-sdk`, `console`, unrelated Result libs).

### TS-34 Import style and order (nit, ~140)
- Check: follow the repo's convention (alias imports vs relative, import order); no `../../..` chains where aliases exist; no path typos; run lint/format on touched files.

### TS-35 Formatting (nit, ~170)
- Check: run prettier/eslint; consistent blank lines between blocks and between `it`/`describe`; no trailing blank lines/double spaces; enum values kept in the order the project uses (often alphabetical).

### TS-36 Function design (minor, ~65)
- Check: explicit return types; return directly (no throwaway const); no `else` after `return/throw`; no flag arguments (split into `enable()/disable()`); extract well-named private methods for nested ifs/long blocks; public methods above private helpers; named constants with units instead of magic numbers/strings; watch cognitive complexity; avoid `for` loops in test fakes (`find`/`map`).

### TS-37 Intent-revealing, consistent naming (minor-nit, ~160)
- Check: name by business meaning; `list*` collections, `get*ById` single, `find*` nullable, `filter*` optional params; no `get*` for collections; no implementation details in names (`InDb`); variable names reflect type; fix typos in identifiers and public docs (they leak into the API).

### TS-38 Dates and clocks (major, ~15)
- Check: use the project's date helper/value object, not raw `new Date()` or string comparison; inject a clock port/service in domain logic so tests can fix "now" **(if one exists)**; test dates relative to now; ISO 8601 and explicit time zones in API docs; no timezone-dependent assertions.

---

## G. Tests

### TS-39 Assert content, deterministically (major, ~60)
- Check: unit and e2e assertions cover returned fields, order, ids, statuses, not just `toHaveLength`/status code; expected counts are literals (no recomputing with the same filter); no `if` inside tests; no vacuous assertions; new fields you added are asserted.
- Ex: `expect(res).toHaveLength(2)` -> also `expect(res[0].id).toEqual('o-1')`.
- Say: "check the content of the result."

### TS-40 Cover errors, edges and every new branch (major, ~45)
- Check: a test per validation/error added (empty, invalid, range, before/after, no filter, null, upstream failure via the project's failure-injection helper); one test combining all filters; separate cases (negative vs zero) in distinct tests; every new filter tested at unit and e2e level; new failure modes registered in the test doubles.

### TS-41 Test structure and naming (nit-minor, ~140)
- Check: `describe` names the use case; `it('should ...')` titles explicit; given/when/then sections; no duplicate/nested describes; variables declared in the test that needs them, not shared top-level `let`; seed helpers and builders (`buildOrder()`, `saveOrders(list)`) with return types; faker/generated ids; no magic strings in specs; use the repo's builders, don't hand-write fixtures.

### TS-42 Test only what the use case needs (minor, ~20)
- Check: no unrelated seed data or tests; builders keep fields private with defaults; no unused variables; do not delete cleanup/teardown.
- Say: "why is this needed here?"

### TS-43 Test doubles behave like the real thing (minor, ~45)
- Check **(if doubles exist)**: seeding methods (`saveX(list)`), one injectable failure mode per gateway method, plural list names, boolean flags `isXCalled`; same behavior as the real adapter (Liskov); consistent file naming; do not add a second double where one exists (e.g. unit-of-work).

### TS-44 E2E tests exercise the HTTP layer (major-minor, ~75)
- Check: one scenario file/suite per resource (add scenarios, not a file per endpoint); the `when` step calls the HTTP endpoint, never an adapter/gateway; data comes from the scenario table, not hardcoded; assert the whole response; use the token/role the ticket targets (admin vs normal user); upstream reads served by mock servers, observable writes by a recording double; suite passes with upstream services down.
- Say: "call the endpoint, not the adapter; we are in e2e."

### TS-45 Mocks mirror real upstream payloads (minor-major, ~45)
- Check: mock payload shape equals the real response (object vs array, field names, id formats, enum values consistent across mocks); realistic values; resource names camelCase, routes kebab-case, specific routes before `:id`; deprecated routes removed; updated when the gateway path changes.
- Say: "the real response is an object, not a list."

### TS-46 Coverage thresholds and CI hygiene (nit-minor, ~36)
- Check: raise/adjust coverage thresholds when coverage changes (unit and e2e); do not commit unrelated lockfile churn, CI branch tweaks, local SSL/datasource tweaks, unrelated renames or accidental files; keep commits squashed/rebased.
- Say: "please revert this change / don't commit this file."

---

## Not worth flagging (reviewers relaxed or ignored)
- Private-field ordering beyond "before methods"; extra tests for pure enum conversion beyond valid + invalid; verbose JSDoc (only `@deprecated` with since/removal info).
- Relaxed: no request class for empty bodies; no providers for handlers; no `Promise.resolve` wrapping; no `async` without `await`; Conflict acceptable for permission-style business errors.
- Rarely discussed in the source reviews, so check only if the diff touches them: rate limiting, caching, transaction boundaries, N+1 beyond isolated cases, guards beyond route-level authorization.
