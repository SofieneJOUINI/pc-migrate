# {{PROJECT_NAME}}

TODO: one paragraph describing the business capability this service owns.

## Architecture

Hexagonal (ports & adapters) with CQRS slices:

```
src/main/java/{{BASE_PACKAGE_PATH}}/
├── infrastructure/            technical concerns (health check, postgres, dates...)
├── libs/                      kernel: base commands/queries/handlers, events, errors
└── modules/{{MODULE_PACKAGE}}/
    ├── commands/<slice>/      write use cases: Command, CommandHandler, Rest/Event controller
    ├── queries/<slice>/       read use cases: Query, QueryHandler, Response, RestController
    ├── domain/                entities, value objects, events (plain Java)
    ├── ports/                 interfaces the core needs from the outside world
    ├── adapters/              event sender, clients, locks (+ in-memory twins)
    ├── database/<aggregate>/  R2DBC ORM entities, repositories (+ in-memory twins)
    ├── services/              domain services shared by several slices
    └── errors/                typed errors with stable codes
```

{{TENANCY}}

## Build & test

```bash
mvn test -Dtest='!ContainersTest'   # fast feedback, no Docker needed
mvn verify                          # everything, incl. Testcontainers E2E tests + JaCoCo report
```

## Run locally

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=local
curl http://localhost:{{PORT}}{{HEALTH_EXAMPLE_PATH}}
```

## Endpoints

| Method | Path | Slice |
| --- | --- | --- |
| GET | `{{HEALTH_PATH}}` | `infrastructure/healthcheck` |

## Events

| Direction | Name | Payload |
| --- | --- | --- |
| | | |
