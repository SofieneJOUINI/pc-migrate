package {{BASE_PACKAGE}}.libs.ddd.events;

import {{BASE_PACKAGE}}.libs.ddd.domain.events.BaseEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import reactor.core.publisher.Mono;

public abstract class EventController<E extends BaseEvent> {
    private final Logger logger = LoggerFactory.getLogger(this.getClass());
    private final Class<E> eventClass;
    private final String eventName;

    protected EventController(Class<E> eventClass, String eventName) {
        this.eventClass = eventClass;
        this.eventName = eventName;
    }

    @EventListener
    public void onDispatchedEvent(DispatchedEvent dispatchedEvent) {
        if (!this.isWatched(dispatchedEvent)) return;
        this.handle(this.eventClass.cast(dispatchedEvent.event()))
                .subscribe(null, error -> this.logger.error("Failed handling event [{}]", this.eventName, error));
    }

    public Mono<Void> handle(E event) {
        return Mono.defer(() -> this.execute(event));
    }

    protected abstract Mono<Void> execute(E event);

    public String getEventName() {
        return eventName;
    }

    private boolean isWatched(DispatchedEvent dispatchedEvent) {
        return this.eventName.equals(dispatchedEvent.eventName()) && this.eventClass.isInstance(dispatchedEvent.event());
    }
}
