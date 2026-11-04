package {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects;

import java.time.Instant;
import java.util.Objects;

public record UseCaseContext(EntityId correlationId, TenantId tenantId, Instant requestedAt) {

    public UseCaseContext {
        Objects.requireNonNull(correlationId, "correlationId is required");
        Objects.requireNonNull(tenantId, "tenantId is required");
        Objects.requireNonNull(requestedAt, "requestedAt is required");
    }

    public static UseCaseContext create(TenantId tenantId, Instant requestedAt) {
        return new UseCaseContext(EntityId.generate(), tenantId, requestedAt);
    }
}
