package {{BASE_PACKAGE}}.modules;

import net.datafaker.Faker;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Objects;

public abstract class AbstractBuilder {
    public static final String NULL_VALUE = "NULL";
    protected static final Faker FAKER = new Faker();

    public <T> T orElse(T value, T defaultValue) {
        if (Objects.isNull(value)) return defaultValue;
        return this.isNullValueRequired(value) ? null : value;
    }

    public <T> boolean isNullValueRequired(T value) {
        return NULL_VALUE.equals(value);
    }

    public Instant instantWithSecondPrecision(Instant instant) {
        return instant.atOffset(ZoneOffset.UTC).withNano(0).toInstant();
    }
}
