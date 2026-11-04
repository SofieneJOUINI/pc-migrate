package {{BASE_PACKAGE}}.infrastructure.dates;

import {{BASE_PACKAGE}}.libs.ddd.ports.DatesPort;
import org.springframework.stereotype.Component;

import java.time.Instant;

@Component
public class SystemDates implements DatesPort {

    @Override
    public Instant now() {
        return Instant.now();
    }
}
