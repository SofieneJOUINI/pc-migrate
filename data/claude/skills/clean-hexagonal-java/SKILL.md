---
name: clean-hexagonal-java
description: Scaffold or extend Java/Spring Boot services with hexagonal clean architecture, CQRS, DDD, SOLID and strict TDD (new projects, use cases, ports, adapters, repositories).
---

# Clean Hexagonal Project

Creates new services, and adds features to existing ones, with a hexagonal/clean architecture driven by TDD. The principles come from these guides:

- SOLID: https://sofienejouini.github.io/docs/solid-principles.html
- Component principles: https://sofienejouini.github.io/docs/component-principles.html
- Clean Code: https://sofienejouini.github.io/docs/clean-code.html
- Code smells & heuristics: https://sofienejouini.github.io/docs/code-smells.html

## Reference files (read when needed)

| File | Read it when |
| --- | --- |
| [references/architecture.md](references/architecture.md) | Always, before creating or moving any file. Covers the layers, the package layout, naming, and how to map them to other stacks. |
| [references/tdd-and-testing.md](references/tdd-and-testing.md) | Before writing any production code. Covers the TDD loop, test types, builders, and fakes. |
| [references/code-templates.md](references/code-templates.md) | When generating a command, query, port, adapter, entity, value object, error, or event. |
| [references/principles.md](references/principles.md) | When making a design decision or refactoring. This is a condensed version of the four guides above. |
| [references/multi-tenancy.md](references/multi-tenancy.md) | When the project is (or must become) multi-tenant. Covers tenant context, isolation rules, persistence, and tests. |
| [references/review-checklist.md](references/review-checklist.md) | Before declaring any task done. |

## Workflow A: create a new project

1. **Gather the inputs.** Ask only for what is missing, and propose defaults:
   - Project name, in kebab-case (e.g. `order-service`). This becomes the artifactId.
   - Base package (default `com.example`), and business module name in kebab-case (default: the project name without `-service`, e.g. `order`).
   - Tenancy. Does one running instance serve several customers or organizations whose data must stay isolated? If yes, pass `--multi-tenant`. If not, stay single-tenant (the default). Don't add tenancy "just in case". See `references/multi-tenancy.md`.
   - Stack. The bundled scaffold is `java-spring` (Java 17, Spring Boot 3 WebFlux, R2DBC Postgres, Testcontainers). For any other stack, see "Other stacks" below.
   - The first 1–3 business capabilities. Phrase each one as a command (changes state) or a query (reads state), plus the trigger for each: HTTP or event.
   - Persistence: Postgres is the default. Add other infrastructure only when a capability needs it.
2. **Scaffold the skeleton** with `scripts/scaffold.py`, which sits next to this file (`${CLAUDE_SKILL_DIR}` in Claude Code). Don't hand-write the boilerplate:
   ```bash
   python3 ${CLAUDE_SKILL_DIR}/scripts/scaffold.py \
     --name order-service --base-package com.acme.orders --module order \
     --output /path/to/parent-dir          # add --multi-tenant when needed
   ```
   Run `python3 ${CLAUDE_SKILL_DIR}/scripts/scaffold.py --help` for all options (`--multi-tenant`, `--group-id`, `--version`, `--java-version`, `--port`, `--force`).
3. **Verify the skeleton is green** before touching it: `mvn -q test -Dtest='!ContainersTest' -Dsurefire.failIfNoSpecifiedTests=false`. Container-based tests need Docker; run the full `mvn verify` when Docker is available.
4. **Build each capability with Workflow B.** One vertical slice at a time, test first.
5. **Finish**: go through `references/review-checklist.md`, update the README (purpose, how to run, endpoints and events), and summarize to the user what was created.

## Workflow B: add a feature slice (command or query)

Follow the three laws of TDD strictly: no production code without a failing test, and never write more production code than the failing test needs.

1. **Name the slice** in the ubiquitous language: verb + noun, e.g. `PlaceOrder` or `ListOrdersByCustomer`. Decide whether it's a command or a query, and whether it's triggered over HTTP or by an event.
2. **Write the unit test first** in `src/test/java/<base>/modules/<module>/commands/<slice>/<Slice>UnitTests.java`:
   - Wire the handler by hand, using in-memory adapters and fakes (`XxxInMemoryRepository`, `FakeDates`, `InMemoryEventDispatcher`). No Spring context and no mocks for the domain.
   - Use a Given / When / Then structure, test names starting with `should...` or `shouldNot...`, and one behavior per test.
   - Create test data through fluent builders (`XxxBuilder.builder(repository).withFoo(...).build()`).
3. **Make it compile, then make it pass, one test at a time.** Create the artifacts in this order, each only when a test needs it:
   `Command/Query` → `Handler` → `Port` (interface in `ports/`) → `InMemory` adapter → domain entity, value objects, errors and events.
4. **Refactor while green**: remove duplication, name things well, extract value objects, and move behavior into entities (tell, don't ask). Re-run the tests.
5. **Add the driving adapter** (`RestController` + `HttpRequest` record, or `EventController`) and cover it:
   - A REST contract test (`@WebFluxTest` with a mocked handler), asserting status codes and error codes for every error the handler can throw.
   - An E2E test (`*E2ETests extends IntegrationTest`) for the happy path plus one important failure, going through the real adapters and Testcontainers.
6. **Add the driven adapter** (`XxxOrmRepositoryImpl` + `XxxOrmEntity` + Spring Data `XxxRepository`, or a client/sender) that implements the same port. The E2E test proves it behaves like the in-memory one. Until this step is done, the Spring context can't start, because in-memory adapters are deliberately not beans. Add the table to `init_tables_and_types.sql` and to `TABLES_TO_CLEAN` in `IntegrationTest`.
7. **Run the full suite**, then go through the review checklist.

## Non-negotiable rules

- **Dependency rule.** `domain` depends on nothing outside itself and the kernel (`libs/`). Handlers depend on `ports` (interfaces) and `domain`, never on `adapters`, `database`, ORM, or HTTP types. Adapters depend inward. See `references/architecture.md`.
- **One slice, one package.** Command, handler, controller(s) and HTTP request for one capability live together in `commands/<slicename>/` (or `queries/<slicename>/`).
- **Ports are small and client-specific** (ISP). Prefer `OrderPlacedEventSenderPort` with one method over a do-everything `EventPort`. A single `EventSender` adapter may implement many sender ports.
- **Every port has at least two implementations**: the real one (a Spring `@Component`) and an in-memory one (not a Spring bean, instantiated by unit tests).
- **Errors are typed and carry a stable code**: `OrderNotFoundError extends NotFoundException` with `ERROR_CODE = "ORDER.NOT_FOUND"`. The HTTP status comes from the base class. Never throw a raw `RuntimeException` or a string.
- **Time and randomness go through ports** (`DatesPort`, id generators), so tests are repeatable.
- **Reactive all the way** (in the Java scaffold). Return `Mono`/`Flux` from ports and handlers. `block()` is only allowed in tests and builders.
- **No comments explaining what the code does.** Rename or extract instead. No commented-out code, no journal comments.
- **In multi-tenant projects, tenant isolation is a business rule.** The tenant is resolved once in the driving adapter, then travels in `UseCaseContext` and events. Every port read/write is scoped by `TenantId`, another tenant's data is reported as not found, and every reading slice has an isolation test.
- **Don't add infrastructure speculatively** (YAGNI). Caches, object storage, schedulers and brokers come in only when a slice's tests need them.

## Other stacks

The scaffold script only generates `java-spring`. For any other language or framework (TypeScript/NestJS, Python, Go, C#, Kotlin/Ktor, Rust...), use the `clean-hexagonal-any-stack` skill instead. It applies the same rules through a language-neutral kernel contract and per-stack guides.

## When the target project already exists

Detect its conventions before generating anything: kernel base classes and their packages, whether it uses a `usecases/` layout or `commands/` + `queries/`, its test base classes, and its error style. Follow the existing style of that project over this skill's defaults, and don't restructure unrelated code.
