package {{BASE_PACKAGE}}.libs.ddd.domain.valueobjects;

import {{BASE_PACKAGE}}.libs.exceptions.EntityIdInvalidError;

import java.util.UUID;

public record EntityId(String value) {

    public EntityId {
        if (value == null || value.isBlank()) throw new EntityIdInvalidError();
    }

    public static EntityId generate() {
        return new EntityId(UUID.randomUUID().toString());
    }

    public String getValue() {
        return value;
    }
}
