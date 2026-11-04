package {{BASE_PACKAGE}}.modules.{{MODULE_PACKAGE}}.builders;

import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.EntityId;
import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.UseCaseContext;
import {{BASE_PACKAGE}}.modules.AbstractBuilder;

import java.time.Instant;

public class UseCaseContextBuilder extends AbstractBuilder {
    private EntityId correlationId;
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

    public UseCaseContextBuilder withRequestedAt(Instant requestedAt) {
        this.requestedAt = requestedAt;
        return this;
    }

    public UseCaseContext build() {
        return new UseCaseContext(
                this.orElse(this.correlationId, EntityId.generate()),
                this.orElse(this.requestedAt, Instant.now()));
    }
}
