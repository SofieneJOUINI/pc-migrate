package {{BASE_PACKAGE}}.infrastructure.healthcheck;

import {{BASE_PACKAGE}}.modules.HumanReadableTest;
import {{BASE_PACKAGE}}.modules.{{MODULE_PACKAGE}}.builders.UseCaseContextBuilder;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class GetHealthInformationUnitTests implements HumanReadableTest {
    private static final String VERSION = "1.2.3";

    private GetHealthInformationQueryHandler getHealthInformationQueryHandler;

    @BeforeEach
    void setup() {
        this.getHealthInformationQueryHandler = new GetHealthInformationQueryHandler(VERSION);
    }

    @Test
    void shouldReportTheServiceAsUpWithItsVersion() {
        // Given
        var query = new GetHealthInformationQuery(UseCaseContextBuilder.builder().build());

        // When
        var healthInformation = this.getHealthInformationQueryHandler.handleMono(query).block();

        // Then
        assertThat(healthInformation).isEqualTo(new GetHealthInformationResponse("UP", VERSION));
    }
}
