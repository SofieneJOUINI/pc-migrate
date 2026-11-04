package {{BASE_PACKAGE}}.infrastructure.healthcheck;

import {{BASE_PACKAGE}}.libs.exceptions.NotFoundException;
import {{BASE_PACKAGE}}.modules.HumanReadableTest;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.reactive.WebFluxTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.reactive.server.WebTestClient;
import reactor.core.publisher.Mono;

import static org.mockito.Mockito.when;

@WebFluxTest(GetHealthInformationRestController.class)
class GetHealthInformationRestControllerTests implements HumanReadableTest {
    private static final String PATH = "/{{MODULE_KEBAB}}/health";

    @MockBean
    private GetHealthInformationQueryHandler getHealthInformationQueryHandler;
    @Autowired
    private WebTestClient webClient;

    @Test
    void shouldReturnTheHealthInformation() {
        // Given
        when(this.getHealthInformationQueryHandler.handleMono(Mockito.any()))
                .thenReturn(Mono.just(new GetHealthInformationResponse("UP", "1.2.3")));

        // When, Then
        this.webClient.get().uri(PATH)
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.status").isEqualTo("UP")
                .jsonPath("$.version").isEqualTo("1.2.3");
    }

    @Test
    void shouldTranslateDomainErrorsIntoTheirHttpStatusAndCode() {
        // Given
        when(this.getHealthInformationQueryHandler.handleMono(Mockito.any()))
                .thenReturn(Mono.error(new NotFoundException("HEALTH.NOT_FOUND")));

        // When, Then
        this.webClient.get().uri(PATH)
                .exchange()
                .expectStatus().isEqualTo(HttpStatus.NOT_FOUND)
                .expectBody()
                .jsonPath("$.code").isEqualTo(404)
                .jsonPath("$.message").isEqualTo("HEALTH.NOT_FOUND");
    }
}
