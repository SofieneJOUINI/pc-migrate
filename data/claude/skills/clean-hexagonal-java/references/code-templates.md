# Code templates

The placeholders are `<base>` (e.g. `com.acme.orders`), `<module>` (e.g. `order`), and `<slice>` (the lowercase package, e.g. `cancelorder`). The examples use a small "order" domain. Rename everything to the real ubiquitous language.

Kernel classes are generated under `<base>.libs`:

| Concept | Class |
| --- | --- |
| Command / handler | `libs.ddd.usecases.BaseCommand`, `BaseCommandHandler<C>` (`handle` → `execute`) |
| Query / handler | `libs.ddd.usecases.BaseQuery`, `BaseQueryHandler<Q, R>` (`handleMono` / `handleFlux` → `execute`) |
| REST base | `libs.ddd.usecases.RestBaseController` (`generateUseCaseContext()`, or `generateUseCaseContext(tenantId)` when multi-tenant) |
| Context | `libs.ddd.domain.valueobjects.UseCaseContext(correlationId, requestedAt)`, or `(correlationId, tenantId, requestedAt)` when multi-tenant |
| Entity / id | `libs.ddd.domain.entities.BaseEntity<EntityId>`, `libs.ddd.domain.valueobjects.EntityId` |
| Event base | `libs.ddd.domain.events.BaseEvent` (ctor takes `UseCaseContext`, `toUseCaseContext()`) |
| Event plumbing | `libs.ddd.events.EventDispatcherPort`, `EventController<E>` |
| Clock | `libs.ddd.ports.DatesPort` |
| Errors | `libs.exceptions.{ArgumentInvalidException, NotFoundException, ConflictException, UnprocessableEntityException}` |

The templates below are single-tenant. For multi-tenant projects, apply the changes in `multi-tenancy.md`: the `/{tenantId}` route prefix, `TenantId` in ports and entities, and `tenant_id` in SQL.

## Contents
- Command slice (HTTP-triggered)
- Command slice (event-triggered)
- Query slice
- Ports
- Event sender adapter
- In-memory repository
- Postgres (R2DBC) repository
- Entity, value object, enum
- Domain event
- Errors

## Command slice (HTTP-triggered)

```java
// commands/cancelorder/CancelOrderCommand.java
public class CancelOrderCommand extends BaseCommand {
    private final String orderId;

    public CancelOrderCommand(UseCaseContext context, String orderId) {
        super(context);
        this.orderId = orderId;
    }

    public String getOrderId() { return orderId; }
}
```

```java
// commands/cancelorder/CancelOrderCommandHandler.java
@Service
public class CancelOrderCommandHandler extends BaseCommandHandler<CancelOrderCommand> {
    private final OrderRepositoryPort orderRepository;
    private final OrderCancelledEventSenderPort orderCancelledEventSender;

    public CancelOrderCommandHandler(OrderRepositoryPort orderRepository,
                                     OrderCancelledEventSenderPort orderCancelledEventSender) {
        this.orderRepository = orderRepository;
        this.orderCancelledEventSender = orderCancelledEventSender;
    }

    @Override
    protected Mono<Void> execute(CancelOrderCommand command) {
        return this.orderRepository.findById(new EntityId(command.getOrderId()))
                .map(OrderEntity::cancel)
                .flatMap(order -> this.orderRepository.update(order)
                        .then(this.sendOrderCancelledEvent(command.getContext(), order)));
    }

    private Mono<Void> sendOrderCancelledEvent(UseCaseContext context, OrderEntity order) {
        return this.orderCancelledEventSender.sendOrderCancelledEvent(
                new OrderCancelled(context, order.getId().getValue()));
    }
}
```

The handler reads like a story: load → ask the entity to decide → persist → notify. Each step is a well-named private method at one level of abstraction.

```java
// commands/placeorder/PlaceOrderHttpRequest.java
public record PlaceOrderHttpRequest(String customerId, List<OrderLineHttpRequest> lines) {
}
```

```java
// commands/cancelorder/CancelOrderRestController.java
@RestController
@RequestMapping("/order")
public class CancelOrderRestController extends RestBaseController {
    private final CancelOrderCommandHandler cancelOrderCommandHandler;

    public CancelOrderRestController(CancelOrderCommandHandler cancelOrderCommandHandler) {
        this.cancelOrderCommandHandler = cancelOrderCommandHandler;
    }

    @PostMapping("/orders/{orderId}/cancellation")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    Mono<Void> cancelOrder(@PathVariable String orderId) {
        return this.cancelOrderCommandHandler.handle(new CancelOrderCommand(
                this.generateUseCaseContext(),
                orderId));
    }
}
```

Controllers only translate. HTTP goes in, a command comes out. No `if`, no business logic. The route prefix is the module name in kebab-case, matching the health check.

## Command slice (event-triggered)

```java
// commands/reservestock/ReserveStockEventController.java
@Component
public class ReserveStockEventController extends EventController<OrderPlaced> {
    private final ReserveStockCommandHandler reserveStockCommandHandler;

    public ReserveStockEventController(ReserveStockCommandHandler reserveStockCommandHandler) {
        super(OrderPlaced.class, OrderPlaced.EVENT_NAME);
        this.reserveStockCommandHandler = reserveStockCommandHandler;
    }

    @Override
    protected Mono<Void> execute(OrderPlaced event) {
        return this.reserveStockCommandHandler.handle(new ReserveStockCommand(
                event.toUseCaseContext(),
                event.getOrderId()));
    }
}
```

`toUseCaseContext()` keeps the correlation id, so a chain of events can be traced across slices. Gate optional flows with `@ConditionalOnProperty(value = "features.<flow>.enabled", havingValue = "true")`.

## Query slice

```java
public class GetOrderByIdQuery extends BaseQuery {
    private final String orderId;
    public GetOrderByIdQuery(UseCaseContext context, String orderId) { super(context); this.orderId = orderId; }
    public String getOrderId() { return orderId; }
}

@Service
public class GetOrderByIdQueryHandler extends BaseQueryHandler<GetOrderByIdQuery, OrderEntity> {
    private final OrderRepositoryPort orderRepository;

    public GetOrderByIdQueryHandler(OrderRepositoryPort orderRepository) {
        this.orderRepository = orderRepository;
    }

    @Override
    protected Mono<OrderEntity> execute(GetOrderByIdQuery query) {
        return this.orderRepository.findById(new EntityId(query.getOrderId()));
    }
}

public record GetOrderByIdResponse(String id, String status, String total) {
    public GetOrderByIdResponse(OrderEntity order) {
        this(order.getId().getValue(), order.getStatus().name(), order.getTotal().toString());
    }
}

@RestController
@RequestMapping("/order")
public class GetOrderByIdRestController extends RestBaseController {
    private final GetOrderByIdQueryHandler getOrderByIdQueryHandler;
    // constructor ...

    @GetMapping("/orders/{orderId}")
    Mono<GetOrderByIdResponse> getOrderById(@PathVariable String orderId) {
        return this.getOrderByIdQueryHandler
                .handleMono(new GetOrderByIdQuery(this.generateUseCaseContext(), orderId))
                .map(GetOrderByIdResponse::new);
    }
}
```

List queries return `Flux` through `handleFlux`, or a paginated response object. Validate the query inputs (page size, date range, id format) in the handler or a `services/Validate...Service`, throwing `ArgumentInvalidException` subclasses.

## Ports

```java
public interface OrderRepositoryPort {
    Mono<OrderEntity> findById(EntityId id);   // errors with OrderNotFoundError when absent
    Mono<Void> create(OrderEntity order);
    Mono<Void> update(OrderEntity order);
}

public interface OrderCancelledEventSenderPort {
    Mono<Void> sendOrderCancelledEvent(OrderCancelled event);
}
```

Name methods in domain terms (`findOrdersAwaitingPaymentSince`), not SQL terms. Return domain entities and value objects, never ORM rows.

## Event sender adapter

The scaffold generates an empty `EventSender`. Add one sender port per event and implement them all here:

```java
@Component
public class EventSender implements OrderPlacedEventSenderPort, OrderCancelledEventSenderPort {
    private final EventDispatcherPort eventDispatcher;

    public EventSender(EventDispatcherPort eventDispatcher) { this.eventDispatcher = eventDispatcher; }

    @Override
    public Mono<Void> sendOrderPlacedEvent(OrderPlaced event) {
        return this.eventDispatcher.dispatch(OrderPlaced.EVENT_NAME, event);
    }

    @Override
    public Mono<Void> sendOrderCancelledEvent(OrderCancelled event) {
        return this.eventDispatcher.dispatch(OrderCancelled.EVENT_NAME, event);
    }
}
```

List each event, its name and its payload in the README (or an AsyncAPI document when other services consume it).

## In-memory repository

```java
public class OrderInMemoryRepository implements OrderRepositoryPort {
    private final Map<EntityId, OrderEntity> savedEntities = new ConcurrentHashMap<>();

    @Override
    public Mono<OrderEntity> findById(EntityId id) {
        return Mono.justOrEmpty(this.savedEntities.get(id))
                .switchIfEmpty(Mono.error(new OrderNotFoundError()));
    }

    @Override
    public Mono<Void> create(OrderEntity order) {
        return Mono.fromRunnable(() -> this.savedEntities.put(order.getId(), order));
    }

    @Override
    public Mono<Void> update(OrderEntity order) {
        return this.create(order);
    }
}
```

## Postgres (R2DBC) repository

```java
@Table("customer_order")
public class OrderOrmEntity implements Persistable<String> {
    @Id private String id;
    @Column("customer_id") private String customerId;
    @Column("status") private String status;
    @Column("total_amount") private BigDecimal totalAmount;
    @Column("currency") private String currency;
    @Transient @JsonIgnore private boolean isNew;

    public OrderOrmEntity() { }

    public OrderOrmEntity(OrderEntity order) {
        this.id = order.getId().getValue();
        this.customerId = order.getCustomerId().value();
        this.status = order.getStatus().name();
        this.totalAmount = order.getTotal().amount();
        this.currency = order.getTotal().currency();
    }

    public OrderEntity toEntity() {
        return new OrderEntity(new EntityId(this.id), new CustomerId(this.customerId),
                OrderStatusEnum.valueOf(this.status), new Money(this.totalAmount, this.currency));
    }

    @Override public String getId() { return this.id; }
    @Override public boolean isNew() { return this.isNew; }
    public OrderOrmEntity setNew(boolean isNew) { this.isNew = isNew; return this; }
}

@Repository
public interface OrderRepository extends ReactiveCrudRepository<OrderOrmEntity, String> {
    @Query("SELECT * FROM customer_order WHERE status = :status")
    Flux<OrderOrmEntity> findAllByStatus(String status);
}

@Component
public class OrderOrmRepositoryImpl implements OrderRepositoryPort {
    private final OrderRepository orderRepository;

    public OrderOrmRepositoryImpl(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    @Override
    public Mono<OrderEntity> findById(EntityId id) {
        return this.orderRepository.findById(id.getValue())
                .map(OrderOrmEntity::toEntity)
                .switchIfEmpty(Mono.error(new OrderNotFoundError()));
    }

    @Override
    public Mono<Void> create(OrderEntity order) {
        return this.orderRepository.save(new OrderOrmEntity(order).setNew(true)).then();
    }

    @Override
    public Mono<Void> update(OrderEntity order) {
        return this.orderRepository.save(new OrderOrmEntity(order)).then();
    }
}
```

For multi-row updates, use `DatabaseClient.sql(...).bind(...)` inside the `...OrmRepositoryImpl`. SQL never leaks out of `database/`. Avoid reserved words as table names (`order`, `user`).

## Entity, value object, enum

```java
public class OrderEntity extends BaseEntity<EntityId> {
    private final CustomerId customerId;
    private final OrderStatusEnum status;
    private final Money total;

    public OrderEntity(EntityId id, CustomerId customerId, OrderStatusEnum status, Money total) {
        super(id);
        this.customerId = customerId;
        this.status = status;
        this.total = total;
    }

    public OrderEntity cancel() {
        if (this.status == OrderStatusEnum.CANCELLED) throw new OrderAlreadyCancelledError();
        if (this.status == OrderStatusEnum.SHIPPED) throw new OrderAlreadyShippedError();
        return new OrderEntity(this.getId(), this.customerId, OrderStatusEnum.CANCELLED, this.total);
    }

    public CustomerId getCustomerId() { return customerId; }
    public OrderStatusEnum getStatus() { return status; }
    public Money getTotal() { return total; }
}
```

- Behavior lives on the entity (`cancel`, `ship`, `addLine`), with intention-revealing names. Prefer returning a new instance to mutating shared state.
- No public setters. Construct entities in a valid state.

```java
public record Money(BigDecimal amount, String currency) {
    public Money {
        if (amount == null) throw new MoneyAmountEmptyError();
        if (currency == null || currency.isBlank()) throw new CurrencyEmptyError();
    }

    public boolean isZero() { return this.amount.signum() == 0; }
}

public record CustomerId(String value) {
    public CustomerId {
        if (value == null || value.isBlank()) throw new CustomerIdEmptyError();
    }
}

public enum OrderStatusEnum { PENDING, PAID, SHIPPED, CANCELLED }
```

Value objects are immutable, validate themselves in the constructor, and replace primitive obsession (ids, emails, amounts, date ranges). When an enum is persisted as a number, give it an explicit `id` field instead of relying on `ordinal()`.

## Domain event

```java
public class OrderCancelled extends BaseEvent {
    public static final String EVENT_NAME = "order_cancelled";
    private final String orderId;

    public OrderCancelled(UseCaseContext context, String orderId) {
        super(context);
        this.orderId = orderId;
    }

    public String getOrderId() { return orderId; }
}
```

Events carry the ids and values that consumers need, and never ORM rows. Name them in the past tense for facts (`OrderPlaced`, `PaymentReceived`), or in the imperative when they are requests addressed to another service (`ShipmentRequested`).

## Errors

```java
public class OrderNotFoundError extends NotFoundException {
    private static final String ERROR_CODE = "ORDER.NOT_FOUND";

    public OrderNotFoundError() {
        super(ERROR_CODE);
    }
}
```

| Base class | HTTP | Use for |
| --- | --- | --- |
| `ArgumentInvalidException` | 400 | malformed or invalid input (`PAGE_SIZE.INVALID`, `CUSTOMER.ID_EMPTY`) |
| `NotFoundException` | 404 | an aggregate that doesn't exist |
| `ConflictException` | 409 | state conflicts (`ORDER.ALREADY_CANCELLED`) |
| `UnprocessableEntityException` | 422 | a valid request that business rules refuse (`ORDER.CREDIT_LIMIT_EXCEEDED`) |

Errors that never reach HTTP and are only used for control flow inside a handler (caught with `onErrorResume`) may extend `RuntimeException` directly.
