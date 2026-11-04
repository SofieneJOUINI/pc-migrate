# Architecture: Hexagonal + Clean Architecture + CQRS (any stack)

## Contents
- Layers and the dependency rule
- Folder layout
- Naming conventions
- Where does this code go?
- Component-level rules
- Composition root

## Layers and the dependency rule

```
          driving side (primary)                     driven side (secondary)
  HTTP ──> <Slice> HTTP adapter ──┐              ┌─> OrderSqlRepository ──> database
 event ──> <Slice> event handler ─┼─> Handler ──> OrderRepositoryPort ◄─ implemented by ─┤
   CLI ──> <Slice> CLI command  ──┘      │       OrderPlacedEventSenderPort              ├─> EventSender ──> dispatcher / broker
                                         │       PaymentClientPort                       └─> PaymentHttpClient ──> other service
                                         ▼
                             domain (entities, value objects, events, errors)
```

- Source-code dependencies only point **inward**: adapters → handlers → ports and domain. Nothing in `domain`, `ports`, `commands` or `queries` imports from `adapters`, `database`, or `infrastructure`.
- **Ports** are interfaces owned by the core and shaped by what the handler needs, not by what the database offers (DIP).
- **Data flow and dependency flow can point in opposite directions.** A handler "sends" an event by calling a port. The adapter that really sends it depends on the port.
- **The framework is a detail.** Framework decorators, annotations, request objects and ORM models stay in adapters. Domain code is plain language code.
- Enforce the rule mechanically where the stack allows it: an import linter (`eslint-plugin-boundaries`, `dependency-cruiser`, `import-linter`, `go-arch-lint`, ArchUnit/NetArchTest), or separate packages/modules/projects.

## Folder layout

Use the stack's casing (kebab-case for TS files, snake_case for Python/Rust, lowercase packages for Go, PascalCase folders for .NET), but keep this shape:

```
src/
├── main / app / cmd                 # composition root: builds adapters, wires handlers, starts servers
├── infrastructure/                  # technical cross-cutting concerns, no business logic
│   ├── health/                      # health-check query slice
│   ├── events/                      # in-process dispatcher, broker dispatcher
│   ├── dates/                       # system clock implementing DatesPort
│   └── http/                        # server setup, error-to-HTTP mapper, auth middleware
├── libs/                            # kernel: stable, abstract, no business vocabulary
│   ├── ddd/                         # EntityId, UseCaseContext, Entity, DomainEvent, Command/Query, handlers, ports
│   └── errors/                      # AppError + categories (InvalidArgument, NotFound, Conflict, Unprocessable)
└── modules/<module>/
    ├── commands/<slice>/            # one folder per write use case: command, handler, http/event adapter, request DTO
    ├── queries/<slice>/             # one folder per read use case: query, handler, response DTO, http adapter
    ├── domain/
    │   ├── entities/                # identity + lifecycle + behavior
    │   ├── value-objects/           # immutable, self-validating
    │   └── events/                  # past-tense facts, or requests addressed to other services
    ├── ports/                       # repository, event sender, client, lock... interfaces
    ├── adapters/                    # event sender, http clients, locks, caches (+ in-memory twins)
    ├── database/<aggregate>/        # SQL/ORM repository, row mapping, migrations (+ in-memory twin)
    ├── services/                    # domain services shared by several slices (only after real duplication)
    └── errors/                      # typed module errors with stable codes

tests/  (or next to the code, following the stack's convention)
├── support/                         # builders base, fakes (FakeDates), test app factory, containers setup
└── modules/<module>/
    ├── commands/<slice>/            # unit tests
    ├── queries/<slice>/
    ├── contract/                    # HTTP boundary tests
    ├── e2e/                         # real adapters + containers
    └── builders/
```

Go is the exception: keep the same concepts, but in packages named after what they provide (`order/placeorder`, `order/domain`, `order/postgres`), with interfaces declared by the consumer package. See `stacks.md`.

When a service has several modules, each gets its own `modules/<module>/` tree. Modules talk to each other through events or ports, never by importing each other's domain or database code.

## Naming conventions

Adapt the casing to the language (`place_order_handler.py`, `PlaceOrderHandler.cs`, `place-order.handler.ts`), and keep the words:

| Artifact | Pattern | Example |
| --- | --- | --- |
| Command | `<Verb><Noun>Command` | `PlaceOrderCommand` |
| Command handler | `<Verb><Noun>CommandHandler` (or `...Handler`) | `PlaceOrderCommandHandler` |
| Query / handler | `<Get/List><Noun>Query[Handler]` | `ListOrdersByCustomerQueryHandler` |
| Query response | `<Get/List><Noun>Response` | `GetOrderByIdResponse` |
| HTTP body | `<Slice>Request` | `PlaceOrderRequest` |
| Driving adapters | `<Slice>HttpAdapter` / `Controller` / `Route`, `<Slice>EventHandler` | `ReserveStockEventHandler` |
| Port | `<Thing>RepositoryPort`, `<EventName>EventSenderPort`, `<Thing>ClientPort` | `OrderRepositoryPort` |
| Real adapter | `<Thing><Technology>Repository`, `EventSender`, `<Thing><Technology>Client` | `OrderPostgresRepository`, `PaymentHttpClient` |
| In-memory adapter | `<Thing>InMemory<Role>` | `OrderInMemoryRepository` |
| Entity | `<Thing>` or `<Thing>Entity` (pick one per project) | `Order` |
| Value object | noun, no suffix | `Money`, `CustomerId`, `OrderStatus` |
| Event | past-tense fact | `OrderPlaced` |
| Error | `<Thing><Problem>Error`, code `THING.PROBLEM` | `OrderAlreadyCancelledError` → `ORDER.ALREADY_CANCELLED` |
| Event names on the wire | snake_case | `order_placed` |
| Test names | sentence | `should not cancel an order when it is already shipped` |

Use one word per concept across the whole module. Don't mix `get`/`fetch`/`retrieve` or `create`/`save`/`insert` for the same operation.

## Where does this code go?

- Does it express a business rule or business vocabulary? Put it in `domain/`: an entity if it has identity and lifecycle, otherwise a value object.
- Does it orchestrate one use case (load, decide, save, notify)? It's a handler in `commands/<slice>` or `queries/<slice>`. Decisions belong in entities and value objects. Handlers only orchestrate.
- Does the handler need the outside world? Define a port with only the methods it needs, then implement it in `adapters/` or `database/` (real + in-memory).
- Is the same domain logic used by 2+ handlers? Extract it into `services/`, taking ports as constructor arguments, but only after the second real use.
- Is it technical and business-agnostic? Put it in `infrastructure/`. Is it a base abstraction every module reuses? Put it in `libs/`.

## Component-level rules

- **CCP / SRP**: a slice folder changes for one reason (its use case). If a requirement change touches five folders, the boundaries are wrong.
- **CRP / ISP**: don't force a handler to depend on a port with methods it doesn't use. Split the port.
- **ADP**: no cycles between folders, packages or modules. Break them with an interface, or communicate through events.
- **SDP / SAP**: stable things (domain, ports, kernel) are abstract and depended upon. Volatile things (HTTP, ORM, clients) are concrete and depend on them.
- Cross-service communication goes through events or a dedicated client port. Never share database tables between services.

## Composition root

One place builds the object graph. It reads the configuration, creates the real adapters (database pool, dispatcher, clients, clock), creates the handlers with those adapters, and registers the driving adapters (routes, event subscriptions).

- With a DI container (NestJS, ASP.NET Core, Spring, Koin), the container is the composition root. Bind each port token/interface to its real adapter in one module per bounded module.
- Without one (Go, plain Node, FastAPI, Rust), write explicit wiring functions (`buildOrderModule(deps)`). That's usually simpler and just as testable.
- Tests build their own graph: in-memory adapters for unit tests, the real graph with containers for E2E tests, and stubbed handlers for contract tests.
