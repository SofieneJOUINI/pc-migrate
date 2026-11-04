package {{BASE_PACKAGE}}.libs.ddd.domain.events;

import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.EntityId;
import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.TenantId;
import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.UseCaseContext;

import java.time.Instant;

public abstract class BaseEvent {
    private final EntityId eventId;
    private final EntityId correlationId;
    private final TenantId tenantId;
    private final Instant occurredAt;

    protected BaseEvent(UseCaseContext context) {
        this.eventId = EntityId.generate();
        this.correlationId = context.correlationId();
        this.tenantId = context.tenantId();
        this.occurredAt = context.requestedAt();
    }

    public UseCaseContext toUseCaseContext() {
        return new UseCaseContext(this.correlationId, this.tenantId, this.occurredAt);
    }

    public EntityId getEventId() {
        return eventId;
    }

    public EntityId getCorrelationId() {
        return correlationId;
    }

    public TenantId getTenantId() {
        return tenantId;
    }

    public Instant getOccurredAt() {
        return occurredAt;
    }
}
