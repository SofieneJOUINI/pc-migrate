# Architecture: Hexagonal + Clean Architecture + CQRS

## Contents
- Layers and the dependency rule
- Package layout
- Naming conventions
- Where does this class go?
- Component-level rules (cohesion & coupling)
- Mapping to other stacks

## Layers and the dependency rule

```
          driving side (primary)                         driven side (secondary)
  HTTP ──> XxxRestController ─┐                   ┌─> XxxOrmRepositoryImpl ──> Postgres (R2DBC)
 event ──> XxxEventController ─┼─> XxxCommandHandler ─> XxxRepositoryPort ◄── implemented by ─┤
                              │    XxxQueryHandler    XxxEventSenderPort                    ├─> EventSender ──> dispatcher / broker
                              │         │             XxxClientPort                         └─> XxxClient ──> other service
                              │         ▼
                              │      domain (entities, value objects, events, errors)
```

- Source-code dependencies only point **inward**: adapters → handlers → ports and domain. Nothing in `domain`, `ports`, `commands` or `queries` imports from `adapters`, `database`, or `infrastructure`.
- **Ports** are interfaces owned by the core and shaped by what the handler needs, not by what the database offers (DIP: the high-level policy owns the abstraction).
- **Data flow and dependency flow can point in opposite directions.** A handler "sends" an event by calling a port. The adapter that really sends it depends on the port, not the other way around.
- **The framework is a detail.** Handlers are `@Service` beans with constructor injection only, so a unit test can call `new Handler(fakes...)`. No field injection and no `@Autowired` in production code.
- **Domain classes are plain code**: no framework, JSON or ORM annotations. Mapping lives in `database/*OrmEntity` and the HTTP DTOs.

## Package layout

```
src/main/java/<base>/
├── <App>Application.java
├── infrastructure/                  # technical cross-cutting concerns, no business logic
│   ├── healthcheck/                 # GetHealthInformation{Query,QueryHandler,Response,RestController}
│   ├── events/                      # SpringEventDispatcher (in-process), InMemoryEventDispatcher (tests)
│   ├── dates/                       # SystemDates implements DatesPort
│   └── ...                          # security, postgres converters, broker config ... when needed
├── libs/                            # kernel, stable and abstract
│   ├── ddd/                         # BaseEntity, EntityId, UseCaseContext, BaseEvent, EventController,
│   │                                # EventDispatcherPort, DatesPort, Base{Command,Query}[Handler], RestBaseController
│   └── exceptions/                  # ExceptionBase + ArgumentInvalid/NotFound/Conflict/UnprocessableEntity, GlobalExceptionHandler
└── modules/<module>/
    ├── commands/<slice>/            # one package per write use case
    │   ├── <Slice>Command.java
    │   ├── <Slice>CommandHandler.java
    │   ├── <Slice>RestController.java      # if triggered over HTTP
    │   ├── <Slice>HttpRequest.java         # record, HTTP body only
    │   └── <Slice>EventController.java     # if triggered by an event
    ├── queries/<slice>/             # one package per read use case
    │   ├── <Slice>Query.java
    │   ├── <Slice>QueryHandler.java
    │   ├── <Slice>Response.java            # read model / DTO built from entities
    │   └── <Slice>RestController.java
    ├── domain/
    │   ├── entities/                # XxxEntity extends BaseEntity<EntityId>, holds behavior
    │   ├── valueobjects/            # immutable, self-validating; XxxEnum for closed sets
    │   └── events/                  # past-tense facts (OrderPlaced) or requests addressed to others
    ├── ports/                       # XxxRepositoryPort, XxxEventSenderPort, XxxClientPort ...
    ├── adapters/                    # EventSender, http clients, locks, caches (+ InMemory twins)
    ├── database/<aggregate>/        # XxxOrmEntity, XxxRepository (Spring Data), XxxOrmRepositoryImpl, XxxInMemoryRepository
    ├── services/                    # domain services shared by several slices (only when real duplication exists)
    └── errors/                      # XxxError extends NotFound/Conflict/ArgumentInvalid/... with ERROR_CODE

src/test/java/<base>/modules/
├── HumanReadableTest, ReplaceCamelCase, RestControllerTests, AbstractBuilder, IntegrationTest, ContainersTest
└── <module>/
    ├── commands/<slice>/<Slice>UnitTests.java
    ├── queries/<slice>/<Slice>UnitTests.java
    ├── integration/restcontrollers/<Slice>RestControllerTests.java
    ├── e2e/<slice>/<Slice>E2ETests.java
    ├── builders/XxxBuilder.java, UseCaseContextBuilder.java
    └── adapters/FakeDates.java ...
```

When several business modules live in one service, each one gets its own `modules/<module>/` tree. Modules talk to each other through events or ports, never by importing each other's domain or database packages.

## Naming conventions

| Artifact | Pattern | Example |
| --- | --- | --- |
| Command | `<Verb><Noun>Command` | `PlaceOrderCommand` |
| Command handler | `<Verb><Noun>CommandHandler` | `PlaceOrderCommandHandler` |
| Query / handler | `<Get/List><Noun>Query[Handler]` | `ListOrdersByCustomerQueryHandler` |
| Query response | `<Get/List><Noun>Response` | `GetOrderByIdResponse` |
| HTTP body | `<Slice>HttpRequest` (record) | `PlaceOrderHttpRequest` |
| Driving adapters | `<Slice>RestController`, `<Slice>EventController` | `ReserveStockEventController` |
| Port | `<Thing>RepositoryPort`, `<EventName>EventSenderPort`, `<Thing>ClientPort`, `<Thing>Port` | `OrderRepositoryPort` |
| Real adapter | `<Thing>OrmRepositoryImpl`, `EventSender`, `<Thing>Client`, `<Thing>RedisLock` | `OrderOrmRepositoryImpl` |
| In-memory adapter | `<Thing>InMemory<Role>` | `OrderInMemoryRepository`, `PaymentInMemoryClient` |
| ORM row | `<Thing>OrmEntity` (`@Table`, `Persistable<String>`) | `OrderOrmEntity` |
| Entity | `<Thing>Entity` | `OrderEntity` |
| Value object | noun, no suffix; `<Thing>Enum` for enums | `Money`, `OrderStatusEnum` |
| Event | past tense fact | `OrderPlaced`, `OrderCancelled` |
| Error | `<Thing><Problem>Error`, code `THING.PROBLEM` | `OrderAlreadyCancelledError` → `ORDER.ALREADY_CANCELLED` |
| Event names on the wire | snake_case | `order_placed` |
| Tests | `<Slice>UnitTests`, `<Slice>RestControllerTests`, `<Slice>E2ETests` | |
| Test methods | `should<Behavior>[When<Condition>]` | `shouldNotCancelOrderWhenItIsAlreadyShipped` |

Use one word per concept across the whole module. Don't mix `get`/`fetch`/`retrieve`, and don't mix `create`/`save`/`insert` for the same operation.

## Where does this class go?

- Does it express a business rule or business vocabulary? Put it in `domain/`: an entity if it has identity and lifecycle, otherwise a value object.
- Does it orchestrate a single use case (load, decide, save, notify)? It's a handler in `commands/<slice>` or `queries/<slice>`. Business decisions belong in entities and value objects, and handlers only orchestrate.
- Does the handler need something from the outside world? Define a port in `ports/` with only the methods this handler needs, then implement it in `adapters/` or `database/` (real + in-memory).
- Is the same domain logic used by 2+ handlers? Extract it into `services/` as a plain class taking ports in its constructor. Wait until the second real use before extracting (a bad abstraction costs more than duplication).
- Is it technical and unrelated to this module's business? Put it in `infrastructure/`.
- Is it a base abstraction every module reuses? Put it in `libs/`, and keep it free of business vocabulary.

## Component-level rules

- **CCP / SRP**: a slice package changes for one reason (its use case). If a requirement change touches five packages, the boundaries are wrong.
- **CRP / ISP**: don't force a handler to depend on a port with methods it doesn't use. Split the port.
- **ADP**: no cycles between packages or modules. When two modules need each other, communicate through events, or extract a shared stable component.
- **SDP / SAP**: stable things (domain, ports, kernel) are abstract and depended upon. Volatile things (controllers, ORM, clients) are concrete and depend on them, never the reverse.
- Cross-service communication goes through events (`EventSender` + `EventController`) or a dedicated `XxxClientPort`. Never share database tables between services.

## Mapping to other stacks

The layout and rules are stack-agnostic. When the project isn't Java/Spring, keep the same folders and names, and swap the technical pieces:

| Concept | Java / Spring (scaffold) | TypeScript / NestJS | Kotlin / Spring | Python / FastAPI |
| --- | --- | --- | --- | --- |
| Async result | `Mono` / `Flux` | `Promise` / `Observable` | `suspend` / `Flow` | `async def` |
| Handler registration | `@Service` + constructor injection | `@Injectable()` provider | `@Service` | dependency via `Depends` or a composition root |
| Port | `interface` | `interface` + injection token (`Symbol`) | `interface` | `Protocol` / `ABC` |
| Driving HTTP adapter | `@RestController` extends `RestBaseController` | `@Controller` | `@RestController` | `APIRouter` |
| Driving event adapter | `EventController<E>` | `@EventPattern` / `@OnEvent` handler | `EventController<E>` | consumer function |
| Error → HTTP mapping | `GlobalExceptionHandler` | `ExceptionFilter` | `@RestControllerAdvice` | exception handler |
| ORM mapping | R2DBC `OrmEntity` + `ReactiveCrudRepository` | TypeORM/Prisma/MikroORM entity + repository | same as Java | SQLAlchemy model |
| Unit test runner | JUnit 5 + AssertJ + StepVerifier | Jest/Vitest | JUnit 5 + Kotest | pytest |
| E2E infra | Testcontainers | Testcontainers for Node | Testcontainers | testcontainers-python |
| Test data | `AbstractBuilder` + datafaker | builder classes + faker | builders + datafaker | builders / factory_boy + Faker |

Keep the real/in-memory pair for every port whatever the stack, and wire in-memory adapters by hand in unit tests.
