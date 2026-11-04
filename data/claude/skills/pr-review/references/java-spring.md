# Java / Spring — review rules
Scope: generic rules for Java 17+ / Spring (Boot) code, with conditional sections for Reactor/WebFlux, DDD/hexagonal layering and in-memory test doubles. Source: ~11.7k real review comments (2022–2026) from one large Spring/WebFlux/DDD codebase, merged and deduplicated; counts are approximate sums and indicate how often reviewers raised a rule. Use: scan the diff against each rule's "Check"; report only what the diff actually shows, cite the JAV id, and prefer Blocker/Major findings over Nit. A rule marked "If the project uses X" applies only when the reviewed repo does; never impose a convention the repo lacks. If a repo-specific profile is loaded (see `profiles/`), its facts and rules complement these.

## Discover in the repo before reviewing
Look these up first (read sibling code, base classes, existing tests) so findings use the repo's own conventions instead of generic guesses:
- Shared kernel / common lib: where utilities, value objects, ids, money, string/date helpers, JSON helpers, error types live; search it and sibling modules before suggesting a new class (JAV-23).
- Base classes: use case / command / query handlers, controllers, entities, ORM entities, events, builders; what they already do (logging, transactions, tenant context) so duplicates can be flagged.
- Error model: exception hierarchy, naming (`<Resource><Reason>Error`?), error-code format and where codes are catalogued or seeded, how errors map to HTTP status.
- Clock and id ports: how "now" and ids are obtained (clock port, fake clock in tests, id generator); is `Instant.now()` banned?
- Event dispatch API: broadcast vs point-to-point vs in-process vs persisted/transactional dispatch; queue/topic naming; event base class; async-API/contract docs.
- Reactive stack: Reactor/WebFlux or blocking MVC; transaction operator vs `@Transactional`; reactive logger/context propagation (tenant, correlation id).
- Persistence: ORM/R2DBC/JPA/JDBC template, migration tool, query style (derived queries, Criteria, hand SQL), pagination idiom, caches and eviction annotations.
- Test setup: base test classes, integration-test base, builders/object mothers, fake data generator, in-memory doubles of ports, assertion style (StepVerifier, AssertJ), event-listening helpers, tenant/user constants.
- Layering: package structure (domain / use cases / ports / adapters / infrastructure), whether domain is Spring-free, where DTOs and errors live.
- Naming suffixes and formatter: `*Port`, `*Impl`, `*Handler`, `*Listener`, `*Builder`, test class suffixes, route style, formatter config file, member-order and import conventions.
- Spec of record: where requirements/contracts live (wiki, ICD, API/event specs); known gaps are linked tickets, not TODOs.

## Rules
### Reactive correctness (if the project uses Reactor/WebFlux)
**JAV-01 A Mono/Flux that is not returned or subscribed must not exist; chain validations into the returned pipeline** — Blocker · ~30 comments
Check: a `checkX(...)`/`validate(...)`/`send...` returning `Mono` called as a statement; `Mono<Void>` flattened inside `flatMap` (never fires, use `.then`); events/commands built eagerly instead of inside `Mono.defer`.
Why: the work silently never executes.
```java
// flagged
validate(cmd);                       // Mono ignored
return repo.save(order);
// expected
return validate(cmd).then(Mono.defer(() -> repo.save(order)));
```
**JAV-02 Order side effects deliberately: persist first, then send events, log, release locks last** — Major · ~70 comments
Check: events/commands sent before the DB write completes; "finished/handled" event not last; lock release not the final step; marking something done before what it depends on (create the ledger before marking entries); detach event before attach event; one private `sendXEvent` method per send, inside `.then(Mono.defer(...))`.
Why: consumers see state that is not yet persisted; locks leak or release early.
**JAV-03 Independent work in `Mono.when`/`Mono.zip`; dependent work in `.then` at the same level** — Major · ~85 comments
Check: sequential `.then`/`flatMap` on independent updates or event sends; `Mono.when` used on steps that must be ordered; `tuple.getT1()/getT2()` instead of named locals.
Why: latency, and correctness when ordering matters.
**JAV-04 No blocking or materialising in reactive code** — Major · ~45 comments
Check: `.block()`; `collectList()` to test emptiness or just to count (use `hasElements`, `switchIfEmpty`, repository `count`); blocking IO (SFTP, files) without `subscribeOn(Schedulers.boundedElastic())`; try/catch around a reactive chain instead of `onError*`; non-reactive in-memory fakes.
Why: event-loop starvation and memory pressure.
**JAV-05 Drop needless reactive plumbing; do not use Mono for sync work** — Minor · ~80 comments
Check: trailing `.then()` after `Mono<Void>`, `.then(Mono.empty())`, `switchIfEmpty(Mono.empty()/Flux.empty())`, `.flatMap(Mono::just)`, `Mono.defer` around an already lazy call (keep it where siblings defer sends), `flatMapMany`+`then`, `collectList` before `Flux.fromIterable`, `then(Mono.just(x))` (use `thenReturn`); sync/pure validation method returning `Mono` (make it `void`/throw); `Mono` passed as a parameter (flatMap at the caller).
Why: noise hides the real flow; Mono return types promise IO that is not there.
**JAV-06 `flatMap` unless order matters; batch bulk work** — Major · ~25 comments
Check: `concatMap` without an ordering reason; per-row save/delete in a loop instead of `saveAll`/`deleteAllById`-style bulk calls with `buffer(BATCH_SIZE)` (constant or configured property, e.g. 100); independent queries not merged with `Flux.merge`.
Why: throughput and memory.
**JAV-07 `onErrorResume`/`catch` must target a specific exception and never swallow** — Major · ~15 comments
Check: `onErrorResume(t -> ...)` without class; `catch (Exception e){ return null; }`; handler placed outside the method owning the failure; a write inside `onErrorResume` without its own transaction scope; catch-and-rethrow of the same error.
Why: hidden failures and half-committed state.

### Transactions
**JAV-08 Atomic multi-write work runs in one transaction, proven by an integration test** — Blocker · ~55 comments
Check: use case with several writes (create+history, delete+insert-into-deleted, status+totals, ledger+marking) without a transaction opened at the start of the use case (reactive: transactional operator; imperative: `@Transactional` on the use-case entry point); `@Transactional` on a private/self-invoked method (the proxy is bypassed, needs another Spring bean), on event listeners or non-proxied calls, or on a bulk `saveAll`; no rollback integration test; event handler not inside the transaction that marks the event as treated.
Why: partial writes in prod; `@Transactional` silently not applied.

### Events and messaging
**JAV-09 Pick the dispatch mode by who consumes the event** — Blocker · ~185 comments
Check: another module/service consumes it -> broadcast (publish-subscribe) dispatch; one consumer or heavy work -> point-to-point dispatch (an in-process notification puts all the load on one instance in a multi-pod deployment); in-process notification only for light local work or test-only listeners; events tied to a transaction use the dispatcher's persisted/transactional dispatch (outbox style); no persisted events nobody reads.
Why: wrong delivery semantics, load imbalance, lost events.
**JAV-10 Event, queue, sender and listener names and registration must agree** — Major · ~60 comments
Check: queue/topic name follows the repo scheme; event name (snake_case or repo style) equals the sender method; listener named after and typed with the same event; a newly consumed event has all its registration (event enum/registry entry, sender port method, replay/dead-letter queue) and a postponed/replayed-event test; lifecycle words (`...Completed`, not `...Finished`), no technology (`Redis`) or foreign-module prefix in names; async-API/contract docs updated when the payload changes.
Why: messages land on the wrong queue or are never consumed.
**JAV-11 Events are minimal, contract-true payloads** — Major · ~40 comments
Check: extends the shared event base; only needed fields (no file names, duplicated ids); id types follow the sender/contract (a `String` if the producer sends strings; value objects converted only at serialization); `@JsonCreator`+`@JsonProperty` where deserialization needs them; `equals/hashCode` consistent; no `toString`; names match the documented contract.
Why: serialization breaks across modules.

### Nullability and optionals (largest bug class)
**JAV-12 Null-guard every nullable DB/legacy value before dereferencing** — Blocker · ~400 comments
Check: new `.getX().getY()`/`.toInstant()`/`.getValue()`/entity mapping on columns that are nullable in old rows (currencies, dates, discounts, optional amounts, country, counts added by later migrations); non-constant-first `equals`; boxed `Boolean` compared with `==`/auto-unboxed; hand-written `!= null && !isEmpty()` instead of the shared null-safe `isEmpty` helper. Zero is a value, not null.
Why: NPE in prod on legacy data.
```java
// flagged
currency.getValue();  deniedCode.equals("N")
// expected
Optional.ofNullable(currency).map(Currency::getValue).orElse(null);
"N".equals(deniedCode);  Boolean.TRUE.equals(flag)
```
**JAV-13 Expose nullable getters as `Optional`/empty collections; never `Optional` as field/parameter; never pass `null` args** — Major · ~80 comments
Check: `Optional` as field/parameter; `Optional.of(maybeNull)`; `new Invoice(a, null, null)` (add overload/factory/`empty()`); returning `null` where Optional, empty collection or error fits.
Why: null contracts become invisible.
**JAV-14 Do not add null handling for values that cannot be null** — Minor · ~60 comments
Check: `Optional.ofNullable`/null checks on values enforced by a builder/constructor/not-null column, computed values, or status/date fields always set at creation; fail fast instead.
Why: dead branches mislead readers.

### Money, dates, domain correctness
**JAV-15 Keep money in an amount value object; derive currency/rate from it; pick the right currency per event** — Blocker · ~130 comments
Check: parallel `Currency`/`BigDecimal` fields beside an amount VO (read the currency from the amount); a multi-currency amount replaced by a single global one (keep each currency's amount); alerts/KPIs compare `abs(difference)` to the threshold, in the reporting currency; optional exchange rate defaults to `BigDecimal.ONE`; difference computed while one side's currency amount is null; rounding before scaling (x100); ORM-to-VO mapping through the VO factory.
Why: wrong ledger/KPI amounts.
**JAV-16 BigDecimal arithmetic and rounding** — Major · ~30 comments
Check: results of `add/subtract` discarded (immutable); `compareTo(ZERO)==0`/`equals` with scale mismatch (use `signum()`, `compareTo`, `isEqualByComparingTo`, or `stripTrailingZeros` first); rounding done ad hoc instead of the project's rounding service (currency fraction digits, exceptional currencies); amount VOs mutable or accepting null.
Why: scale-sensitive equality bugs.
**JAV-17 Time comes from a clock port; dates use UTC and explicit rules** — Major · ~70 comments
Check: `Instant.now()`/`Clock`/`ZonedDateTime.now()`/`ZoneId.systemDefault()` or `now()` cached at class init (inject the clock port, use `ZoneId.UTC`, a fake clock in tests); "business date" values not normalised the way the project defines (e.g. midnight UTC) or derived from today instead of the entity's date; date range not validated both-or-none/ordered; month as a fixed 30 days; exclusive bounds where inclusive specified.
Why: off-by-one-hour/day and wrong stats.
**JAV-18 Logic must match the referenced spec; check cross-module impact** — Blocker · ~110 comments
Check: statuses, fields, flows differing from the linked spec/contract; a changed task type, event, enum, table or API response with no thought for the other consumers (other services, front end, jobs, old data); module/library version not bumped when the repo versions modules; removed or renamed API-facing fields/ids still used by clients or legacy data (keep with `@Deprecated(since, forRemoval)`).
Why: silent contract breaks across modules and tenants.

### Domain model and DDD (if the project uses DDD/hexagonal layering)
**JAV-19 Business rules live in the entity/VO/domain service, not in handlers, repositories, ORM entities or constructor params** — Major · ~150 comments
Check: status, counts, `isCredit()/isDebit()`, `isConfirmed`, eligibility computed in a use case, query handler, ORM class or passed as ctor args (compute in the entity); separate `accept()`/`dispute()`/`resolve()` instead of status params; ports return raw data and sums/percentages/rounding/business filters happen in the domain, not in SQL; helper logic that only touches entity fields moved into the entity.
Why: single responsibility; in-memory and ORM repos stay equivalent.
**JAV-20 No setters or setter chains in use cases; no Demeter chains** — Major · ~170 comments
Check: `entity.setX(..)` sequences (use constructor/factory/domain method like `markAsOnHold(reason)`; derived hashes computed in the constructor); `a.getX().getY().getZ()` (add a method on the owner); whole entity/command passed when only an id/amount is used.
Why: encapsulation, minimal coupling.
**JAV-21 Value objects: immutable, minimal, typed** — Major · ~130 comments
Check: non-`final` VO fields or setters (modifiers return a new VO); `record` for simple data (no `toString/equals/hashCode` in records); primitives/`String` for domain concepts (use the project's `Currency`, id and amount VOs, validated VOs, enums instead of magic strings or ints; ints only in ORM entities); classes for their own sake (empty interface, factory over a ctor call); 5+ loose params instead of a VO (`CreditCard`, `DateRange`).
Why: validity and clarity of the ubiquitous language.
**JAV-22 Layering: domain depends only on ports; code lives in the right package/module** — Major · ~110 comments
Check: Spring/POI/Jackson/ORM imports in domain; logic in adapters/repositories; class in the wrong package (commands vs queries, services in infrastructure, errors in the errors package, DTOs with the ports, test-only classes in the test tree); shared-kernel class copied into a module or module-specific code placed in a shared package; a gateway/port to the same module (use the repository); concerns of another bounded context; same-named repository/component in two modules of one Spring context without a unique bean name (`@Repository("billing_InvoiceRepository")`).
Why: dependency direction and Spring context conflicts.
**JAV-23 Reuse before adding: classes, enums, errors, DTOs, builders, utilities** — Major · ~160 comments
Check: new class/enum/error/DTO/builder/VO/utility equal to an existing one in the module, sibling modules or shared kernel (type enums, status enums, string/clock helpers, abstract builders, existing not-found errors, existing in-memory repos); near-identical use cases per provider not combined; new event/sender/port/listener whose payload equals an existing one, mono/multi-currency payload variants, one controller multiplexing events, events/ports with no consumer; a table/entity that already exists after a rebase; an enum added only to validate where the gateway/upstream is source of truth.
Why: duplicated contracts drift.

### Errors and validation
**JAV-24 Custom errors: right base, name, code, tests** — Major · ~275 comments
Check: base class matches the situation (not found / invalid argument / missing argument / conflict-already-exists / unprocessable: valid input but forbidden state) following the project's hierarchy and HTTP mapping; name `<Resource><Reason>Error`; error code in the repo's format (e.g. `RESOURCE.REASON`) equal to the API/front-end code, not a loose word like `"DateEmpty"`; non-empty message; code seeded wherever messages are catalogued (canned messages, migration); covered by a REST-controller test and a unit/integration test; no unused errors.
Why: HTTP status and error-code contract with clients.
**JAV-25 Fail with a specific error, never empty/null/generic** — Major · ~85 comments
Check: not-found/invalid returning `Mono.empty()`/`null` instead of `Mono.error(new OrderNotFoundError())` (or throwing in imperative code); `NoSuchElementException`/generic exception/magic error string; a parser/IO `catch` returning `null`/`""`/`0` (missing fields stay `null`; log with the exception, then throw the functional error); in-memory and ORM repos raising different errors; `parseInt`/`substring`/`new BigDecimal` on unchecked input.
Why: silent data corruption, inconsistent API behaviour.
**JAV-26 Validate cheap -> expensive, in small `check/validate` methods, with the repo idiom** — Major · ~230 comments
Check: order emptiness -> id format (before touching the DB) -> existence -> state -> related entities, one error per case; `validate` returns void/`Mono<Void>`, not the entity; `existsBy*` on the owning table instead of `find`+`switchIfEmpty` (no extra existence check when `findById` already throws, or on delete); both-or-none filters (both dates, bin+last4) and standalone filters (id, document number) that ignore others; pagination validation in the handler, functional filter validation in a reusable service; null-safe helpers, `Enum.valueOf`, id value objects for format checks; absent optional filters never raise.
Why: predictable errors and cheap failures.

### Persistence
**JAV-27 If the project uses in-memory test doubles: the in-memory repository must mirror the ORM one; no test-only methods on ports** — Major · ~190 comments
Check: same filters, ordering, null handling, bounds (`containing` vs `startsWith`, strict `>`), errors; every port method implemented in both; test-only methods (`forceError`, `findXForTests`, `addX`) in the in-memory class or private, not on the port; no business logic or over-engineering in the fake; unused port/ORM methods deleted; ORM defaults unchanged.
Why: tests pass on the fake while prod behaves differently.
**JAV-28 SQL: select needed columns/joins only; prefer derived queries/Criteria; bind parameters** — Major · ~120 comments
Check: `select *` (also just to count), unused columns/`LEFT JOIN`s, list endpoints that load all reference rows in memory and match them in Java (ask for a JOIN in the query when page sizes are small), values stored in a JSON/metadata column when a real column exists; hand SQL where `existsBy`/derived queries/the Criteria API works; `"""` text blocks with `WHERE 1=1`, `String.format`/concatenated values or `LIMIT` instead of bind parameters; keyword casing and full table names per repo style; before/after-id pagination and page-size defaults belong in the repository.
Why: performance and injection safety.
**JAV-29 No N+1; update directly instead of find+save** — Major · ~115 comments
Check: per-item queries in loops (use `findAllByIdIn`, `saveAll`, batch delete); `findById(id).flatMap(save)` (overwrites columns written by other modules; use `UPDATE ... WHERE id IN (:ids)`); several updates per aggregate per use case; `collectList` then Java filtering; flag parameters.
Why: DB load and lost concurrent writes.
**JAV-30 ORM mapping and schema fidelity; a new field touches the whole stack** — Major · ~120 comments
Check: new/renamed field present in ORM entity, ctor, `toEntity/fromEntity`, migration/view, in-memory repo, builders, test table clean-up, REST response, event sender/queue, async-API doc, tests, downstream payloads; DB column not hidden in a JSON column (filtered/joined fields get a real column); related tables updated together (history/deleted copies, rates); column types/names match the DB; `Persistable<ID>` with `@Id` when ids are assigned by the app; shared ORM base class (audit dates) extended; `@Repository` not `@Component`; mapping non-static after constructors, one shared private method; JSON via the project's serializer helper.
Why: data loss and half-wired features.
**JAV-31 Caches only for stable reference data, with correct eviction** — Major · ~30 comments
Check: plain `HashMap` cache shared across threads (use `ConcurrentMap`); cache of values changeable in the DB without eviction; settings setters not evicting (the project's evict annotation).
Why: stale or racy reads.

### REST layer
**JAV-32 HTTP semantics, routes and response payloads** — Major · ~95 comments
Check: create -> POST + `@ResponseStatus(CREATED)`; update -> PUT (or PATCH for partial); no content -> 204; routes follow the repo scheme (kebab-case plural nouns, `@PathVariable` for ids); `List*` names for collections; no list returned from get-one; request object instead of many params (page-size `defaultValue`, pagination last); response only has fields clients need (no entities, a shared amount response type); already-processed -> Conflict/Unprocessable; controller converts id String -> id VO.
Why: API contract with front end and sibling modules.

### Architecture of use cases
**JAV-33 Use case, command, query, event, test and package names describe the behaviour and change together** — Major · ~120 comments
Check: command class starts with a verb; names consistent across use case/handler/controller/response/package/tests; a renamed concept renames the whole vertical slice; repo suffixes (`*CommandHandler/*QueryHandler/*EventListener`); no technology words; repository mutators named after the domain action (`assignOwner`, `markAsResolved`).

### Tests
**JAV-34 Assert every relevant output, independent of production code** — Major · ~360 comments
Check: new field/event/amount not asserted in every related test; missing amounts (all currencies), currencies, dates, event id, period, type, referential keys, user, lock state, reverted flag; `isNotNull`/`isPresent` instead of the exact value; fields instead of the whole value object/expected object; expected built from what the use case produced or via a serialize round trip (build from source data); persisted state/event payload unchecked (`findById`, event-listening helper); assertions inside `forEach` over a possibly empty list; redundant size assertion; same condition tested twice or `assertThrows` where `StepVerifier` fits.
Why: tests that cannot fail.
**JAV-35 Prove filters with distractor, boundary and negative data; cover every new error** — Major · ~290 comments
Check: new filter/branch tested only with matching data; missing distractors (other tenant/rule/type/provider, inactive, outside date range, at cut-off, > page size, before/after id, mixed statuses, several items for aggregation), null/empty filters, an "all filters" test, a no-match case returning an empty list (`shouldReturnAnEmptyListWhen…`), flag on/off; error-case tests placed first in the class; no test per new error code; hard-coded years.
**JAV-36 Test at the right level; few costly E2E** — Major · ~165 comments
Check: E2E repeating unit cases or validation (one happy-path e2e per use case); repository/transaction/cache behaviour tested outside the integration-test base; REST endpoint without a web-layer test (`@WebFluxTest`/`@WebMvcTest`) covering each handler error with the real code string and status; a failing test deleted instead of fixed; unit tests not extending the project's unit-test base when one exists; test class per use case mirroring the main package.
**JAV-37 Test data via builders, a fake-data generator and constants** — Minor · ~300 comments
Check: builders follow the repo base (defaults via `orElse`-style helper, `Boolean` wrapper so defaults apply, nullable fields default `null`, "without persisting" variants + bulk create), no unused builder fields/params, irrelevant attributes not set; fake-data generator as a single field, realistic values, no random amounts (use distinct, clear values); fake user/dates/ports; tenant/user constants not hard-coded; no `null` ctor args.
**JAV-38 Test structure, naming, helpers** — Minor · ~680 comments
Check: `// given // when // then` (same casing) with `givenX/whenX/thenX` private helpers; tests first (negative first is fine), helpers after `@Test`; names `shouldXWhenY`/`shouldReturnErrorWhen...` without tech words and matching what is asserted; helpers single-responsibility, take only needed params (no boolean flags), reuse existing ones; expected values declared in Then next to use; DRY secondary to clarity; follow the neighbouring file for given/when/then in names.
**JAV-39 Do not touch unrelated tests, timeouts or shared infrastructure** — Major · ~120 comments
Check: changed wait/timeout values, shared integration-test setup, other features' tests/assertions/listeners, renamed constants/endpoints, removed tests or fields, import reformatting; ask to revert or justify ("why was this removed?").
Why: hidden regressions and noisy diffs.

### Readability and hygiene
**JAV-40 Remove dead code** — Major (whole class/event/port/error/public API) / Nit (imports, overrides) · ~670 comments
Check: added method/field/param/injected port/class/enum/error/event/constructor/setter with no caller; `@Override` equal to the base default; commented-out code; stale TODOs; speculative code for unimplemented cases (YAGNI); unused builder fields.
Why: stale contracts and confusion; history lives in git.
**JAV-41 Extract long/nested logic into intent-named private methods; one abstraction level** — Minor · ~560 comments
Check: lambda/`execute`/parser body > ~10–15 lines or nested `flatMap`; assertion blocks in tests; `else`/nested ifs instead of early return; `noneMatch` over negated `allMatch`; long `switch` instead of `Map.of`/enum lookup; trivial one-liners extracted needlessly.
**JAV-42 No output parameters, flag parameters or tuple/`Pair` returns** — Major · ~45 comments
Check: callee mutates a passed list/map/`StringBuilder` (build and return it); boolean flag parameters; `Pair<Boolean, ExceptionBase>` (use a record or a specific error).
Why: hidden side effects.
**JAV-43 Logging via the project's logger, with context, once** — Minor · ~50 comments
Check: `System.out`/raw logger when the project has a context-aware logger; log without context (tenant/correlation id); logging where the base use case/handler already logs; no log for skipped/invalid rows in loaders; (reactive) context not written to the chain (`contextWrite(...)`).
**JAV-44 Naming: intent over mechanics, domain-accurate, consistent** — Minor · ~450 comments
Check: misleading or technical names (`userId` -> `owner`, `update` vs `change`, `find*` returns Optional/Mono, `list*` collection); abbreviations vs DB/API/spec names; singular resource names; names consistent with sibling features and in-memory/ORM counterparts; the team's domain vocabulary used consistently (`discrepancy` vs `difference`); single-letter or throwaway names (`e`, `entry`, `ob1`); revert renames without reason.

## Style conventions (Minor/Nit)
- No wildcard imports; do not reorder unrelated imports; remove unused imports.
- Follow the project's formatter config (e.g. one constructor parameter/injected field per line, blank line between methods, no double blank lines, chain dot at line start); do not hand-format against it.
- Member order: follow the existing convention in the repo (e.g. static constants, fields, constructors, public, protected, private), also in tests, fakes and listeners.
- Keep lists alphabetical where the project already does (metadata keys, enum constants, field dictionaries); do not introduce the convention otherwise.
- Extract repeated literals (date formats, file extensions, tenant, regexes, magic numbers like 100/13) to `private static final UPPER_SNAKE` or an enum; tunables via `@Value`/properties with a default.
- Variables/fields camelCase (no cryptic abbreviations), constants `UPPER_SNAKE`, boolean getters `isX`; package names lowercase.
- Remove comments that restate code or mark removed code; no `toString/equals/hashCode/getters` on records or events; do not mix Lombok `@Getter` and explicit getters.
- Idioms: `String.format`/`.formatted` over concatenation, `.toList()`, `IntStream.range` over for/break, `Objects.isNull/nonNull`, shared null-safe string helpers if the repo has them.

## Not worth flagging
- Javadoc/comment absence; HashMap vs TreeMap order; toString on events.
- Long descriptive method/test names (encouraged); duplication in tests that makes a case clearer.
- Fields kept for backward compatibility when justified; no E2E required per amount variant.
- Defensive checks/getters/Optional that builders or constructors already guarantee are not needed (flag the extra ones, not their absence).
