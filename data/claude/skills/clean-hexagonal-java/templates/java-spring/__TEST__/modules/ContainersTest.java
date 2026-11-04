package {{BASE_PACKAGE}}.modules;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ContainersTest extends IntegrationTest {

    @Test
    void postgresContainerShouldBeUp() {
        assertThat(postgres.isRunning()).isTrue();
        assertThat(postgres.getFirstMappedPort()).isNotNull();
    }
}
