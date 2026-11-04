package {{BASE_PACKAGE}}.libs.ddd.events;

import {{BASE_PACKAGE}}.libs.ddd.domain.events.BaseEvent;
import reactor.core.publisher.Mono;

public interface EventDispatcherPort {
    Mono<Void> dispatch(String eventName, BaseEvent event);
}
