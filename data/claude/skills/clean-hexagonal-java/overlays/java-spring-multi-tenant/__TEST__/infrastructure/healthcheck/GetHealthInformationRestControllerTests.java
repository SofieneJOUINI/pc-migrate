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

import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@WebFluxTest(GetHealthInformationRestController.class)
class GetHealthInformationRestControllerTests implements HumanReadableTest {
    private static final String PATH = "/{tenantId}/{{MODULE_KEBAB}}/health";
    private static final String TENANT = "tenant-a";

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
        this.webClient.get().uri(PATH, TENANT)
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.status").isEqualTo("UP")
                .jsonPath("$.version").isEqualTo("1.2.3");
    }

    @Test
    void shouldPassTheTenantFromThePathToTheQuery() {
        // Given
        when(this.getHealthInformationQueryHandler.handleMono(Mockito.any()))
                .thenReturn(Mono.just(new GetHealthInformationResponse("UP", "1.2.3")));

        // When
        this.webClient.get().uri(PATH, TENANT).exchange().expectStatus().isOk();

        // Then
        verify(this.getHealthInformationQueryHandler).handleMono(Mockito.argThat(
                query -> query.getTenantId().getValue().equals(TENANT)));
    }

    @Test
    void shouldRejectAnInvalidTenantId() {
        // When, Then
        this.webClient.get().uri(PATH, "bad$tenant")
                .exchange()
                .expectStatus().isEqualTo(HttpStatus.BAD_REQUEST)
                .expectBody()
                .jsonPath("$.message").isEqualTo("TENANT_ID.INVALID");
        verify(this.getHealthInformationQueryHandler, never()).handleMono(Mockito.any());
    }

    @Test
    void shouldTranslateDomainErrorsIntoTheirHttpStatusAndCode() {
        // Given
        when(this.getHealthInformationQueryHandler.handleMono(Mockito.any()))
                .thenReturn(Mono.error(new NotFoundException("HEALTH.NOT_FOUND")));

        // When, Then
        this.webClient.get().uri(PATH, TENANT)
                .exchange()
                .expectStatus().isEqualTo(HttpStatus.NOT_FOUND)
                .expectBody()
                .jsonPath("$.code").isEqualTo(404)
                .jsonPath("$.message").isEqualTo("HEALTH.NOT_FOUND");
    }
}
