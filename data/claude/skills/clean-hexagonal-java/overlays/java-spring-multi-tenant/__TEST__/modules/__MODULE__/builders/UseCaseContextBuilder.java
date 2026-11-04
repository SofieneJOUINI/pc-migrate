package {{BASE_PACKAGE}}.modules.{{MODULE_PACKAGE}}.builders;

import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.EntityId;
import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.TenantId;
import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.UseCaseContext;
import {{BASE_PACKAGE}}.modules.AbstractBuilder;

import java.time.Instant;

public class UseCaseContextBuilder extends AbstractBuilder {
    public static final TenantId DEFAULT_TENANT_ID = new TenantId("tenant-a");
    public static final TenantId OTHER_TENANT_ID = new TenantId("tenant-b");

    private EntityId correlationId;
    private TenantId tenantId;
    private Instant requestedAt;

    private UseCaseContextBuilder() {
    }

    public static UseCaseContextBuilder builder() {
        return new UseCaseContextBuilder();
    }

    public UseCaseContextBuilder withCorrelationId(EntityId correlationId) {
        this.correlationId = correlationId;
        return this;
    }

    public UseCaseContextBuilder withTenantId(TenantId tenantId) {
        this.tenantId = tenantId;
        return this;
    }

    public UseCaseContextBuilder withRequestedAt(Instant requestedAt) {
        this.requestedAt = requestedAt;
        return this;
    }

    public UseCaseContext build() {
        return new UseCaseContext(
                this.orElse(this.correlationId, EntityId.generate()),
                this.orElse(this.tenantId, DEFAULT_TENANT_ID),
                this.orElse(this.requestedAt, Instant.now()));
    }
}
