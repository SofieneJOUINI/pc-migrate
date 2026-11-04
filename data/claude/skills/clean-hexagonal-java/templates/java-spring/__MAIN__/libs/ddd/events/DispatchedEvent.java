package {{BASE_PACKAGE}}.libs.ddd.events;

import {{BASE_PACKAGE}}.libs.ddd.domain.events.BaseEvent;

public record DispatchedEvent(String eventName, BaseEvent event) {
}
