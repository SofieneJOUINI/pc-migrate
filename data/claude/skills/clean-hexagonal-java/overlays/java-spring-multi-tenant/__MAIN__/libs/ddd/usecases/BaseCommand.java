package {{BASE_PACKAGE}}.libs.ddd.usecases;

import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.EntityId;
import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.TenantId;
import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.UseCaseContext;

import java.util.Objects;

public abstract class BaseCommand {
    private final UseCaseContext context;

    protected BaseCommand(UseCaseContext context) {
        this.context = Objects.requireNonNull(context, "A command needs a context");
    }

    public UseCaseContext getContext() {
        return context;
    }

    public EntityId getCorrelationId() {
        return context.correlationId();
    }

    public TenantId getTenantId() {
        return context.tenantId();
    }
}
