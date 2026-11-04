package {{BASE_PACKAGE}}.libs.ddd.usecases;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import reactor.core.publisher.Mono;

public abstract class BaseCommandHandler<C extends BaseCommand> {
    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    public Mono<Void> handle(C command) {
        return Mono.defer(() -> this.execute(command))
                .doOnSubscribe(subscription -> this.logger.info("Handling [{}] [tenant: {}] [correlation: {}]",
                        command.getClass().getSimpleName(), command.getTenantId().getValue(),
                        command.getCorrelationId().getValue()))
                .doOnError(error -> this.logger.error("Failed handling [{}] [tenant: {}] [correlation: {}]",
                        command.getClass().getSimpleName(), command.getTenantId().getValue(),
                        command.getCorrelationId().getValue(), error));
    }

    protected abstract Mono<Void> execute(C command);
}
