# Stack guides

How to express the kernel contract (`kernel.md`) and the layout (`architecture.md`) idiomatically in each stack. Every section uses the same example slice, **CancelOrder**: load the order, `order.cancel()` (which fails with `ORDER.ALREADY_CANCELLED`), save it, and send `order_cancelled`.

If the user's stack isn't listed, map the same concepts: interface/protocol for ports, a constructor or factory for injection, a native async type, typed errors plus one edge mapper, a unit test runner, an HTTP test client, and Testcontainers.

## Contents
- TypeScript (Node: Fastify/Express, or NestJS)
- Python (FastAPI)
- Go
- C# (.NET / ASP.NET Core)
- Kotlin (Ktor or Spring)
- Rust (axum)
- PHP (Symfony / Laravel)
- Architecture enforcement tools

---

## TypeScript (Node: Fastify/Express, or NestJS)

**Toolchain**: `npm`/`pnpm`, `typescript` in `strict` mode, ESLint + Prettier, Vitest (or Jest), `@faker-js/faker`, `testcontainers`, Supertest (Express), Fastify `inject()`, or `@nestjs/testing`. Persistence: `pg`/Kysely/Drizzle/Prisma/TypeORM, but ORM models stay in `database/`.

**Layout**: `src/libs/ddd`, `src/libs/errors`, `src/modules/order/commands/cancel-order/{cancel-order.command.ts, cancel-order.handler.ts, cancel-order.http.ts}`, `src/main.ts` (composition root). Tests go in `test/` or as `*.spec.ts` next to the code.

**Ports**: TS `interface`s are erased at runtime. Without a container, pass them through constructors. With NestJS, declare a token (`export const ORDER_REPOSITORY = Symbol('OrderRepositoryPort')`) and register handlers with **factory providers**, so the handler classes stay free of Nest decorators:

```ts
{ provide: CancelOrderCommandHandler,
  useFactory: (orders: OrderRepositoryPort, sender: EventSender) => new CancelOrderCommandHandler(orders, sender),
  inject: [ORDER_REPOSITORY, EventSender] }
```

**Kernel sketch**:

```ts
export abstract class AppError extends Error {
  abstract readonly category: 'INVALID_ARGUMENT' | 'NOT_FOUND' | 'CONFLICT' | 'UNPROCESSABLE';
  constructor(readonly code: string) { super(code); this.name = new.target.name; }
}
export class ConflictError extends AppError { readonly category = 'CONFLICT' as const; }

export abstract class CommandHandler<C extends Command> {
  private readonly logger = new Logger(this.constructor.name);
  async handle(command: C): Promise<void> {
    this.logger.info(`Handling ${command.constructor.name} [correlation: ${command.correlationId.value}]`);
    try { await this.execute(command); }
    catch (error) { this.logger.error(`Failed handling ${command.constructor.name} [correlation: ${command.correlationId.value}]`, error); throw error; }
  }
  protected abstract execute(command: C): Promise<void>;
}
```

**Slice**:

```ts
export class OrderAlreadyCancelledError extends ConflictError {
  static readonly CODE = 'ORDER.ALREADY_CANCELLED';
  constructor() { super(OrderAlreadyCancelledError.CODE); }
}

export class CancelOrderCommandHandler extends CommandHandler<CancelOrderCommand> {
  constructor(
    private readonly orders: OrderRepositoryPort,
    private readonly orderCancelledSender: OrderCancelledEventSenderPort,
  ) { super(); }

  protected async execute(command: CancelOrderCommand): Promise<void> {
    const order = await this.orders.findById(command.orderId);
    const cancelledOrder = order.cancel();
    await this.orders.update(cancelledOrder);
    await this.orderCancelledSender.sendOrderCancelled(new OrderCancelled(command.context, cancelledOrder.id));
  }
}
```

**Unit test (Vitest)**:

```ts
describe('CancelOrder', () => {
  let orders: OrderInMemoryRepository;
  let dispatcher: InMemoryEventDispatcher;
  let handler: CancelOrderCommandHandler;

  beforeEach(() => {
    orders = new OrderInMemoryRepository();
    dispatcher = new InMemoryEventDispatcher();
    handler = new CancelOrderCommandHandler(orders, new EventSender(dispatcher));
  });

  it('should not cancel an order that is already cancelled', async () => {
    const order = await OrderBuilder.of(orders).withStatus(OrderStatus.Cancelled).build();

    await expect(handler.handle(new CancelOrderCommand(aUseCaseContext(), order.id)))
      .rejects.toBeInstanceOf(OrderAlreadyCancelledError);
    expect(dispatcher.all()).toHaveLength(0);
  });
});
```

**Error mapper**: a Fastify `setErrorHandler`, an Express error middleware `(err, req, res, next)`, or a Nest `@Catch() ExceptionFilter`, mapping `category` → status and returning `{ code, message: err.code }`. Validate request bodies at the edge with zod/TypeBox/class-validator, and turn failures into an `InvalidArgumentError` with a stable code.

---

## Python (FastAPI)

**Toolchain**: `uv` (or Poetry), Python 3.12+, `ruff` (lint + format), `mypy --strict` or `pyright`, `pytest` + `pytest-asyncio`, `faker`, `httpx` (`AsyncClient(transport=ASGITransport(app))`), `testcontainers[postgres]`, SQLAlchemy 2 async or `asyncpg`, `import-linter`.

**Layout**: `src/<package>/libs/ddd`, `src/<package>/modules/order/commands/cancel_order/{command.py, handler.py, http.py}`, `src/<package>/main.py` (composition root: `create_app(settings)`), `tests/...`.

**Idioms**: ports are `typing.Protocol`. Value objects are `@dataclass(frozen=True, slots=True)` with validation in `__post_init__`. Build handlers in the composition root and expose them to routes through `app.state` or a small `Depends` provider. Handlers never import FastAPI.

```python
class AppError(Exception):
    category: ClassVar[Category]
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code

class ConflictError(AppError):
    category = Category.CONFLICT

class OrderAlreadyCancelledError(ConflictError):
    CODE: Final = "ORDER.ALREADY_CANCELLED"
    def __init__(self) -> None:
        super().__init__(self.CODE)


class OrderRepositoryPort(Protocol):
    async def find_by_id(self, order_id: EntityId) -> Order: ...
    async def update(self, order: Order) -> None: ...


class CancelOrderCommandHandler(CommandHandler[CancelOrderCommand]):
    def __init__(self, orders: OrderRepositoryPort, order_cancelled_sender: OrderCancelledEventSenderPort) -> None:
        super().__init__()
        self._orders = orders
        self._order_cancelled_sender = order_cancelled_sender

    async def _execute(self, command: CancelOrderCommand) -> None:
        order = await self._orders.find_by_id(command.order_id)
        cancelled_order = order.cancel()
        await self._orders.update(cancelled_order)
        await self._order_cancelled_sender.send_order_cancelled(OrderCancelled(command.context, cancelled_order.id))
```

```python
async def test_should_not_cancel_an_order_that_is_already_cancelled() -> None:
    # Given
    orders = OrderInMemoryRepository()
    dispatcher = InMemoryEventDispatcher()
    handler = CancelOrderCommandHandler(orders, EventSender(dispatcher))
    order = await OrderBuilder(orders).with_status(OrderStatus.CANCELLED).build()

    # When, Then
    with pytest.raises(OrderAlreadyCancelledError):
        await handler.handle(CancelOrderCommand(a_use_case_context(), order.id))
    assert dispatcher.all() == []
```

**Error mapper**: `@app.exception_handler(AppError)` returning `JSONResponse(status_code=STATUS[err.category], content={"code": ..., "message": err.code})`. Pydantic request models live in `http.py` and are converted into commands there.

---

## Go

**Toolchain**: Go modules, `gofmt`/`goimports`, `golangci-lint`, the standard `testing` package (optionally `testify`), `net/http/httptest`, `testcontainers-go`, `pgx`/`sqlc`, `go-arch-lint`.

**Layout (idiomatic Go, same concepts)**:

```
cmd/order-service/main.go            composition root
internal/kernel/                     EntityID, UseCaseContext, AppError, DatesPort, EventDispatcher, WithLogging
internal/order/domain/               Order, Money, OrderCancelled, errors
internal/order/cancelorder/          Command, Handler, HTTP handler (ports declared here, by the consumer)
internal/order/postgres/             OrderRepository (real)
internal/order/inmemory/             OrderRepository (twin)
internal/order/events/               Sender
internal/platform/http/              router, error mapper
```

**Idioms**: there's no inheritance. Wrap handlers for cross-cutting concerns with a generic decorator (`kernel.WithLogging[C](name, next)`). Small interfaces are declared by the package that uses them. `context.Context` (cancellation and deadlines) is separate from `kernel.UseCaseContext` (correlation id, requestedAt, tenant), which the command carries. Errors are values: define `*kernel.AppError{Code, Category}` sentinels, check them with `errors.Is`/`errors.As`, and wrap them with `fmt.Errorf("update order: %w", err)`.

```go
var ErrOrderAlreadyCancelled = kernel.Conflict("ORDER.ALREADY_CANCELLED")

type OrderRepository interface {
	FindByID(ctx context.Context, id kernel.EntityID) (domain.Order, error)
	Update(ctx context.Context, order domain.Order) error
}

type OrderCancelledSender interface {
	SendOrderCancelled(ctx context.Context, event domain.OrderCancelled) error
}

type Handler struct {
	orders OrderRepository
	sender OrderCancelledSender
}

func NewHandler(orders OrderRepository, sender OrderCancelledSender) *Handler {
	return &Handler{orders: orders, sender: sender}
}

func (h *Handler) Handle(ctx context.Context, cmd Command) error {
	order, err := h.orders.FindByID(ctx, cmd.OrderID)
	if err != nil {
		return err
	}
	cancelledOrder, err := order.Cancel()
	if err != nil {
		return err
	}
	if err := h.orders.Update(ctx, cancelledOrder); err != nil {
		return fmt.Errorf("update order: %w", err)
	}
	return h.sender.SendOrderCancelled(ctx, domain.NewOrderCancelled(cmd.Context, cancelledOrder.ID()))
}
```

```go
func TestCancelOrder(t *testing.T) {
	t.Run("should not cancel an order that is already cancelled", func(t *testing.T) {
		// Given
		orders := inmemory.NewOrderRepository()
		dispatcher := inmemory.NewEventDispatcher()
		handler := cancelorder.NewHandler(orders, events.NewSender(dispatcher))
		order := builders.AnOrder(t, orders).WithStatus(domain.StatusCancelled).Build()

		// When
		err := handler.Handle(context.Background(), cancelorder.Command{Context: builders.AUseCaseContext(), OrderID: order.ID()})

		// Then
		if !errors.Is(err, domain.ErrOrderAlreadyCancelled) {
			t.Fatalf("expected ErrOrderAlreadyCancelled, got %v", err)
		}
		if got := len(dispatcher.All()); got != 0 {
			t.Fatalf("expected no event, got %d", got)
		}
	})
}
```

**Error mapper**: one `writeError(w, err)` helper used by every HTTP handler. It extracts the category with `errors.As(err, &appErr)`, writes the status and `{code, message}`, and logs and hides anything else behind a 500.

---

## C# (.NET / ASP.NET Core)

**Toolchain**: `dotnet new sln`, with one project per layer when enforcement matters (`Order.Domain`, `Order.Application`, `Order.Infrastructure`, `Order.Api`) or folders in one project, `dotnet format`, nullable enabled, xUnit, an assertion library (Shouldly or AwesomeAssertions), Bogus, `WebApplicationFactory<Program>`, Testcontainers for .NET, EF Core or Dapper, NetArchTest.

**Idioms**: `record` for value objects, commands and events. `Task` async with a `CancellationToken`. Constructor injection, registered in one `IServiceCollection` extension per module (`services.AddOrderModule(configuration)`), which is the composition root. Handlers are plain classes. MediatR is optional, and adds nothing the base handler doesn't.

```csharp
public sealed class OrderAlreadyCancelledError() : ConflictError("ORDER.ALREADY_CANCELLED");

public sealed class CancelOrderCommandHandler(
    IOrderRepositoryPort orders,
    IOrderCancelledEventSenderPort orderCancelledSender,
    ILogger<CancelOrderCommandHandler> logger) : CommandHandler<CancelOrderCommand>(logger)
{
    protected override async Task Execute(CancelOrderCommand command, CancellationToken cancellationToken)
    {
        var order = await orders.FindById(command.OrderId, cancellationToken);
        var cancelledOrder = order.Cancel();
        await orders.Update(cancelledOrder, cancellationToken);
        await orderCancelledSender.SendOrderCancelled(new OrderCancelled(command.Context, cancelledOrder.Id), cancellationToken);
    }
}
```

```csharp
[Fact]
public async Task ShouldNotCancelAnOrderThatIsAlreadyCancelled()
{
    // Given
    var order = await OrderBuilder.Of(_orders).WithStatus(OrderStatus.Cancelled).Build();

    // When
    var act = () => _handler.Handle(new CancelOrderCommand(AUseCaseContext(), order.Id), CancellationToken.None);

    // Then
    await Should.ThrowAsync<OrderAlreadyCancelledError>(act);
    _dispatcher.All().ShouldBeEmpty();
}
```

**Error mapper**: an `IExceptionHandler` (.NET 8+) registered with `AddExceptionHandler`, mapping `AppError.Category` → status and writing `{ code, message }`.

---

## Kotlin (Ktor or Spring)

**Toolchain**: Gradle Kotlin DSL, ktlint/detekt, JUnit 5 or Kotest, kotlinx-coroutines-test, Testcontainers, Exposed/jOOQ/Spring Data R2DBC, Konsist or ArchUnit.

**Idioms**: `@JvmInline value class` for ids, `data class` for value objects, commands and events. `suspend` functions for ports and handlers. `sealed` hierarchies work well for error categories. With Spring, the Java skill's layout and kernel translate one-to-one. With Ktor, wire things by hand in `Application.module()` or with Koin.

```kotlin
class OrderAlreadyCancelledError : ConflictError("ORDER.ALREADY_CANCELLED")

class CancelOrderCommandHandler(
    private val orders: OrderRepositoryPort,
    private val orderCancelledSender: OrderCancelledEventSenderPort,
) : CommandHandler<CancelOrderCommand>() {
    override suspend fun execute(command: CancelOrderCommand) {
        val cancelledOrder = orders.findById(command.orderId).cancel()
        orders.update(cancelledOrder)
        orderCancelledSender.sendOrderCancelled(OrderCancelled(command.context, cancelledOrder.id))
    }
}
```

```kotlin
@Test
fun `should not cancel an order that is already cancelled`() = runTest {
    val order = OrderBuilder(orders).withStatus(OrderStatus.CANCELLED).build()

    assertThrows<OrderAlreadyCancelledError> { handler.handle(CancelOrderCommand(aUseCaseContext(), order.id)) }
    assertThat(dispatcher.all()).isEmpty()
}
```

**Error mapper**: Ktor `StatusPages { exception<AppError> { call, e -> ... } }`, or a Spring `@RestControllerAdvice`.

---

## Rust (axum)

**Toolchain**: Cargo workspace, `rustfmt`, `clippy -D warnings`, `tokio`, `axum`, `sqlx`, `thiserror`, `fake`, `testcontainers` + `testcontainers-modules`, `cargo-tarpaulin` or `llvm-cov`.

**Idioms**: enforce the dependency rule with crates: `domain` (no I/O dependencies), `application` (handlers + port traits), `infrastructure` (sqlx, HTTP clients), `api` (axum, composition root). Newtypes with `TryFrom` for value objects. Ports are traits. Native `async fn` in traits works for generics, and `dyn` ports need the `async-trait` crate or boxed futures. Errors are a `thiserror` enum per module, with a `category()` method.

```rust
#[derive(Debug, thiserror::Error)]
pub enum OrderError {
    #[error("ORDER.NOT_FOUND")] NotFound,
    #[error("ORDER.ALREADY_CANCELLED")] AlreadyCancelled,
}

pub struct CancelOrderCommandHandler<R: OrderRepositoryPort, S: OrderCancelledEventSenderPort> {
    orders: R,
    order_cancelled_sender: S,
}

impl<R: OrderRepositoryPort, S: OrderCancelledEventSenderPort> CancelOrderCommandHandler<R, S> {
    pub async fn handle(&self, command: CancelOrderCommand) -> Result<(), AppError> {
        let order = self.orders.find_by_id(&command.order_id).await?;
        let cancelled_order = order.cancel()?;
        self.orders.update(&cancelled_order).await?;
        self.order_cancelled_sender
            .send_order_cancelled(OrderCancelled::new(&command.context, cancelled_order.id()))
            .await
    }
}
```

```rust
#[tokio::test]
async fn should_not_cancel_an_order_that_is_already_cancelled() {
    let orders = OrderInMemoryRepository::default();
    let dispatcher = InMemoryEventDispatcher::default();
    let order = OrderBuilder::new(&orders).with_status(OrderStatus::Cancelled).build().await;
    let handler = CancelOrderCommandHandler::new(orders.clone(), EventSender::new(dispatcher.clone()));

    let result = handler.handle(CancelOrderCommand::new(a_use_case_context(), order.id().clone())).await;

    assert!(matches!(result, Err(AppError::Order(OrderError::AlreadyCancelled))));
    assert!(dispatcher.all().is_empty());
}
```

**Error mapper**: `impl IntoResponse for AppError`, mapping `category()` → `StatusCode`, with a JSON `{code, message}` body.

---

## PHP (Symfony / Laravel)

PHP 8.2+ `readonly` classes for value objects, commands and events. Constructor injection through the framework container, configured in one place per module. PHPUnit or Pest, Testcontainers for PHP or docker compose, Doctrine/Eloquent kept in `database/`, a kernel exception listener (Symfony) or exception handler (Laravel) as the error mapper, and Deptrac for layer rules. Keep framework attributes out of `domain/` and handlers.

---

## Architecture enforcement tools

| Stack | Tool | Rule to add first |
| --- | --- | --- |
| TypeScript | `dependency-cruiser` or `eslint-plugin-boundaries` | `domain` must not import `adapters`, `database`, `infrastructure`, or framework packages |
| Python | `import-linter` (layers contract) | `modules.*.domain` is independent of `adapters`, `database`, `fastapi`, `sqlalchemy` |
| Go | `go-arch-lint`, or `depguard` in golangci-lint | `domain` packages don't import `postgres`, `http`, `database/sql` |
| C# | NetArchTest or project references | `Order.Domain` references nothing but the kernel |
| Kotlin/Java | Konsist / ArchUnit | same as above |
| Rust | crate boundaries | `domain` crate has no I/O dependencies |
| PHP | Deptrac | same as above |

Add the rule in the first commit, so the architecture can't erode silently.
