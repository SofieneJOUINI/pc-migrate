---
name: clean-hexagonal-any-stack
description: Build or extend services in any language (TypeScript, Python, Go, C#, Kotlin, Rust...) with hexagonal clean architecture, CQRS, DDD, SOLID and strict TDD. Not for Java/Spring.
---

# Clean Hexagonal, any stack

Builds services with a hexagonal/clean architecture driven by TDD, in whatever language the user picks. There's no generator. You build the skeleton test-first from a language-neutral kernel contract, using the idioms of the chosen stack. The principles come from these guides:

- SOLID: https://sofienejouini.github.io/docs/solid-principles.html
- Component principles: https://sofienejouini.github.io/docs/component-principles.html
- Clean Code: https://sofienejouini.github.io/docs/clean-code.html
- Code smells & heuristics: https://sofienejouini.github.io/docs/code-smells.html

## Reference files (read when needed)

| File | Read it when |
| --- | --- |
| [references/architecture.md](references/architecture.md) | Always, before creating or moving any file. Covers the layers, the folder layout, naming, and where each thing goes. |
| [references/kernel.md](references/kernel.md) | When bootstrapping a project. It defines the kernel contract (ids, context, entity, event, command/query/handler, ports, errors) in pseudo-code. |
| [references/stacks.md](references/stacks.md) | Right after choosing the stack. For each language it gives the layout, dependency injection, async model, error mapping, test tools, and an example slice. |
| [references/tdd-and-testing.md](references/tdd-and-testing.md) | Before writing any production code. Covers the TDD loop, test types, builders, fakes, and event assertions. |
| [references/multi-tenancy.md](references/multi-tenancy.md) | When one deployment serves several isolated customers/organizations. |
| [references/principles.md](references/principles.md) | When making a design decision or refactoring. This is a condensed version of the four guides above. |
| [references/review-checklist.md](references/review-checklist.md) | Before declaring any task done. |

## Workflow A: create a new project

1. **Gather the inputs.** Ask only for what is missing, and propose defaults:
   - Language and framework. If the user has no preference, propose one that fits their team, e.g. TypeScript + Fastify/NestJS, Python + FastAPI, Go + net/http, or C# + ASP.NET Core.
   - Project name, and the first business module (e.g. `order-service` / `order`).
   - Tenancy: does one running instance hold data for several customers who must never see each other's data? Default no. See `references/multi-tenancy.md`.
   - Persistence (default Postgres) and how events travel (default: in-process dispatcher; add a broker only when another service consumes them).
   - The first 1–3 business capabilities. Phrase each one as a command (changes state) or a query (reads state), plus the trigger for each: HTTP or event.
2. **Initialize the toolchain**, using the stack's standard tools (`npm init`, `uv init`/`poetry`, `go mod init`, `dotnet new`, `cargo new`...). Set up the formatter, the linter, the test runner, a coverage tool, and one command each to build, test, and run. Follow `references/stacks.md`.
3. **Create the folder layout** from `references/architecture.md`, in the stack's casing convention.
4. **Build the kernel test-first** from `references/kernel.md`. Only build what the first slice needs: `EntityId`, `UseCaseContext`, the base command/query and handlers, typed errors, error-to-HTTP mapping, `DatesPort` and its fake, `EventDispatcherPort` with in-memory and in-process implementations. Each piece gets a unit test first.
5. **Build a health-check query slice end to end** (unit test → query handler → HTTP adapter → contract test). This proves that the layering, the error mapping, and the test setup work before any business code exists.
6. **Add the delivery basics**: a README (purpose, commands, endpoints and events), a `.gitignore`, a Dockerfile, a CI workflow that runs lint and tests, and configuration from the environment.
7. **Build each capability with Workflow B**, one vertical slice at a time.
8. **Finish**: go through `references/review-checklist.md`, and summarize to the user what was created.

## Workflow B: add a feature slice (command or query)

Follow the three laws of TDD strictly: no production code without a failing test, and never write more production code than the failing test needs.

1. **Name the slice** in the ubiquitous language: verb + noun, e.g. `PlaceOrder` or `ListOrdersByCustomer`. Decide whether it's a command or a query, and whether it's triggered over HTTP or by an event.
2. **Write the unit test first**, in the slice's test folder:
   - Build the handler by hand, using in-memory adapters and fakes (`OrderInMemoryRepository`, `FakeDates`, `InMemoryEventDispatcher`). No framework container, no database, and no mocks for the domain.
   - Use a Given / When / Then structure, sentence-like test names ("should ... when ..."), and one behavior per test.
   - Create test data through builders with realistic random defaults.
3. **Make it compile, then make it pass, one test at a time.** Create the artifacts in this order, each only when a test needs it:
   `Command/Query` → `Handler` → `Port` (interface or protocol) → in-memory adapter → domain entity, value objects, errors and events.
4. **Refactor while green**: remove duplication, name things well, extract value objects, and move behavior into entities (tell, don't ask).
5. **Add the driving adapter** (HTTP route + request DTO, or event handler) and cover it with a contract test at the HTTP boundary. The handler is replaced by a stub, and the test asserts status codes and error codes for every error the handler can raise.
6. **Add the driven adapter** (SQL repository, HTTP client, broker publisher) that implements the same port, and cover it with an E2E or integration test against real infrastructure (Testcontainers or docker compose). This proves it behaves like the in-memory twin. Register it in the composition root.
7. **Run the full suite**, then go through the review checklist.

## Non-negotiable rules

- **Dependency rule.** `domain` depends on nothing outside itself and the kernel. Handlers depend on ports and the domain, never on adapters, the ORM, HTTP, or the framework. Adapters depend inward.
- **Composition root.** Only one place (e.g. `main`, the app module, or the DI container setup) knows the concrete adapters and wires them into handlers. Handlers receive their dependencies through the constructor (or factory function) and never build them themselves.
- **One slice, one folder.** A capability's command, handler, HTTP/event adapter and DTO live together in `commands/<slice>/` (or `queries/<slice>/`).
- **Ports are small and client-specific** (ISP). Each port has a real adapter and an in-memory twin that behave the same way (LSP).
- **Errors are typed and carry a stable code** (`ORDER.NOT_FOUND`). The error's category decides the HTTP status. A single mapper at the edge applies it. Never throw strings or generic errors for business cases.
- **Time, ids and randomness go through ports**, so tests are repeatable.
- **Async all the way**, in the stack's native async model. No blocking calls inside async paths.
- **No comments explaining what the code does.** Rename or extract instead.
- **YAGNI**: caches, brokers, schedulers and extra layers come in only when a slice's tests need them.
- **In multi-tenant projects, tenant isolation is a business rule**: the tenant is resolved once at the edge, travels in the context and events, and scopes every read and write.

## When the target project already exists

Detect its language, framework, folder layout, kernel equivalents, test tools and error style before generating anything. Follow the existing conventions over this skill's defaults, and don't restructure unrelated code. If the project is Java/Spring, switch to the `clean-hexagonal-java` skill.
