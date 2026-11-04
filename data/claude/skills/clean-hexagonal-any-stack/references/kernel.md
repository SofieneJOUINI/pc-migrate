# Kernel contract (language-neutral)

The kernel lives in `libs/`. It's the most stable and most abstract part of the codebase, and holds no business vocabulary. Implement it test-first in the chosen language, using that language's idioms (see `stacks.md`). The pseudo-code below defines **behavior**, not syntax. `async T` means the stack's async type (`Promise<T>`, `Task<T>`, coroutine, `Mono<T>`, or a plain return in Go).

Build only what the first slice needs, and add the rest when a test asks for it.

## Contents
- Value objects: EntityId, UseCaseContext
- Entity
- Domain event
- Command, Query, handlers
- Errors and HTTP mapping
- Ports: DatesPort, IdGeneratorPort
- Events: EventDispatcherPort, dispatchers, event handlers
- Multi-tenant variant
- Kernel tests to write first

## Value objects

```
value EntityId(value: string)
    invariant: value is not blank                 else EntityIdInvalidError  (INVALID_ARGUMENT, "ENTITY_ID.INVALID")
    equality: by value

value UseCaseContext(correlationId: EntityId, requestedAt: Instant)
    invariant: both present
    create(requestedAt, idGenerator) -> UseCaseContext(idGenerator.next(), requestedAt)
```

Rules for every value object: immutable, validates itself when constructed, equality by value, no setters. Use the language's native construct (TS `class` with `readonly` + private constructor + `static create`, Python `@dataclass(frozen=True)`, Go struct with a `New...` constructor returning `(T, error)`, C#/Kotlin `record`/`data class`, Rust newtype + `TryFrom`).

## Entity

```
abstract Entity<Id>
    id: Id                                         required, immutable
    equality: same concrete type and same id
```

Entities hold behavior (`order.cancel()`), are created in a valid state, and change state only through intention-revealing methods. Prefer returning a new instance, or keep the mutation private to the entity. Never use public setters.

## Domain event

```
abstract DomainEvent
    eventId: EntityId                              generated
    correlationId: EntityId                        copied from the context
    occurredAt: Instant                            copied from the context
    constructor(context: UseCaseContext)
    toUseCaseContext() -> UseCaseContext(correlationId, occurredAt)

concrete events: EVENT_NAME constant in snake_case ("order_placed") + the ids and values consumers need
```

## Command, Query, handlers

```
abstract Command(context: UseCaseContext)        getContext(), getCorrelationId()
abstract Query(context: UseCaseContext)          same

abstract CommandHandler<C extends Command>
    handle(command) -> async void
        log "Handling <CommandName> [correlation: id]"
        run execute(command)
        on error: log "Failed handling <CommandName> [correlation: id]" with the error, then re-raise it unchanged
    protected abstract execute(command) -> async void

abstract QueryHandler<Q extends Query, R>
    handle(query) -> async R                     (or a stream/list variant)
        on error: log a warning with the correlation id, then re-raise it
    protected abstract execute(query) -> async R
```

This is the Template Method pattern: cross-cutting behavior (logging, metrics, transactions) lives once in `handle`, and business orchestration lives in `execute`. In languages without inheritance (Go, Rust), use a generic wrapper or decorator instead: `WithLogging(handler) Handler`.

## Errors and HTTP mapping

```
abstract AppError(code: string)                   code is stable, UPPER.SNAKE, dotted: "ORDER.NOT_FOUND"
    category: INVALID_ARGUMENT | NOT_FOUND | CONFLICT | UNPROCESSABLE

InvalidArgumentError  extends AppError  category INVALID_ARGUMENT  -> HTTP 400
NotFoundError         extends AppError  category NOT_FOUND         -> HTTP 404
ConflictError         extends AppError  category CONFLICT          -> HTTP 409
UnprocessableError    extends AppError  category UNPROCESSABLE     -> HTTP 422
anything else                                                       -> HTTP 500, generic message, full error logged

module errors: class OrderNotFoundError extends NotFoundError { code = "ORDER.NOT_FOUND" }

HTTP error body: { "code": <http status number>, "message": <error code> }
```

A **single error mapper** at the HTTP edge applies this table (an exception filter, middleware, or exception handler). Controllers never build error responses themselves. In Go/Rust, return typed errors, check them with `errors.As` or `match` in the mapper, and wrap them for context without losing the type.

## Ports

```
port DatesPort          now() -> Instant
port IdGeneratorPort    next() -> EntityId          (optional; EntityId.generate() is fine if tests never assert on ids)
```

The real implementations (`SystemDates`, `UuidGenerator`) live in `infrastructure/`. The fakes (`FakeDates` with a settable current date, `SequentialIdGenerator`) live in the test support folder.

## Events

```
port EventDispatcherPort
    dispatch(eventName: string, event: DomainEvent) -> async void

InMemoryEventDispatcher implements EventDispatcherPort         (tests)
    records every (eventName, event)
    dispatched(eventName, type) -> list of events with that name
    all() -> list

InProcessEventDispatcher implements EventDispatcherPort        (production, single service)
    delivers to every registered EventHandler whose eventName matches
    a failing handler is logged, and doesn't break the other handlers or the publisher

abstract EventHandler<E extends DomainEvent>                   (driving adapter, lives in the slice folder)
    eventName: string
    handle(event: E) -> async void                             builds a command with event.toUseCaseContext()

EventSender implements <X>EventSenderPort, <Y>EventSenderPort   (module adapter)
    sendXxx(event) -> dispatcher.dispatch(Xxx.EVENT_NAME, event)
```

When another service consumes the events, add a broker dispatcher (Kafka, RabbitMQ, SQS, NATS...) implementing the same port, plus an outbox table if the event must never be lost after a commit. Handlers and senders don't change.

## Multi-tenant variant

Only for multi-tenant projects (see `multi-tenancy.md`):

```
value TenantId(value)            invariant: matches ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$  else TenantIdInvalidError (INVALID_ARGUMENT, "TENANT_ID.INVALID")
UseCaseContext(correlationId, tenantId, requestedAt)
Command / Query                  + getTenantId()
DomainEvent                      + tenantId, kept by toUseCaseContext()
handler logs                     "[tenant: t] [correlation: id]"
HTTP adapter helper              contextFor(rawTenantId) -> UseCaseContext.create(TenantId(rawTenantId), clock.now())
```

## Kernel tests to write first

1. `EntityId` rejects a blank value with `ENTITY_ID.INVALID`, and two ids with the same value are equal.
2. A command handler re-raises the error from `execute` unchanged, and logs with the correlation id.
3. The error mapper turns each category into its status and `{code, message}` body, and turns an unknown error into a 500 without leaking its message.
4. `InMemoryEventDispatcher` returns the dispatched events by name.
5. The in-process dispatcher delivers to matching handlers only, and one failing handler doesn't stop the others.
6. (multi-tenant) `TenantId` rejects invalid values, and events carry the tenant into `toUseCaseContext()`.
