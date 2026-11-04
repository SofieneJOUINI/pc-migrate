package {{BASE_PACKAGE}}.libs.ddd.usecases;

import org.reactivestreams.Publisher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

public abstract class BaseQueryHandler<Q extends BaseQuery, R> {
    private final Logger logger = LoggerFactory.getLogger(this.getClass());

    public Mono<R> handleMono(Q query) {
        return Mono.defer(() -> Mono.from(this.execute(query)))
                .doOnError(error -> this.logFailure(query, error));
    }

    public Flux<R> handleFlux(Q query) {
        return Flux.defer(() -> this.execute(query))
                .doOnError(error -> this.logFailure(query, error));
    }

    protected abstract Publisher<R> execute(Q query);

    private void logFailure(Q query, Throwable error) {
        this.logger.warn("Failed handling [{}] [correlation: {}]",
                query.getClass().getSimpleName(), query.getCorrelationId().getValue(), error);
    }
}
