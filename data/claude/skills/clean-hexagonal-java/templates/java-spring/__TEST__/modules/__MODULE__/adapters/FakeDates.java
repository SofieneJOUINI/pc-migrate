package {{BASE_PACKAGE}}.modules.{{MODULE_PACKAGE}}.adapters;

import {{BASE_PACKAGE}}.libs.ddd.ports.DatesPort;

import java.time.Instant;

public class FakeDates implements DatesPort {
    private Instant currentDate = Instant.parse("2024-01-01T00:00:00Z");

    @Override
    public Instant now() {
        return this.currentDate;
    }

    public FakeDates setCurrentDate(Instant currentDate) {
        this.currentDate = currentDate;
        return this;
    }
}
