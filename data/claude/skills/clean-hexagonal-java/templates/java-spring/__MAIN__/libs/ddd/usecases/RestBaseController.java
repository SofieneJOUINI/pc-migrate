package {{BASE_PACKAGE}}.libs.ddd.usecases;

import {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects.UseCaseContext;

import java.time.Instant;

public abstract class RestBaseController {

    protected UseCaseContext generateUseCaseContext() {
        return UseCaseContext.create(Instant.now());
    }
}
