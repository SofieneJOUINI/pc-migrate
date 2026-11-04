package {{BASE_PACKAGE}}.infrastructure.events;

import {{BASE_PACKAGE}}.libs.ddd.domain.events.BaseEvent;
import {{BASE_PACKAGE}}.libs.ddd.events.DispatchedEvent;
import {{BASE_PACKAGE}}.libs.ddd.events.EventDispatcherPort;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;
import reactor.core.publisher.Mono;

/**
 * In-process dispatcher: events only reach EventControllers of this service.
 * Replace with a broker adapter (AMQP, Kafka...) implementing the same port when events must cross service boundaries.
 */
@Component
public class SpringEventDispatcher implements EventDispatcherPort {
    private final ApplicationEventPublisher applicationEventPublisher;

    public SpringEventDispatcher(ApplicationEventPublisher applicationEventPublisher) {
        this.applicationEventPublisher = applicationEventPublisher;
    }

    @Override
    public Mono<Void> dispatch(String eventName, BaseEvent event) {
        return Mono.fromRunnable(() -> this.applicationEventPublisher.publishEvent(new DispatchedEvent(eventName, event)));
    }
}
