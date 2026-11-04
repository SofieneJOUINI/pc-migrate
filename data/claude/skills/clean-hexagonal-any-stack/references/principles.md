# Principles (condensed)

Sources, the author's own guides. Fetch them when you need the full explanation or examples:
- SOLID: https://sofienejouini.github.io/docs/solid-principles.html
- Component principles: https://sofienejouini.github.io/docs/component-principles.html
- Clean Code: https://sofienejouini.github.io/docs/clean-code.html
- Code smells & heuristics (Clean Code ch. 17, C1–T9): https://sofienejouini.github.io/docs/code-smells.html

## Contents
- SOLID, and how it shows up in this architecture
- Component principles
- Clean Code: names, functions, objects, classes, errors, comments, formatting
- Design patterns used in these projects

## SOLID, and how it shows up in this architecture

| Principle | Rule | Where you see it |
| --- | --- | --- |
| **S**ingle Responsibility | One reason to change | One use case per handler. Controllers only translate. ORM/row mapping only maps. Split `UserManager` into `UserService` + `UserNotifier`. |
| **O**pen/Closed | Extend without editing tested code | New behavior = new slice, new adapter, or new strategy implementation. A switch on type becomes polymorphism (Interface + Strategy + a Factory that picks the implementation). |
| **L**iskov Substitution | Subtypes honor the base contract | `XxxInMemoryRepository` and `XxxPostgresRepository` must behave the same: same errors, same empty-vs-error semantics. An implementation that throws "not supported" breaks LSP. |
| **I**nterface Segregation | Clients depend only on what they use | Many small `XxxEventSenderPort`s instead of one big port. `EventSender` implements them all. |
| **D**ependency Inversion | Depend on abstractions; the high-level policy owns them | Handlers depend on `ports/` interfaces, injected through the constructor. Business logic lives in the most stable component: the domain. |

## Component principles

Cohesion (what goes together):
- **REP**: what is released together shares a theme and a version. A library (e.g. a money-rounding library) exposes a `Port` + `Factory` and hides its implementation (package-private class).
- **CCP**: group what changes together (a slice package). This is SRP at the component level.
- **CRP**: don't make consumers depend on things they don't use. Keep libraries small and focused.

Coupling (how components depend on each other):
- **ADP**: no dependency cycles. Break them with an interface (DIP) or by extracting a shared component.
- **SDP**: depend in the direction of stability. UI, adapters and third-party integrations point toward the domain.
- **SAP**: stable components are abstract (ports, kernel base classes). Volatile ones are concrete.

## Clean Code

**Names**
- Intention-revealing and pronounceable. No `a1`, `dtaRcrd`, `u` for user, or mental mapping.
- One word per concept (`getUser`, not `getUserInfo`/`getUserData`/`getUserDetails`).
- Searchable: `MILLISECONDS_PER_DAY`, not `86400000`. Named constants for every magic value, including error codes and event names.
- No redundant context (`Car.make`, not `Car.carMake`). No encodings or Hungarian notation.
- Scope length matches name length. Names describe side effects (`createOrReturn...`).
- Names sit at the right abstraction level (`connectionLocator`, not `phoneNumber`).

**Functions**
- Small, doing one thing, at one level of abstraction. Callers sit above callees (newspaper order).
- 0–2 arguments. Beyond that, introduce a parameter object or value object.
- No flag arguments: `createTempFile()` + `createFile()`, not `createFile(name, true)`.
- No output arguments and no hidden side effects. Return new values instead of mutating inputs.
- Encapsulate conditionals (`if (canActivateService(...))`) and prefer positive ones (`isEmailUsed`, not `isEmailNotUsed`).
- Replace type checks and switches with polymorphism. Allow at most one switch per type, inside a factory.
- Prefer declarative stream and reactive pipelines to imperative loops with accumulators.
- Command/query separation: a method either changes state or answers a question.
- Remove dead code and duplication (DRY), but prefer duplication to a wrong abstraction across different domains.
- Avoid transitive navigation (`a.getB().getC().do()`, Law of Demeter).
- Make temporal coupling explicit: each step's output feeds the next step's input.
- Don't over-optimize. Measure first.

**Objects and data structures**
- Encapsulate: private fields, behavior next to data, no public setters on entities.
- Prefer immutability (readonly/final fields, records or frozen dataclasses, returning new instances).
- Composition over inheritance, unless it's a true is-a relationship with real reuse.
- Avoid feature envy: if a method mostly uses another object's data, move it there.

**Classes**
- Measure size by responsibilities, not by lines. High cohesion: each field used by most methods.
- Low coupling: depend on ports and value objects, not concrete adapters.

**Error handling**
- Throw typed errors with stable codes. Never throw strings or generic exceptions for business cases.
- Never swallow errors: no empty `catch`, no `catch` that returns an empty result without an explicit business reason and a log line.
- Map infrastructure errors (SQL, HTTP client, broker) to domain errors at the adapter boundary, and recover only where the use case defines what recovery means. In languages with error values (Go, Rust), return typed errors and wrap them with context. Never ignore them.

**Comments**
- Code explains itself. A comment is only for a constraint the code can't express (a legal rule, the reason behind a non-obvious workaround, an external contract).
- No commented-out code, no journal or author comments, no banner/positional markers, no redundant doc comments. `TODO` is allowed but is not a license to ship bad code.

**Formatting**
- Consistent casing: PascalCase types, camelCase members, UPPER_SNAKE constants, snake_case event names.
- Organized imports, no wildcards unless that's the project's style. Let the formatter decide the layout.

**Environment**
- One command to build and one to test (`make test`, `npm test`, `pytest`, `go test ./...`, `dotnet test`...), and they're documented in the README.
- Don't disable failing tests or compiler warnings to go faster (G4).

## Design patterns used in these projects

| Pattern | Where |
| --- | --- |
| Ports & Adapters | the whole architecture |
| Command / Command Handler (CQRS) | `commands/`, `queries/` |
| Template Method | `CommandHandler.handle()` (or a decorator in Go/Rust) wraps logging and error handling around `execute()` |
| Strategy + Factory | interchangeable implementations chosen at runtime (`PricingStrategyFactory` picking a `PricingStrategy` per customer type) |
| Repository | `XxxRepositoryPort` |
| Builder | test data builders, fluent builders for complex value objects (`DiscountRuleBuilder`) |
| Observer / Pub-Sub | domain events through `EventSender` and `EventController` |
| Null Object / Fake | in-memory adapters, `FakeDates` |
| Adapter | every class in `adapters/` and `database/` |

Apply a pattern only when it removes a real smell (duplication, a switch on type, rigid coupling). Never add one just to have it.
