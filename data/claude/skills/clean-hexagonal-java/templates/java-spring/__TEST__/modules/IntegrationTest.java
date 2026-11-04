package {{BASE_PACKAGE}}.modules;

import {{BASE_PACKAGE}}.{{APP_CLASS}};
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.reactive.AutoConfigureWebTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.r2dbc.core.DatabaseClient;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.TestPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.List;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        classes = {{APP_CLASS}}.class)
@AutoConfigureWebTestClient
@TestPropertySource(locations = "classpath:application-integration-test.properties")
@ActiveProfiles("integration-test")
public abstract class IntegrationTest implements HumanReadableTest {
    private static final List<String> TABLES_TO_CLEAN = List.of();

    public static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>(DockerImageName.parse("postgres:16-alpine"))
            .withDatabaseName("{{DB_NAME}}")
            .withUsername("postgres")
            .withPassword("postgres")
            .withInitScript("scripts/init_tables_and_types.sql");

    @Autowired
    private DatabaseClient databaseClient;

    @DynamicPropertySource
    static void containersProperties(DynamicPropertyRegistry registry) {
        postgres.start();
        registry.add("spring.r2dbc.url", () -> "r2dbc:postgresql://%s:%s/%s"
                .formatted(postgres.getHost(), postgres.getFirstMappedPort(), postgres.getDatabaseName()));
        registry.add("spring.r2dbc.username", postgres::getUsername);
        registry.add("spring.r2dbc.password", postgres::getPassword);
    }

    @BeforeEach
    void cleanUp() {
        this.cleanUpPostgresDB().block();
    }

    private Mono<Void> cleanUpPostgresDB() {
        return Flux.fromIterable(TABLES_TO_CLEAN)
                .concatMap(table -> this.databaseClient.sql("DELETE FROM " + table).then())
                .then();
    }
}
