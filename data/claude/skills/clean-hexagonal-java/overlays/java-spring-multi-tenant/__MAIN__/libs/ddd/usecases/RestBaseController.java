package {{BASE_PACKAGE}}.libs.ddd.usecases;

import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.TenantId;
import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.UseCaseContext;

import java.time.Instant;

public abstract class RestBaseController {

    protected UseCaseContext generateUseCaseContext(String tenantId) {
        return UseCaseContext.create(new TenantId(tenantId), Instant.now());
    }
}
