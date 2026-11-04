package {{BASE_PACKAGE}}.infrastructure.events;

import {{BASE_PACKAGE}}.libs.ddd.domain.events.BaseEvent;
import {{BASE_PACKAGE}}.libs.ddd.events.DispatchedEvent;
import {{BASE_PACKAGE}}.libs.ddd.events.EventDispatcherPort;
import reactor.core.publisher.Mono;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

public class InMemoryEventDispatcher implements EventDispatcherPort {
    private final List<DispatchedEvent> dispatchedEvents = new CopyOnWriteArrayList<>();

    @Override
    public Mono<Void> dispatch(String eventName, BaseEvent event) {
        return Mono.fromRunnable(() -> this.dispatchedEvents.add(new DispatchedEvent(eventName, event)));
    }

    public <E extends BaseEvent> List<E> getDispatchedEvents(String eventName, Class<E> eventClass) {
        return this.dispatchedEvents.stream()
                .filter(dispatchedEvent -> dispatchedEvent.eventName().equals(eventName))
                .map(DispatchedEvent::event)
                .map(eventClass::cast)
                .toList();
    }

    public List<DispatchedEvent> getAllDispatchedEvents() {
        return List.copyOf(this.dispatchedEvents);
    }
}
