package {{BASE_PACKAGE}}.modules.{{MODULE_PACKAGE}}.adapters;

import {{BASE_PACKAGE}}.libs.ddd.events.EventDispatcherPort;
import org.springframework.stereotype.Component;

@Component
public class EventSender {
    private final EventDispatcherPort eventDispatcher;

    public EventSender(EventDispatcherPort eventDispatcher) {
        this.eventDispatcher = eventDispatcher;
    }
}
