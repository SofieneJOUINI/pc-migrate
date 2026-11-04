# General review rules (every PR / MR, any stack)

Distilled from ~24,000 real review comments (Java/Spring, TypeScript/NestJS and Angular code,
2022–2026). These are the things experienced reviewers flagged again and again, independent of
language. Apply them to every review, then the stack file(s), then the repo's own conventions.

## Cross-stack rules

**GEN-01 Correctness first: nulls, empty collections, amounts, dates** — Blocker/Major
Check: dereferencing values that can be null/undefined/empty (nullable DB columns, optional DTO
fields, `list[0]` without a size check); money handled with the project's money type (sign, scale,
rounding, currency never dropped); dates created/compared in UTC through the project's clock
abstraction instead of `now()` calls scattered in domain code.

**GEN-02 Don't duplicate what already exists** — Major · one of the most frequent comments everywhere
Check: a new helper, DTO, value object, client/gateway, component, error class or constant that
already exists in the repo or in a shared library. **Search before claiming** (`git grep`), and name
the existing thing in the finding. Wording: "this already exists in …, reuse it."

**GEN-03 Put code in the right layer / module** — Major
Check: business rules in controllers, handlers, adapters or UI components instead of the domain
model/service; infrastructure details (queues, URLs, SQL, HTTP) leaking into domain code; code
shared by several modules added to one of them instead of the shared library.

**GEN-04 Contracts stay consistent end to end** — Major
Check: the same field has the same name, type and optionality in DB column, entity, DTO, event,
API docs, client model and test mocks; renamed/removed fields, endpoints, events or error codes
still used by other services or the front end; new event fields the consumers don't handle.

**GEN-05 Tests cover the change and assert real values** — Major · very frequent
Check: new or changed behaviour without tests; only the happy path (missing error, empty, boundary,
permission, "no match" cases); filters tested only with matching data (add distractors);
assertions on length / not-null instead of actual values (amounts, currency, dates, ids, status);
in-memory/fake implementations not updated to behave like the real one.

**GEN-06 No dead, debug or commented-out code** — Minor · very frequent
Check: unused imports, fields, methods, classes, injected dependencies, parameters; `console.log`,
`System.out`, `print`, debug logging; commented-out blocks; TODOs without a ticket.

**GEN-07 Small, intention-revealing functions** — Minor · very frequent
Check: long methods or nested conditionals → extract well-named private methods; duplicated blocks;
`else` after `return`/`throw`; magic numbers/strings → named constants (unit in the name:
`timeoutInSeconds`); boolean flag parameters.

**GEN-08 Names carry business meaning and match the domain vocabulary** — Minor · very frequent
Check: names that describe mechanics instead of meaning; singular/plural mismatches; identifier
typos; names copied from a sibling class that don't fit; terms that differ from the spec and the
existing code (`list…` for collections, `get…ById` for one item, booleans as `is/has…`).

**GEN-09 Errors follow the project's convention** — Minor/Major
Check: right error type (not found vs invalid argument vs business-rule violation vs conflict);
error codes in the project's format; every new error mapped to the right HTTP status, documented
and tested; empty results are not errors.

**GEN-10 Config changes are complete and safe** — Major (Blocker for secrets)
Check: new config/env var/feature flag added to the example/default config and to every
environment (and tenant, if multi-tenant); feature flags off by default; no credentials, tokens
or personal data committed; no stray edits to local/test config files.

**GEN-11 Performance on real data volumes** — Major
Check: queries or calls inside loops (N+1), loading everything to count/filter in memory,
`SELECT *`, missing pagination on list endpoints, unbounded collections.

**GEN-12 Security basics** — Blocker
Check: endpoints without authorization or with a role copied from another endpoint; user-supplied
values in SQL/shell/paths without binding/escaping; identity taken from the request body instead
of the authenticated user; sensitive data in logs.

## PR / MR hygiene (report under "PR hygiene")
Check these against **the repo's own conventions** (learn them from `git log`, branch names, the
PR/MR template, CONTRIBUTING):
- One ticket/topic per PR, focused scope: no unrelated formatting, renames or files from other
  branches ("too many files modified, keep only your feature").
- Ticket reference in title/commits/branch, in the same format as recent history.
- Rebased on the latest target branch; no conflicts; CI green.
- No committed junk: lockfile churn unless intended, logs, IDE folders, crash dumps, large or real
  data files.
- Released artifacts get a version bump when the project versions them per change.
- Linked changes stated: dependent backend/front PRs, permissions/roles, migrations, API/event docs.
- UI changes match the ticket/design; screenshots help.

## When to request changes vs approve
- **Changes requested**: bug, data/amount error, security issue, contract break, missing or
  failing tests for new logic, missing migration/version bump/permission, wrong scope, conflicts.
- **Approve with comments**: naming, readability, small refactors, nits.
- **Approve**: nothing blocking; state any merge condition explicitly ("rebase before merging").

## Tone
Short, direct and friendly: "please rename …", "extract this into a method", "why do we need
this?", "this already exists in …". Ask when unsure; a short word of praise when the PR is good.
No lecturing, no generic advice without a file and line.
