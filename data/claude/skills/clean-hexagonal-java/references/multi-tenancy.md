# Multi-tenancy

Read this when the project was scaffolded with `--multi-tenant`, or when a single-tenant project must become multi-tenant.

## Contents
- When to use it
- What the scaffold generates
- The rules
- Slice templates (tenant-aware)
- Persistence
- Events
- Tests
- Where the tenant comes from
- Converting a single-tenant project

## When to use it

Use it when **one deployment serves several customers/organizations whose data must stay isolated** (SaaS, white-label platforms, one service per market or country). Don't use it just because there are users. Users belong to a tenant, they don't replace it. Don't use it either when each customer gets its own deployment and database (that's single-tenant, repeated).

If unsure, ask the user: "Will one running instance hold data for several customers who must never see each other's data?"

## What the scaffold generates

`--multi-tenant` copies `overlays/<stack>-multi-tenant` over the base template:

| File | Change |
| --- | --- |
| `libs/ddd/domain/valueobjects/TenantId` | new value object, validated (`^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`), else `TenantIdInvalidError` (400, `TENANT_ID.INVALID`) |
| `UseCaseContext(correlationId, tenantId, requestedAt)` | the tenant is part of every use case context |
| `BaseCommand` / `BaseQuery` | `getTenantId()` |
| `BaseCommandHandler` / `BaseQueryHandler` | log `[tenant: ...] [correlation: ...]` |
| `BaseEvent` | carries `tenantId`; `toUseCaseContext()` keeps it for the next slice |
| `RestBaseController` | `generateUseCaseContext(String tenantId)` |
| health check | `GET /{tenantId}/<module>/health`, with tests for tenant propagation and invalid tenants |
| `UseCaseContextBuilder` | `withTenantId(...)`, plus `DEFAULT_TENANT_ID` (`tenant-a`) and `OTHER_TENANT_ID` (`tenant-b`) |

## The rules

1. **The tenant is resolved once, at the driving adapter**, then only travels inside `UseCaseContext`. HTTP controllers take it from the path. Event controllers take it from the event (`event.toUseCaseContext()`). Handlers and domain code never read it from a header, thread-local, or static.
2. **Every tenant-owned aggregate is scoped by tenant.** Either the entity has a `TenantId tenantId` field, or every port method takes a `TenantId`. Pick one style per project and use it everywhere.
3. **Every read and write filters by tenant.** No `findById(id)` without the tenant. A record from another tenant is reported as *not found* (404), never as forbidden, so ids don't leak between tenants.
4. **Every event carries the tenant** (inherited from `BaseEvent`), and consumers rebuild the context from it.
5. **Tenant isolation is tested** in unit tests (in-memory adapters must filter too) and in E2E tests (the SQL must filter).
6. **Global data is explicit.** Reference data shared by all tenants (currencies, countries) lives in tables without `tenant_id` and ports without `TenantId`, and is named so it's obviously global.
7. **Tenant-specific configuration** (limits, feature flags, settings) is loaded through a port (`TenantSettingsPort`), not scattered `if (tenant == ...)` checks. A switch on tenant is a code smell (G23). Use a strategy per setting.

## Slice templates (tenant-aware)

```java
@RestController
@RequestMapping("/{tenantId}/order")
public class CancelOrderRestController extends RestBaseController {
    // constructor ...

    @PostMapping("/orders/{orderId}/cancellation")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    Mono<Void> cancelOrder(@PathVariable String tenantId, @PathVariable String orderId) {
        return this.cancelOrderCommandHandler.handle(new CancelOrderCommand(
                this.generateUseCaseContext(tenantId),
                orderId));
    }
}
```

```java
@Override
protected Mono<Void> execute(CancelOrderCommand command) {
    return this.orderRepository.findById(command.getTenantId(), new EntityId(command.getOrderId()))
            .map(OrderEntity::cancel)
            .flatMap(order -> this.orderRepository.update(order)
                    .then(this.sendOrderCancelledEvent(command.getContext(), order)));
}
```

```java
public interface OrderRepositoryPort {
    Mono<OrderEntity> findById(TenantId tenantId, EntityId id);   // OrderNotFoundError when absent in this tenant
    Flux<OrderEntity> findAllByStatus(TenantId tenantId, OrderStatusEnum status);
    Mono<Void> create(OrderEntity order);                          // the entity carries its TenantId
    Mono<Void> update(OrderEntity order);
}
```

Commands and queries don't need their own tenant field, because `getTenantId()` comes from the context.

## Persistence

- Every tenant-owned table has `tenant_id VARCHAR(64) NOT NULL`, and the primary key or unique constraints include it when business keys are only unique within a tenant (`UNIQUE (tenant_id, order_number)`).
- Index `tenant_id` first in composite indexes (`(tenant_id, status)`), since every query filters on it.
- The ORM row maps `tenant_id` to and from `TenantId`. SQL always has `WHERE tenant_id = :tenantId`.

```java
@Query("SELECT * FROM customer_order WHERE tenant_id = :tenantId AND id = :id")
Mono<OrderOrmEntity> findByTenantIdAndId(String tenantId, String id);
```

```java
public class OrderInMemoryRepository implements OrderRepositoryPort {
    private final Map<EntityId, OrderEntity> savedEntities = new ConcurrentHashMap<>();

    @Override
    public Mono<OrderEntity> findById(TenantId tenantId, EntityId id) {
        return Mono.justOrEmpty(this.savedEntities.get(id))
                .filter(order -> order.getTenantId().equals(tenantId))
                .switchIfEmpty(Mono.error(new OrderNotFoundError()));
    }
    // ...
}
```

Stronger isolation options are schema-per-tenant or database-per-tenant, where a `ConnectionFactory` is routed by tenant. Only choose them when a requirement demands it (regulation, very large tenants), and keep them inside `infrastructure/`. The ports stay the same.

## Events

`BaseEvent` already carries `tenantId`. Event controllers must build the next context with `event.toUseCaseContext()`, never with a new or default tenant. When events leave the service through a broker, put the tenant in the payload or a message header, and restore it in the consuming adapter.

## Tests

- `UseCaseContextBuilder.builder().withTenantId(OTHER_TENANT_ID).build()` for the other side of an isolation test.
- Every slice that reads data gets at least one isolation test:

```java
@Test
void shouldNotFindAnOrderOfAnotherTenant() {
    // Given
    var order = OrderBuilder.builder(this.orderRepository).withTenantId(OTHER_TENANT_ID).build();
    var query = new GetOrderByIdQuery(UseCaseContextBuilder.builder().build(), order.getId().getValue());

    // When, Then
    StepVerifier.create(this.handler.handleMono(query))
            .expectError(OrderNotFoundError.class)
            .verify();
}
```

- Every command that publishes events asserts the event's `getTenantId()`.
- The E2E suite repeats one isolation test through the real database adapter.
- REST contract tests cover an invalid tenant id (400 `TENANT_ID.INVALID`), which the generated health-check test shows.

## Where the tenant comes from

The scaffold takes it from the first path segment, which is explicit and easy to test. Alternatives are a header (`X-Tenant-Id`) or a JWT claim. With those:
- Resolve it in the driving adapter only (a `@RequestHeader`, or the authenticated principal), and pass it to `generateUseCaseContext(tenantId)`.
- With authentication, **the tenant must come from the verified token**, or be checked against it. Never trust a client-supplied tenant id alone.

## Converting a single-tenant project

Do it test-first, one step at a time:
1. Add `TenantId` and `TenantIdInvalidError`, then extend `UseCaseContext`, `BaseEvent`, `BaseCommand`, `BaseQuery`, the handlers' logging, `RestBaseController` and `UseCaseContextBuilder` as in the overlay.
2. Fix the compilation errors, which shows every place that creates a context.
3. For each aggregate, write the isolation test first. Then add `tenantId` to the entity or the port, the in-memory filter, the column plus migration, and the SQL filter.
4. Move routes under `/{tenantId}/...` and update the REST contract tests.
