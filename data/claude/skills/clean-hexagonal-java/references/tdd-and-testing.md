# TDD and testing

## Contents
- The loop
- Test types (what each one proves)
- Unit test template
- Test data builders
- Fakes and in-memory adapters
- Asserting published events
- REST contract tests
- E2E tests with Testcontainers
- F.I.R.S.T. and naming

## The loop

The three laws of TDD:
1. Write no production code until you have a failing unit test.
2. Write no more of a test than is sufficient to fail. A compilation failure counts as a failure.
3. Write no more production code than is sufficient to pass the currently failing test.

Red → Green → Refactor, one behavior at a time:

1. **Red**: write the next `should...` test for the smallest behavior not implemented yet. Run it and watch it fail for the right reason.
2. **Green**: write the simplest code that passes. Hard-coding is fine when a later test will force the generalization (triangulation).
3. **Refactor**: with all tests green, remove duplication, improve names, extract value objects or methods, and push logic into entities. Change no behavior.

Order of tests for a new slice: happy path → each validation error → each business rule branch → idempotency or concurrency (e.g. duplicate request, lock already held) → boundaries (empty lists, zero amounts, date edges, rounding).

After you find a bug, write the failing test that reproduces it first. Then test the rest of that function exhaustively, because bugs cluster (T6).

## Test types

| Type | Class suffix | Base | Spring? | Proves |
| --- | --- | --- | --- | --- |
| Unit | `UnitTests` | `HumanReadableTest` | No | Business behavior of one handler, with in-memory adapters. **Most tests are here.** |
| REST contract | `RestControllerTests` | `HumanReadableTest` + `@WebFluxTest(Controller.class)` | Web slice only | Routing, request mapping, status codes, error-code → HTTP mapping |
| E2E | `E2ETests` | `IntegrationTest` | Full context + Testcontainers | Real adapters (SQL, broker, clients) honor the same port contract; wiring works |
| Containers smoke | `ContainersTest` | `IntegrationTest` | Full | Infrastructure is up |

`ReplaceCamelCase` prefixes display names with `[unit]`, `[rest api]`, `[e2e]` or `[integration]` and turns `shouldDoXWhenY` into `should do x when y`. That only works if you follow the suffixes above.

## Unit test template

```java
class PlaceOrderUnitTests implements HumanReadableTest {
    private OrderRepositoryPort orderRepository;
    private InMemoryEventDispatcher eventDispatcher;
    private PlaceOrderCommandHandler handler;

    @BeforeEach
    void setup() {
        this.orderRepository = new OrderInMemoryRepository();
        this.eventDispatcher = new InMemoryEventDispatcher();
        this.handler = new PlaceOrderCommandHandler(
                this.orderRepository,
                new EventSender(this.eventDispatcher),
                new FakeDates());
    }

    @Test
    void shouldPlaceTheOrder() {
        // Given
        final var command = this.givenAPlaceOrderCommand();

        // When
        this.handler.handle(command).block();

        // Then
        this.thenTheOrderShouldBePending(command.getOrderId());
    }

    @Test
    void shouldNotPlaceAnOrderWithoutLines() {
        // Given
        final var command = PlaceOrderCommandBuilder.builder().withLines(List.of()).build();

        // When, Then
        StepVerifier.create(this.handler.handle(command))
                .expectError(OrderWithoutLinesError.class)
                .verify();
    }

    private void thenTheOrderShouldBePending(String orderId) {
        var order = this.orderRepository.findById(new EntityId(orderId)).block();
        assertThat(order.getStatus()).isEqualTo(OrderStatusEnum.PENDING);
    }
}
```

Rules:
- Wire the handler with `new`. Every dependency is an in-memory adapter or a fake, and Mockito is not used in unit tests.
- Given / When / Then comments, with each step extracted into an intention-revealing private method (`given...`, `when...`, `then...`).
- For expected failures, use `StepVerifier.create(handler.handle(cmd)).expectError(XxxError.class).verify()` or `assertThatThrownBy(() -> handler.handle(cmd).block()).isInstanceOf(XxxError.class)`.
- One concept per test. Several `assertThat` lines are fine if they describe the same outcome.

## Test data builders

```java
public class OrderBuilder extends AbstractBuilder {
    private final OrderRepositoryPort orderRepository;
    private OrderStatusEnum status;
    private String customerId;

    private OrderBuilder(OrderRepositoryPort orderRepository) { this.orderRepository = orderRepository; }

    public static OrderBuilder builder(OrderRepositoryPort orderRepository) { return new OrderBuilder(orderRepository); }

    public OrderBuilder withStatus(OrderStatusEnum status) { this.status = status; return this; }
    public OrderBuilder withCustomerId(String customerId) { this.customerId = customerId; return this; }

    public OrderEntity build() {
        var order = new OrderEntity(
                EntityId.generate(),
                new CustomerId(this.orElse(this.customerId, FAKER.internet().uuid())),
                this.orElse(this.status, OrderStatusEnum.PENDING));
        this.orderRepository.create(order).block();
        return order;
    }
}
```

- Builders take the **port**, so the same builder works in unit tests (in-memory) and E2E tests (the real `@Autowired` port).
- Every field has a realistic random default (`orElse(value, default)`, datafaker `FAKER`). Tests only set what matters to them, which keeps them readable and exposes hidden coupling.
- `AbstractBuilder.NULL_VALUE` lets a test force `null` explicitly.
- Builders for commands and contexts (`UseCaseContextBuilder`, `PlaceOrderCommandBuilder`) don't persist anything.

## Fakes and in-memory adapters

- `XxxInMemoryRepository implements XxxRepositoryPort` lives in `src/main/.../database/<aggregate>/` next to the real one and has no Spring annotations. It keeps a `Map`, filters with streams, and throws the same typed errors as the real adapter (e.g. `OrderNotFoundError`).
- Other adapters get in-memory twins too: `XxxInMemoryLock`, `XxxInMemoryClient`, `XxxInMemoryCache`.
- `FakeDates implements DatesPort`, with a settable `currentDate`, lives in `src/test/.../adapters/`.
- If an in-memory adapter and the real one disagree, the E2E tests catch it. Keep them in sync when a port changes.

## Asserting published events

Handlers publish through a sender port implemented by `EventSender`, which delegates to `EventDispatcherPort`. In unit tests, give `EventSender` an `InMemoryEventDispatcher` and inspect what it recorded:

```java
this.eventDispatcher = new InMemoryEventDispatcher();
var eventSender = new EventSender(this.eventDispatcher);
...
this.handler.handle(command).block();

assertThat(this.eventDispatcher.getDispatchedEvents("order_placed", OrderPlaced.class))
        .singleElement()
        .extracting(OrderPlaced::getOrderId)
        .isEqualTo(command.getOrderId());
```

Assert that nothing was sent on failure paths too (`getAllDispatchedEvents()).isEmpty()`).

In production, `SpringEventDispatcher` publishes events in-process, and every `EventController<E>` bean whose event name matches receives them. When the service needs a real broker (Kafka, RabbitMQ, SQS...), add a new `EventDispatcherPort` adapter. Handlers, senders and controllers don't change.

## REST contract tests

```java
@WebFluxTest(CancelOrderRestController.class)
class CancelOrderRestControllerTests implements HumanReadableTest {
    @MockBean private CancelOrderCommandHandler handler;
    @Autowired private WebTestClient webClient;

    @Test
    void shouldReturnAConflictWhenTheOrderIsAlreadyCancelled() {
        when(this.handler.handle(Mockito.any())).thenReturn(Mono.error(new OrderAlreadyCancelledError()));

        this.webClient.post().uri("/order/orders/{orderId}/cancellation", "an-order-id")
                .exchange()
                .expectStatus().isEqualTo(HttpStatus.CONFLICT)
                .expectBody().jsonPath("$.message").isEqualTo("ORDER.ALREADY_CANCELLED");
    }
}
```

These tests are the only place where mocking the handler is fine, because they test the HTTP boundary and not the business behavior. Write one test per error the handler can raise.

## E2E tests with Testcontainers

- Extend `IntegrationTest`: `@SpringBootTest`, `@ActiveProfiles("integration-test")`, a static Postgres container (plus a broker or cache when used), `@DynamicPropertySource`, and a `@BeforeEach` that deletes the rows of `TABLES_TO_CLEAN`.
- `@Autowired` the **ports** (not the adapters) and reuse the unit-test builders to arrange data.
- Drive the system from outside: `WebTestClient` for HTTP slices, or dispatch the incoming event for event slices. Then assert on the stored state (through ports) and on the outgoing events.
- Cover the happy path and one or two important failures. Leave the branch-by-branch coverage to the unit tests.
- Add every new table to `src/test/resources/scripts/init_tables_and_types.sql` and to `TABLES_TO_CLEAN` in `IntegrationTest`.

## F.I.R.S.T. and naming

- **Fast**: unit tests never start Spring or containers.
- **Independent**: no shared mutable state between tests. Rebuild the fakes in `@BeforeEach`.
- **Repeatable**: time goes through `DatesPort`/`FakeDates`, and random data only feeds fields that don't affect the assertion.
- **Self-validating**: assertions only, no printing results for manual inspection.
- **Timely**: the test is written before the code.
- Test names are sentences: `shouldReturnAnErrorWhenPageSizeExceedsTheMaximum`, never `test1` or `testHandle`.
- Keep test code as clean as production code. Duplication in tests gets extracted into builders and `then...` helpers.
- Check coverage with JaCoCo (`mvn verify` → `target/site/jacoco`). Look at uncovered branches, not just the percentage.
