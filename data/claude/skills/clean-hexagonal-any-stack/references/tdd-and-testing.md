# TDD and testing (any stack)

## Contents
- The loop
- Test types
- Unit test shape
- Test data builders
- Fakes and in-memory adapters
- Asserting published events
- Contract tests at the HTTP boundary
- E2E tests against real infrastructure
- F.I.R.S.T. and naming

## The loop

The three laws of TDD:
1. Write no production code until you have a failing unit test.
2. Write no more of a test than is sufficient to fail. A compilation or import error counts as a failure.
3. Write no more production code than is sufficient to pass the currently failing test.

Red → Green → Refactor, one behavior at a time:
1. **Red**: write the next test for the smallest missing behavior. Run it, and watch it fail for the right reason.
2. **Green**: write the simplest code that passes. Hard-coding is fine when the next test will force the generalization (triangulation).
3. **Refactor**: with everything green, remove duplication, improve names, extract value objects or functions, and push logic into entities. Change no behavior.

Order of tests for a new slice: happy path → each validation error → each business rule branch → idempotency or concurrency → boundaries (empty lists, zero amounts, date edges, rounding).

After you find a bug, write the failing test that reproduces it first. Then test the surrounding code thoroughly, because bugs cluster (T6).

## Test types

| Type | Proves | Uses | Share of tests |
| --- | --- | --- | --- |
| Unit | The business behavior of one handler, including domain rules | Handler built by hand with in-memory adapters and fakes. No framework, no I/O. | Most |
| Contract (HTTP) | Routing, request parsing and validation, status codes, error-code mapping | The real HTTP layer (in-process test client) with a stubbed handler | One per route, plus one per error |
| E2E / integration | Real adapters honor the port contract, and the wiring works | The real composition root, Testcontainers or docker compose, HTTP or event input | Happy path plus 1–2 key failures per slice |

Keep them separable (folders, tags, or naming), so the unit and contract suites run without Docker in a few seconds.

## Unit test shape

Pseudo-code, which reads the same in every language:

```
describe "PlaceOrder"
    beforeEach:
        orderRepository = new OrderInMemoryRepository()
        eventDispatcher = new InMemoryEventDispatcher()
        dates           = new FakeDates("2024-01-01T00:00:00Z")
        handler         = new PlaceOrderCommandHandler(orderRepository, new EventSender(eventDispatcher), dates)

    test "should place the order as pending":
        # Given
        command = PlaceOrderCommandBuilder().build()
        # When
        await handler.handle(command)
        # Then
        order = await orderRepository.findById(command.orderId)
        expect(order.status).toBe(PENDING)

    test "should not place an order without lines":
        command = PlaceOrderCommandBuilder().withLines([]).build()
        expect(await handler.handle(command)).toFailWith(OrderWithoutLinesError)
        expect(eventDispatcher.all()).toBeEmpty()
```

Rules:
- Build the handler with the constructor (or factory). Every dependency is an in-memory adapter or a fake, and the domain is never mocked.
- Use Given / When / Then, with each step extracted into an intention-revealing helper when it's more than a line (`givenAPaidOrder()`, `thenTheOrderShouldBe(...)`).
- Assert on the error **type**, or on its stable code, never on the message text.
- One concept per test. Several assertions are fine when they describe the same outcome.

## Test data builders

```
class OrderBuilder
    constructor(repository: OrderRepositoryPort)
    withStatus(status) -> this
    withCustomerId(id) -> this
    async build() -> Order:
        order = new Order(EntityId.generate(), CustomerId(customerId ?? faker.uuid()), status ?? PENDING)
        await repository.create(order)
        return order
```

- Builders take the **port**, so the same builder arranges data for unit tests (in-memory) and E2E tests (real adapter).
- Every field has a realistic random default (faker). A test only sets what matters to it.
- Command, query and context builders don't persist anything.

## Fakes and in-memory adapters

- `XxxInMemoryRepository` implements the same port as the real repository. It lives next to it (or in test support if the language makes that awkward), keeps a map, and raises **the same typed errors** as the real one.
- Other adapters get in-memory twins too (clients, locks, caches). `FakeDates` has a settable current date.
- The E2E tests are the safety net that keeps twins and real adapters in sync. Update both whenever a port changes.
- Mocks are acceptable only at boundaries you don't own and can't fake cheaply. Even there, prefer a hand-written fake.

## Asserting published events

```
await handler.handle(command)
events = eventDispatcher.dispatched("order_placed", OrderPlaced)
expect(events).toHaveLength(1)
expect(events[0].orderId).toBe(command.orderId)
```

Also assert that nothing was dispatched on failure paths.

## Contract tests at the HTTP boundary

```
test "should return 409 ORDER.ALREADY_CANCELLED when the order is already cancelled":
    handler = stub(CancelOrderCommandHandler, fails with OrderAlreadyCancelledError)
    app     = buildHttpApp(overrides: { cancelOrderHandler: handler })
    response = POST /order/orders/42/cancellation
    expect(response.status).toBe(409)
    expect(response.body.message).toBe("ORDER.ALREADY_CANCELLED")
```

This is the only place where stubbing the handler is fine, because the test is about the HTTP boundary, not about behavior. Also cover request validation (missing field → 400 with a stable code).

## E2E tests against real infrastructure

- Start real dependencies with Testcontainers (available for Node, Python, Go, .NET, JVM and Rust) or docker compose, once per test run.
- Build the application with the **real** composition root, overriding only the configuration (connection strings).
- Reset state before each test (truncate the module's tables, purge queues). Keep the list of tables next to the migrations so it can't drift.
- Arrange data through ports and builders, act through HTTP or by publishing the incoming event, and assert on stored state (through ports) and outgoing events.

## F.I.R.S.T. and naming

- **Fast**: unit tests never start the framework, a server, or containers.
- **Independent**: no shared mutable state. Rebuild fakes before each test.
- **Repeatable**: time and ids come from fakes, and random data only feeds fields the assertion doesn't depend on.
- **Self-validating**: assertions only, no printing results for manual inspection.
- **Timely**: the test is written before the code.
- Test names are sentences: "should return an error when page size exceeds the maximum", never `test1` or `testHandle`.
- Test code is held to the same standard as production code. Extract duplication into builders and helpers.
- Track coverage (c8/istanbul, coverage.py, `go test -cover`, coverlet, JaCoCo, tarpaulin), and look at uncovered branches, not the percentage.
