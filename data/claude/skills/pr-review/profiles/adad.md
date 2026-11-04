# Profile: MnC-Aero ADAD platform

**Applies when:** the `origin` remote is `github.com/MnC-Aero/*` (adad-frontend, adad-api, Java modules
such as accounting / etl / matching / kpi / audit-track / integration-factory…), or Java packages
start with `io.adad`. Do **not** load it for other repos (including other GitLab projects).

Project facts and project-only rules learned from the ADAD review history. They complement the
generic files in `references/`; IDs like `ADAD-JAV-n` point back to related generic rules.

## Platform
- Base branch `develop` (PRs into `main`/`master` are releases; `fix/*` branches target staging).
- Jira tickets `ADAD-<n>`. Branches `feature/ADAD-<n>` / `fix/ADAD-<n>`; commits start with `[ADAD-<n>]`
  (or `ADAD-<n>`) and the ticket matches the branch.
- Stacks: Java 17/21 + Spring Boot 3 WebFlux modules with DDD layering and shared code in `adad-core`;
  adad-api = NestJS 10 + TypeORM + Postgres (DDD/CQRS); adad-frontend = Angular 15 + PrimeNG 13 + RxJS 7
  (Jasmine/Karma).
- Pre-commit hooks run Prettier / ESLint (`no-explicit-any`, `no-non-null-assertion`, explicit return
  types in adad-api).
- Multi-tenant: config, SSM parameters, seeds and Helm values exist per tenant and per environment.
- Most frequent single request in the Java repos: bump the version in `pom.xml` of every changed
  plugin/lib (and not of untouched ones).
- Keycloak roles live in the keycloak-cli project; a new endpoint needs its role created there.

## Java modules
- Stack: MnC-Aero ADAD Java 17 modules (Spring Boot 3.3 WebFlux/Reactor, DDD, ports/adapters, ORM + InMemory repos, integration-factory plugins); audit-track runs Java 21. Default branch for PRs: `develop`; tickets `ADAD-n`.
- Packages: `io.adad.modules.<module>.{domain,commands,queries,usecases,ports(.dto),adapters|infrastructure,database,services,errors}`; `domain/{entities,valueobjects,events}`; ORM under `database.<entity>`; test builders `.builders`; use-case package = lowercase use-case name.
- Shared libs: `io.adad.adadcore.libs.*` (older `io.adad.libs.*`) and `io.adad.domain.valueobjects` (`ULID`, `GenericId`, `NanoId`, `MonetaryAmount`, `Currency`, `StatDate`, `DateVO`). Search there and sibling modules before adding a class (`Strings.isEmpty/notEmpty/toMd5`, `Objects`, `Dates`, `JsonSerializer`, `ReportField/ReportItem`, `EventWithExtendedFields`, `ItemFilterUtils`, `ReportMarkedAsFailed`, `ErrorMessage`, `KpiCalculationUtils`).
- Base classes: `BaseUseCase<Cmd>` (`execute`), `BaseCommandHandler`/`BaseQueryHandler` (both already log), `TenantBaseCommand`, `ReportBaseCommand`, `TenantBaseEvent`/`BaseEvent`, `RestBaseController`, `BaseEntity<ULID|GenericId>`, `BaseOrmEntity` (created/updated date), `EventController<E>`, `AbstractBuilder` (`this.orElse(field, default)`).
- Time: `InstantPort`/`instants`/`DatesPort` (tests `FakeDates`); never `Instant.now()`/`Clock`; DB `OffsetDateTime` -> `.toInstant()`. StatDate = midnight UTC instant, derived from the entity created date.
- Exceptions (module `errors` package): `NotFoundException`, `ArgumentInvalidException`, `ArgumentNotProvidedException`, `ConflictException`, `UnProcessableEntityException`, `NotImplementedException`; code format `RESOURCE.REASON` equal to the front-end code; seeded in canned messages/migration; REST tests assert `ErrorMessage(error, httpCode, status)`.
- Events: `Message.create(event,"name"[, PUBLISH_SUBSCRIBE])`/`createInternal`/`createDelayed`; senders expose `dispatchEvent`, `persistedDispatchEvent`, `notifyInternally`; broadcast to matching, kpi, featurization, audit-track; queue `Consumer.<module>.VirtualTopic.<event_name>`; accounting registers events in the `AccountingEvent` enum; reuse `sendAccountingEvent`, `RefreshKpis`; AsyncAPI pages are the contract; never `KPI`/`Redis` in event names.
- Reactive/Spring: `ReactiveAdadLogger` (`getLogger().info(context, ...)`), `TenantContext.withTenantId` in `contextWrite`, `TransactionalOperator`, `R2dbcEntityTemplate`+`Criteria`, `@ReactiveCacheEvict` on tenant-settings setters, `@Value("${adad.<area>.<name-kebab>}")`, repositories `createAll/saveAll/deleteAllByIds`, `@Repository("kpi_SettlementRepository")` unique names across modules.
- Naming: `XxxRepositoryPort`, `XxxOrmRepositoryImpl`, `XxxInMemoryRepository`, `XxxOrmEntity`, `XxxEventSenderPort`, `XxxEventListener`, `XxxBuilder extends AbstractBuilder`; tests `XxxUnitTests`, `XxxIntegrationTest`, `XxxE2ETests`, `XxxRestControllerTests`; routes `/{tenantId}/<module>/<kebab-plural>`; `MonetaryAmountResponse`; errors like `MarketNotFound`.
- Tests: `AsyncUnitTests`, per-module `IntegrationTest`, `StepVerifier`, Faker, `FakeDates`, `listenToEvent/listenToMultipleEvents`, tenant constant `TENANT`, `buildWithoutPersisting`+`createAll`, `waitAtMostFor`.
- Style: shared formatter `adad_style.xml`; member order static constants, fields, constructors (`@PostConstruct` first), public, protected, private; alphabetical lists for `JournalEntryMetadataFieldEnum`, `HeaderEnum`, `FeedDataFieldEnum`, `ItemHistoryTitle`, metadata puts; `Strings.toMd5/isEmpty`.
- Vocabulary: accounting vs transaction/payment/settlement currency; molecule; discrepancy (not "difference"); "associated" (not "linked"); `CARD_BIN` not `CC_BIN`.
- Spec of record: Confluence specs, per-acquirer ICD, event-stream/AsyncAPI pages; known gaps go in Jira links, not TODOs; module/plugin/adad-core `pom.xml` version bumped on change.
- Nullable legacy columns (JAV-12): accounting/payment/settlement currency, reconciliation/effective/treated dates, discount, withholding, chargeback, confirmed/discrepancy amounts, country, marketId, installment counts. Never-null (JAV-14): matched sale reconciliation date, accounting date, status, currency of computed discrepancy, `createdDate`, payment-order amounts.
- Money specifics (JAV-15): `getSaleGrossAmount().getPaymentCurrency()`; accounting amount not replaced by global/transaction amount; KPI in accounting currency; payment discrepancy with null payment-currency amount; ORM via `toMonetaryAmount`; shared rounding service (exceptional-currency fraction digits).
- Cache/misc: tenant-settings caches evicted via `@ReactiveCacheEvict`; enum added only to validate where the API gateway is source of truth is rejected; near-identical use cases (Amex/ROE/HOT) combined.
- **ADAD-JAV-1 Installment vs normal, provisional vs confirmed settlements stay separate** — Blocker · ~70 comments
  Check: installment logic mixed into normal-settlement code (use strategy classes and separate tests); difference and accounting adjustment not recalculated together; molecule updated more than once; first-installment dates not updated; installment acquirer not mapping isInstallment/count/first amount.
- **ADAD-JAV-2 Accounting `Match*Command` conventions (accounting-module)** — Major · ~110 comments
  Check: metadata `put` keys alphabetical; non-overridden getters `private`; no dead fields; event name/type not hard-coded in metadata (service sets them); `transactionDate` per event rule (sealing, reconciliation, settlement, deletion date, now); command-specific defaults inside the command.
- **ADAD-JAV-3 Scripts/ETL loaders, audit-track feed items, reports** — Major · ~200 comments
  Check: scripts dispatched via `ScriptTypeEnum` strategy (default throws `ScriptProcessorCanNotBeDetected`); loaders throw+log on missing/invalid data; audit-track items built with `ItemHistoryFeedItemWrapperFactory`/`FeedItemContentFactory`; human text from canned messages (`getMessageEn()`); `FeedDataFieldEnum`/`ItemHistoryTitle` alphabetical, abbreviated, dictionary updated, existing values reused; feed map uses `.getValue()` on ULIDs/currencies/enums, null-safe; no double `WHERE`; report name/user from `ExtractDataCommand`, `.csv` constant, failed report marked failed, columns per spec; ETL/bank-only concerns not in kpi.
- **ADAD-JAV-4 Plugin amounts, signs, scale, currency, dates** — Blocker · ~150 comments
  Check: `BigDecimal` parsed straight from `String` (never float/double or guessed `setScale`/`HALF_UP` — core rounds, max DB scale 3); raw amounts kept as `String` in Record, converted in `CreateXSettlements`; scale from currency fraction digits; one `changeAmountSignBasedOnTransactionType` helper (refund/chargeback negative per signing-logic page; `signum()`, `abs().negate()`); null amount AND currency checked before `MonetaryAmount.ofNonConvertedMonetaryAmount`; `io.adad.domain.valueobjects.Currency` not `java.util.Currency`; dates `ZoneId.UTC`, Excel `asInstant()`.
- **ADAD-JAV-5 Plugin class responsibilities and singleton safety** — Major · ~200 comments
  Check: field-derived logic (transaction type, cc bin/last four, amounts, fop code, dates) in `Record` getters, `CreateXSettlements` only maps, parser only parses; static `Map.of` lookup with `getOrDefault(key, TransactionType.NA)`; no trim (BeanIO trims); `@DocumentParser`/`@SettlementCreator` classes hold no mutable state (per-file data in FileRecord); no overriding of defaults (`isEligible...`, `getRecordClass`, `detectFileContext`); sanity check via handler/factory; plugin-common interfaces (`TransactionType`, `Transaction<>`); parsers: missing fields stay `null`, `logger.warn(msg,e)`, throw the plugin functional error so the file is marked corrupted.
- **ADAD-JAV-6 Plugin change checklist** — Major · ~140 comments
  Check: plugin version bumped in pom; `DatasourceName` equals DB datasource name (case matters for queues) and `Detect*FileContext` exists (file-name regex, version, header); BeanIO xml updated for new fields; universal fields mapped (alternateFormOfPaymentCode, installments if supported, settlement/payment/transaction dates, document number); transaction type validated against ICD and eligibility checked after mapping; transaction vs payment-order vs miscellaneous-fee split by `AtomType`; fingerprint excludes line/sequence number and uses stronger hash than MD5; universal fields added to `GenericAbstract*` DTO base and never removed.
- **ADAD-JAV-7 Plugin tests** — Major · ~90 comments
  Check: `CreateXSettlements` unit tests cover every mapped field; sanity-check tests cover each error code and the fingerprint; integration test asserts record count (`expectNextCount(N)`) and type != NA; e2e per new universal field; perf (1000-tx file < 1000 ms) and duplicate-run tests; no assumed "USD".

## Angular frontend (adad-frontend)
Stack: Angular 15, PrimeNG 13 + PrimeFlex, RxJS 7.8, Jasmine/Karma. No NgRx, no i18n lib (hard-coded English); state = component fields + service observables. Until April 2025 (ADAD-8610) the app was an Nx monorepo under `libs/web/...`; old review comments refer to that layout, always apply the current `src/app/modules` layout. Acceptance is checked against the Jira ticket, low-fi screenshots and the API spec (swagger/Jira).
- Layout: one Angular module per feature in `src/app/modules/<feature>/{components,pages,models,services,pipes}` with `<feature>.module.ts`; each feature has a path alias `@<feature>/*` in `tsconfig.json` (new feature -> add the alias, keep list alphabetical). Page-level views in `pages/`, reusable pieces in `components/`; folder names plural.
- File naming: models `models/<kebab>/<kebab>.model.ts` + `.spec.ts`; DTOs `<name>-dto.model.ts` (+ spec); enums `<name>.enum.ts` (one enum per directory); pipes `pipes/<name>/<name>.pipe.ts`; services `services/<name>/`. File/folder name == class name in kebab-case; selector `adad-frontend-<name>`; `.component.ts` not `-component.ts`.
- Import aliases (cross-module imports never `../../..`): `@core/...` (permission, keycloak-handler, `models/error-http`, `models/app-settings`, guards, interceptors; security/errors/config only, not feature services); `@shared-gui/...` (generic UI: table, `toast-handler`, `confirm-dialog-handler`, dialog handler, spinner, error displayer, status tags, export button, `utils/mock-pipe` = `MockPipeFactory`); `@shared-ui/...` (business-shared: `models/monetary-amount`, shared dropdown filters for acquirers/FOP/sale sources/airlines/markets/transaction types, `utils/date-formatter`, `utils/search-list-request`, `has-*-query-changed` and `is-*-eligible-*` pipes, cross-feature services like markets/airlines/search-filters-storage); `@<feature>/...` for feature code. Before suggesting a new filter/pipe/component, `ls src/app/modules/shared-ui` and `shared-gui`.
- Shared pipes: `formatAmountByCurrency`, `formatMonetaryAmount`, `timezoneOffsetDate`, `deduceTitleCaseFromCamelCaseAndPascalCase`, `hasXFilterChanged` (+ `hasStringQueryChanged`, `hasPrimitiveTypedQueryChanged`), `Deduce<X>ColumnsPipe` (columns by permission/context).
- State conventions: `listX`, `isLoadingListX`, `errorMessage`, `loadListX()`, `xFilter` + `xFilterHistory` (export/load-more use history), `afterId` pagination, `setActionsByPermissions()`, `toastKey`/`confirmDialogKey`, `initMocks()` in specs.
- Backend contract: resources plural, endpoints `/v1/...`, newer version in `apiPathV2`, DTO fields match the API spec; error codes `RESOURCE.REASON` mapped in core. Dates: `DD/MM/YYYYTHH:mm:ss` for effective dates, ISO strings elsewhere (follow the spec).
- Quality gates: husky pre-commit (prettier/lint) must not be bypassed; Prettier line width 150; Sonar rules (no `switch` under 3 cases, no `style` attr, no clickable `li`). Branch named `feature/ADAD-NNNN`. Workflow files: readable step names, upper-case env names.
- Alphabetical ordering is mandatory (~900 comments, the single most repeated remark): imports, injected services, methods (public first), `@Input`/`@Output` and model attributes + constructor assignments (inputs before outputs; `id` first only for entities), HTML attributes (`[(ngModel)]` counts), module declarations/imports/providers/routes, enum values, switch cases, role enums, error-code maps and tests, spec `let` variables (after `component`/`fixture`), TestBed providers/declarations/mock pipes, `initMocks` lines, mock-service methods, `createSpyObj` lists, request-param assertions. HTML attribute order: structural directive first, others alphabetical, `(event)` last. Lifecycle order `ngOnInit`, `ngOnChanges`, `ngOnDestroy`.
- Test labels: root `describe` == exact class name; suites start uppercase (`When ...`, `Handle loading ... successfully`), never `should`; `it` starts lowercase `should ...` ("should x and y", not "should x and should y"); service spec suites named like the method ("Get X", "Change X"). Mock pipes via `MockPipeFactory({ name })` only for pipes used in the template.
- Not flagged in ADAD: i18n keys, NgRx, `trackBy`, exact PrimeFlex spacing values.

### ADAD-only rules
**ADAD-FE-1 Error handling via core `ErrorHttp`** — Major · ~50 comments
Check: errors typed `ErrorHttp`, branch on `error.statusCode`; new codes in `BAD_REQUEST_CODES_<RESOURCE>_MAP` in `bad-request-codes-<resource>` files (one per resource, alphabetical, with tests); not-found/conflict maps registered in `ErrorHttpHandlerInterceptor`.

**ADAD-FE-2 Permissions wiring** — Blocker · ~105 comments
Check: new role enum value per new page/action (key == value, singular, `-page` suffix for pages) present in keycloak-cli/role docs and `app-routing.module.ts`; actions hidden via `*adadFrontendHasPermission` or permission pipe; `setActionsByPermissions()` private, called in `ngOnInit`, spec uses `mockPermissionService`; `CoreModule` imported when the directive is used.

**ADAD-FE-3 Shared pieces to reuse** — Major · ~100 comments
Check: `adad-frontend-table` (not raw `<table>`), `TruncateListTextComponent`, `adad-frontend-text-shortener` + `adad-frontend-clipboard-copy-button`, inplace editor, spinner, tag, export button, acquirer/sale-source/FOP dropdown filters; pure UI in `shared/gui`, models/services in `shared/ui`, exported from `index.ts`; `ToastHandlerService`, `ConfirmDialogHandlerService`, `DialogHandlerService`, `PermissionService`, `KeycloakHandlerService`; every `toastKey` has a matching `<adad-frontend-toast>`.

**ADAD-FE-4 Filter wiring names** — Major · ~130 comments
Check: `hasXFilterChanged` pipe (+ spec), `prepareXFiltersForExtraction` built from `xFilterHistory`, `afterId` load-more disabled via pipe tied to history; all contexts sharing the list (sales, settlements, deleted variants, audit track).

**ADAD-FE-5 State and display conventions** — Minor · ~110 comments
Check: loading/error naming `isLoadingListX`/`errorMessage`; empty value `-`; amounts via `formatAmountByCurrency`/`formatMonetaryAmount` + `text-right`; dates via `timezoneOffsetDate` / `dd/MM/yyyy`; percent via `percent` pipe; `Deduce<X>ColumnsPipe`/`Has*FilterChangedPipe` for column/filter logic; plain columns `*ngSwitchDefault` with `{{ x[column.property] || '-' }}`; required inputs `[class.ng-dirty]` while empty (as in ChartAccountsComponent); `optionLabel/optionValue`; `styleClass` for PrimeFlex on PrimeNG; PrimeNG events typed.

**ADAD-FE-6 CSS naming and styling** — Major · ~350 comments
Check: root class = component name PascalCase without `Component` (`SalesList`), children `Root-Child` (`Toolbar-UserDropMenu`); dialog/toast `styleClass` = component name; `toastKey`/`confirmDialogKey` = `<ComponentName>Toast`/`<ComponentName>ConfirmDialog`; PrimeFlex classes instead of new SCSS; no global `.p-datatable`/`.p-progress-spinner` styling, use `GuiTable-*`/`GuiSpinner`; rules under `.Root ::ng-deep .Child`.

**ADAD-FE-7 Naming specifics** — Minor · ~150 comments
Check: lists `listXxxs`; template refs end in `Tmpl`; no `Adad` prefix in class names; DTO extends front model and calls `super`; delete columns hidden in create mode; action columns 5-10% width; default filters per ticket; `private readonly UPPER_SNAKE` constants; no French.

**ADAD-FE-8 Copy conventions** — Minor · ~140 comments
Check: toasts "Sale deleted successfully.", "X alert accept failed."; confirm "Are you sure that you want to ...?"; placeholder "Select a FOP type"; acquirer vs customer wording; compare against low-fi screenshots.

**ADAD-FE-9 Test mocks** — Minor · ~90 comments
Check: `jasmine.createSpyObj('ExactServiceName', [...])` as `mockXxxService`; `MockPipeFactory`; `CUSTOM_ELEMENTS_SCHEMA` (drop `NO_ERRORS_SCHEMA`); `setActionsByPermissions()` suite with `mockPermissionService`; `initMocks()`.

## NestJS API (adad-api)

Profile fragment for MnC-Aero's adad-api; use together with `typescript-backend.md` (TS-nn). Counts from ~3,300 review comments.

### Facts
- Stack: NestJS/TypeScript, DDD-ish + CQRS (command-handlers, query-handlers), in-memory repositories/gateways for unit specs, Jest `*.spec.ts`, BDD e2e (`*.feature` + `*.e2e-spec.ts`) with json-server mocks (`tests/server-mocks`).
- Layout: `src/modules/<module>/{commands,queries,domain,database,adapters,ports,errors,event-handlers,integration-events}`; each use case folder has `*.command|query.ts`, `*-handler.ts`, `*.http.controller.ts`, `*.request.dto.ts`, `*.response.dto.ts`, `*.spec.ts`; wiring in `<module>.module.ts`, `<module>.providers.ts`, `<module>.routes.ts`; shared kernel `src/libs/ddd` (value-objects, ports/dtos, base repositories) and `src/libs/exceptions`.
- Aliases: `@modules/...`, `@libs/...` (TS-34).
- Helpers to reuse: `Guard.isEmpty`, `DateVO` (`now`, `isBefore`, `isStrictlyBefore`, `addDays`), `ULID`, `UUID`, `Result` (`@libs/ddd/domain/utils/result.util`), `RestHttpRequestsService`, `TenantId()`/`User()` + `AuthenticatedUser`, `MonetaryAmountResponse`, `RateOfExchangeResponse`, `MonetaryAmountDTO` (`@libs/ddd/domain/ports/dtos/monetary-amount.dto`), `RateOfExchangeDTO`, `removeEmptyProps`, `FakeDateService` (`setNowTo`), `DatePort`/`DateService`, module `*ConfigPort` (`getBaseUrl(tenantId)`).
- Test infra: `*InMemoryFactory`/`*InMemoryGateway`/`*InMemoryUnitOfWork`, `forceError(ErrorType.X)`, builders in `tests/<module>/*.builder.ts` (e.g. `FeeRuleBuilder`), e2e in `tests/<module>/`, mocks `tests/server-mocks/{resources,routes}.json`.
- Conventions: use cases `<Verb><Entity>`; `@Roles({ roles: ['realm:<domain>-<get|manage>', '<entity-plural>-<action>'] })`; error `msg = 'ENTITY.ERROR_CODE'`; terms "datasource" (one word), "sale source", "acquirer"; status enums ACTIVE/INACTIVE.
- Ops: roles live in the separate keycloak-cli project; env vars in `.env.example` and helm `api-chart/values-*.yaml` (dev/uat/prod, per tenant).
- Process: confirm contracts with ETL/matching/accounting/KPI teams (confluence/jira pages cited) before merging gateway changes; squash/rebase, no unrelated renames.

### ADAD-only rules
- ADAD-API-1 (major, ~55, maps TS-13): Roles use `realm:<domain>-get|manage` plus a granular `<entity-plural>-<action>` role (`['realm:atom-get','failed-transactions-list']`); the granular role must exist in keycloak-cli before merge; spec user role must match. Check: `'sales-get'` on deleted-sale endpoint -> `'deleted-sales-get'`.
- ADAD-API-2 (major, ~30, maps TS-07): HTTP gateways use `RestHttpRequestsService` (no raw axios), URL from `getBaseUrl(tenantId)`, send `command.getUsername()` not `getRawProps().username`, spread `...command.parameters`.
- ADAD-API-3 (nit, ~140, maps TS-34): imports via `@modules/`/`@libs/`, no `../..`; run lint/prettier.
- ADAD-API-4 (nit-minor, ~40, maps TS-22): DTO class suffix uppercase `DTO` (`AcquirerDTO`); files `*.dto.ts`, `*.request.dto.ts`, `*.response.dto.ts` (sonar coverage exclusion uses `**/*.dto.ts`); port/gateway DTOs use plain `string`, not VOs.
- ADAD-API-5 (minor, ~45, maps TS-27/TS-43): error file `entity-reason.error.ts`, class `EntityReasonError`, `static readonly msg = 'ENTITY.ERROR_CODE'` (UPPER_SNAKE after the dot, no dots in the code part: `'SALE.INVALID_PAGINATION_FIELDS'`); in-memory gateway `ErrorType` entries end with `Error`, one per gateway method, used via `forceError(ErrorType.X)`; new `ErrorType` added with each new failure test.
- ADAD-API-6 (major, ~15, maps TS-38): `DateVO` helpers not `new Date()`; domain services inject `DatePort`/`DateService`; tests use `FakeDateService.setNowTo`.
- ADAD-API-7 (minor, ~18, maps TS-23/TS-02): reuse `Guard.isEmpty`, `ULID`, `MonetaryAmount*`/`RateOfExchange*` from `@libs/ddd/...`; shared VOs (e.g. ReferenceId) go to `libs/ddd/domain/value-objects` when used by 2 modules; call `validateX` as `if (!Guard.isEmpty(x)) this.validateX(x)`.
- ADAD-API-8 (major, ~12, maps TS-08): adding an event type also updates `messaging.service.ts`/queue-name mapping; domain event keeps `ULID[]`, integration event `string[]`; enum values snake_case, alphabetical.
- ADAD-API-9 (major, ~20, maps TS-32): new env/SSM value goes in `.env.example`, helm values per tenant for dev/uat/prod, and e2e env; e.g. `accountingYearStart` was duplicated.
- ADAD-API-10 (major-minor, ~120, maps TS-44/TS-45): e2e = one `manage-<entity>.feature` + `.e2e-spec.ts` per resource under `tests/<module>/`; steps "I request ... / I get ..."; token `adadAdmin` vs airline user per ticket; GET endpoints use json-server mocks, observable POSTs use an e2e gateway; mocks in `tests/server-mocks/resources.json` and `routes.json`, camelCase resource keys, kebab-case routes, specific before `:id`.
- ADAD-API-11 (nit-minor, ~36, maps TS-46): update `jest.all.config.js` thresholds (unit and e2e); do not commit `package-lock.json` changes (lockfileVersion 2, npm 7+), `.github/workflows` branch tweaks, ssl/datasource tweaks in `tenancy.service.ts`.
- ADAD-API-12 (minor, ~40, maps TS-12): `@ApiTags('<Resource In Title Case>')` matches the entity and sibling endpoints; tenant/KPI settings have their own tag.
- ADAD-API-13 (major, ~22, maps TS-16): `@Param('xxxId') id`, `@TenantId()`, `@User() user: AuthenticatedUser`; never hand-build `AuthenticatedUser`; no `deletedBy`/`userId`/`acquirerId` from the body.
- ADAD-API-14 (major, ~8, maps TS-04/TS-05): Operation and AcquirerMarket are not aggregate roots (no repository); reuse the ETL/KPI/matching/accounting module gateways (`<Module>ModuleGateway`, e.g. `acquirerEtlModule`).
- ADAD-API-15 (nit, ~60, maps TS-37): domain spelling fixes (`Aquirer`, `Salessource`, `Tymee`), `datasource` one word, `fileId` for File id, `creationDate` vs `fileReceptionDate`.
- ADAD-API-16 (minor, ~14, maps TS-31): ORM entities: no `@VersionColumn` unless real optimistic version; `version` is auto-managed, never set in entity create.

## Config, SQL, build

Facts (ADAD / MnC-Aero)
- Migrations: TypeORM `.ts` files with raw SQL; run by filename timestamp; class name = `Name<timestamp>`, file name matches, no spaces or `(...)`.
- Mirror tables: sale/deleted_sale, settlement/deleted_settlement, failed_* tables, molecule + deleted/failed molecule tables, bank_deposit/failed_bank_deposit.
- Column sizes: ULID `varchar(26)`, UUID `varchar(36)`, currency `varchar(3)`, DEBIT/CREDIT `varchar(6)`; money values as `jsonb`; amount default 0, eligibility default TRUE; indexes `USING BTREE`.
- Dates stored in UTC across tenants. Team convention: no constraints on columns.
- Standard columns on new tables: `version`, `metadata`, `created_date`, `updated_date`.
- Heavy backfills go to the batch-migration project.
- Seed files: `seed*.sql`, `db-clean-up.sql`; test schema `init_tables_and_types.sql`; cleanup in IntegrationTest base class. Seeds must match plugin/code/Confluence values (datasources like REDEVD/REDEVC, event reference ids, FOP ids).
- Maven: plugins released independently per module; shared libs adad-core, plugins-common, hash-calculator, fx-rate-converter, monetary rounding; libs not to bump unless changed: beanio-lib, csv-lib, excel-lib, parents. Java 21 for ETL/enrichment, 17 where stated. Version property style `<io.adad.core.version>`.
- Config: properties prefix `adad.<module>.<kebab-case>`; files `application.properties`, `application-local.properties`, `application-integration-test.properties`; flags `features.x.enabled=false`, local value `OTHER`; infra params in adad-deployment/helm; SSM parameter CSVs per tenant and env (dev, staging, prod); Helm port 8080.
- CI: `.github/workflows/main.yml`, tag `$IMAGE_TAG`, deploy on `develop` or `v*-release`.
- Docs: Confluence (tables, roles docs); AsyncAPI for events.
- Keycloak: `keycloak-cli` `changelog-N.json`; realm roles adad-admin/super-admin (full), airline-user (read-only).
- Test API repo: adad-test-api (Cypress/BDD).

Rules
- ADAD-CFG-1 (major): `.attach_pid*`, `hs_err_pid*.log`, `qq:q!`/`wq`/`credentials` files, `package-lock.json` (unless intended) must not be committed; add to `.gitignore`. Check: PR file list for these names.
- ADAD-CFG-2 (major): BeanIO XML mappings (~25 comments): repeating records are lists (not `maxOccurs=1`), `ignoreUnidentifiedRecords=false`, drop unused fields/records/regex/setters, use shared amount handlers (`AbstractCommonLongTypeHandler`), sequential field order, update matching ICD version. Check: diff of mapping XML.
- ADAD-CFG-3 (major): Keycloak roles (~74 comments): `resource-plural-verb` (`sales-list` GET all, `-get` by id, `-update`, `-delete`); front roles action-first per roles doc; assign to adad-admin/super-admin and airline-user (read-only); update Confluence roles doc. Check: new `changelog-N.json`, N next free, one per PR.
- ADAD-CFG-4 (minor): SSM CSVs: use different cron frequencies per tenant/job; pick one of `business-days` / `is-business-days`; do not copy wrong tenant names. Check: all tenants x envs updated.
- ADAD-CFG-5 (major): Plugin pom bump: breaking change (new plugins-common, universal fields) = major/minor bump; plugin must not depend on another plugin; module/package names lowercase; register new plugin in parent `pom.xml`; shared plugins-common change in its own PR. Check: pom diff per changed plugin.
- ADAD-CFG-6 (major): Seeds: keep tenant-minimal (e.g. "won't be used by AY"); canned messages in English matching `TransactionOnHoldDetected` error codes in failed-transaction view; add rule contents per accounting rule (positive/negative net). Check: seed diff vs tenant scope.
- ADAD-CFG-7 (minor): Test API: use `cy.api` not `cy.request`; PascalCase classes, lowerCamel methods, lowercase-dash folders; no `Create...`/`API...` class prefixes; main-branch env URLs (8x staging) stay working. Check: spec files.
- ADAD-CFG-8 (minor): KPI tables: e.g. `kpi_bank_stats`, `datasource_id` style names; trace-only values (e.g. `source_file_name`) in `metadata`. Check: migration column list.
- ADAD-CFG-9 (minor): Sonar: do not exclude files, fix the issue; snakeyaml: override property rather than exclude. Check: pom/sonar properties.

