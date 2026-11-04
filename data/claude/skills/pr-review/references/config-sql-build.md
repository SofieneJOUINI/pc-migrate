# Config, SQL, build, scripts - generic review rules

Applies to PRs touching DB migrations, SQL (seed/test), build files (Maven/npm/Gradle), configuration (properties, env, Helm/Kubernetes, parameter stores), CI workflows, Dockerfiles, API/event docs (OpenAPI/AsyncAPI), identity-provider role config and test scripts.
Distilled from ~880 real review comments. Counts are approximate ("~N comments in the source reviews"). Severity: blocker / major / minor / nit.
Rules marked (conditional) apply only if the repo has that artifact or convention; never invent a convention the repo lacks. Project-specific facts and rules live in the project profile; where the profile conflicts with a rule below, the profile wins.

## Discover in the repo before reviewing

- Migration tool, folder, file/class naming pattern, ordering mechanism (timestamp, sequence number), and the latest existing migration.
- Current schema source of truth (entities/models, init or schema dump) and which tables mirror each other (archive, deleted, failed, history).
- Test schema files (init SQL, fixtures) and test cleanup mechanism (base class, truncate script).
- Seed/reference-data scripts and any clean-up script.
- How versions are bumped and released (pom/package version, SNAPSHOT policy, changelog, tags); which modules release independently.
- Dependency management (parent/BOM, property blocks, lockfiles) and the agreed runtime version (JDK/Node).
- Config files per environment and per tenant/customer; naming convention of keys; where defaults are documented; local/test config files shared by all devs.
- Secret handling (ignored files, `.example` files, secret store) and `.gitignore`.
- CI workflow files, image registry and tagging scheme, deploy branch/tag conditions.
- Docs that must follow code changes (API/event spec, role/permission docs, README).
- Project policy on DB constraints, standard columns, naming and column types.

## 1. Migrations (~220 comments in the source reviews)

**CFG-01 Timezone-aware timestamps** - major, ~20
- Check: every date/time column uses a timezone-aware type (`TIMESTAMP WITH TIME ZONE`/`timestamptz`), never plain `TIMESTAMP`/`DATETIME` without zone, unless the repo's convention says otherwise.
- Why: naive timestamps cause timezone bugs when data is UTC or multi-region.
- Example: `created_date TIMESTAMP` -> `created_date TIMESTAMP WITH TIME ZONE`.

**CFG-02 Idempotent and reversible migrations** - major, ~35
- Check: `IF [NOT] EXISTS` on create/add/drop where the dialect allows; a `down()`/rollback exists and mirrors `up()` exactly; both directions were run locally.
- Why: migrations rerun across many schemas/environments and must roll back cleanly.
- Example: `down()` missing or only partly undoing `up()`.

**CFG-03 Keep sibling/archive tables in sync** - major, ~25
- Check: a column/index/type change on a table is applied in the same migration to every mirror table (archive, deleted, failed, history, staging copies), and to copy/archival code paths that list columns.
- Why: mirror tables must stay structurally identical or archiving/copy logic breaks.
- Example: `ALTER TABLE orders ...` only -> same `ALTER` on `deleted_orders`.

**CFG-04 Group related changes, separate additive from destructive** - minor to major, ~8
- Check: related changes on the same tables live in one migration; adding/backfilling and dropping deprecated columns are in separate migrations or PRs.
- Why: atomic releases; dropping in the same release breaks backward compatibility.

**CFG-05 Backward-compatible schema changes; never edit released migrations** - blocker, ~8
- Check: no drop/rename of columns or tables still used by a deployed release (expand, migrate, contract over several releases); an already-released migration is not modified (edit only if merged but not yet released, otherwise add a new one).
- Why: other environments may run an older release against the new schema.
- Example: `DROP COLUMN x` in the PR that stops using x -> keep it, remove in a later release.

**CFG-06 Check the current schema first** - major, ~15
- Check: added columns/tables do not already exist; renamed or legacy columns are verified against the real table and the ORM entity; nothing duplicates an earlier migration.
- Why: duplicates fail on deploy; non-matching names silently diverge from the entity.

**CFG-07 Size and type columns to the data** - minor to major, ~60
- Check: width matches the identifier format (ULID 26, UUID 36, currency code 3, short enums sized to longest value); complex or monetary values use the same type as sibling columns (json/jsonb or numeric); defaults are explicit and sensible (0 for amounts, boolean defaults).
- Why: avoids truncation and wasted width; keeps entity mapping consistent.
- Example: `id varchar(36)` holding a ULID -> `varchar(26)`.

**CFG-08 Naming consistency** - minor, ~30
- Check: snake_case (or the repo's convention) for tables/columns; references end with `_id`; names identical across migration, entity, init SQL and spec; migration file name and class name match, descriptive, no spaces or special characters.
- Why: drift between migration, entity and docs causes mapping bugs.
- Example: `datasourceId` -> `datasource_id`.

**CFG-09 Migration ordering** - minor, ~8
- Check: the new migration is the latest in the folder after rebase (timestamp/sequence bumped); file and class renamed when scope changes.
- Why: tools run by order; an older one may be skipped or run in the wrong position.

**CFG-10 Constraints and logic in the DB: follow the project's policy** - major, ~12 (conditional)
- Check: if the project avoids DB-level NOT NULL/UNIQUE/CHECK/enum types/triggers and validates in code, flag any added; otherwise check constraints are safe for existing data (defaults, backfill before NOT NULL).
- Why: constraints on populated tables can break the migration and portability.
- Example: `version int NOT NULL` -> nullable with default (when policy is no constraints).

**CFG-11 Standard columns** - minor to major, ~10 (conditional)
- Check: if the project defines standard columns for new tables (version, metadata, created/updated dates, audit), they are present; trace-only values go in the metadata column when one exists, not a dedicated column.
- Why: platform-wide table convention.

**CFG-12 Heavy backfills outside schema migrations** - major, ~6
- Check: no large UPDATE/INSERT-SELECT without a selective WHERE on production-size tables inside a schema migration; use the project's data-migration job/script/procedure, batched.
- Why: schema migrations must be fast and safe; huge tables lock and time out.

**CFG-13 DDL hygiene** - nit to minor, ~8
- Check: `CREATE OR REPLACE` for views/functions/procedures; explicit index method if the project does so; `IF EXISTS` on drops; obsolete indexes dropped with their column; related ALTERs combined in one statement/transaction.

## 2. Seed / reference-data SQL (~108 comments)

**CFG-14 Seeds match code and spec** - major, ~60
- Check: names, IDs, event/type codes, internal names and foreign references equal the values in code and specs; IDs are unique (no copy-paste duplicates); references point to real rows.
- Why: wrong seed values give broken rules and failed matching in demo/test environments.
- Example: a record copied from another entry but its key not changed.

**CFG-15 Seeds minimal and environment-appropriate** - minor to major, ~30
- Check: only data the target tenant/env uses; existing rules/records are not edited (add new ones); each rule has its contents/variants; no schema-qualified names, empty or misaligned lines.

**CFG-16 User-visible seed text** - minor, ~12
- Check: canned messages and labels are in the project's language (usually English) and match the error/status codes defined in code.

**CFG-17 Seed and clean-up scripts follow schema changes** - minor, ~5
- Check: new tables/columns are reflected in seed scripts and in any clean-up/truncate script.

## 3. Test schema and test cleanup (~65 comments)

**CFG-18 Test schema aligned with migrations** - major, ~35
- Check: test init/schema SQL contains exactly the columns and tables in the migrations/entities (no deprecated columns), same names, types and order.
- Why: tests silently diverge from production schema and fail later in CI.
- Example: legacy column kept in test DDL after being renamed in the migration.

**CFG-19 New tables get test cleanup** - major, ~15
- Check: every new table in test schema is also deleted/truncated in the shared test cleanup; queues/events are cleaned between tests.
- Why: leftover rows/events cause flaky pipelines.

**CFG-20 No unused test schema** - minor, ~12
- Check: unused tables/columns and unrelated edits removed or reverted.

## 4. Build files and versions (~167 comments)

**CFG-21 Bump the version of every released artifact you changed** - major, ~112 (most frequent request)
- Check: each module/library/plugin changed has its version bumped per the repo's scheme; breaking changes get a major/minor bump; a bugfix on an unreleased snapshot keeps the version; never reuse a version already deployed.
- Why: independent releases need unique versions; a wrong or missing bump yields stale or conflicting artifacts.
- Example: module changed, version untouched -> bump; 2.0.3 already deployed -> use 2.0.4.

**CFG-22 Do not bump unchanged modules; shared libs release separately** - minor, ~15
- Check: no bump for untouched modules/parents; changes to a shared library go in their own PR and release, dependents updated afterward.

**CFG-23 Manage dependency versions centrally** - minor, ~25
- Check: versions in a properties block (above dependencies) or parent/BOM, referenced not hard-coded; nothing already managed by the parent is re-declared; no duplicate dependencies.
- Example: `<version>2.0.0</version>` inline -> `<core.version>`.

**CFG-24 Agreed shared versions and platform runtime** - major, ~25
- Check: internal shared libraries at the latest agreed version; JDK/Node/base-image version matches the platform standard; no dependency on an unpublished version.

**CFG-25 Remove unneeded build clutter** - minor to major, ~40
- Check: unneeded dependencies, exclusions, workaround lines, local-only settings (e.g. `.m2/settings.xml`); one deployable module must not depend on another deployable module; module/package names follow convention (lowercase); new module registered in the parent/aggregator; quality-gate exclusions are not used to hide issues (fix them).

**CFG-26 Vulnerable or old libraries** - minor, ~4
- Check: prefer overriding a version property over excluding a transitive dependency; upgrade vulnerable/outdated libs to the latest stable.

## 5. Configuration (properties, env, Helm, parameter stores) (~100 comments)

**CFG-27 Do not touch shared local/test config without reason** - major, ~45
- Check: local, integration-test and base config files carry no accidental, debug or commented-out edits; debug logging dropped; local defaults kept (feature flags off locally).
- Why: these files are shared by all devs and CI; stray edits break others.

**CFG-28 Config key naming, units, defaults, flags** - minor, ~15
- Check: new keys follow the repo's prefix/kebab-case convention; the unit is in the name (`-in-seconds`, `-in-days`) when the value is a duration/size; a documented default exists in the base config; feature flags default to disabled.

**CFG-29 New variables are declared where the repo expects** - minor, ~8
- Check: new env vars/flags added to `.env.example` or the base config file; a library does not ship its own env/config (the consuming app sets it); infra values (URLs, keys) come from deployment config, not code.

**CFG-30 Port and probe consistency** - blocker for prod, ~15
- Check: server port, Service targetPort, liveness and readiness probe ports agree; replica counts come from values; prod values never reference localhost.
- Why: mismatched probe port kills pods.

**CFG-31 Apply config changes to every env and tenant** - major, ~20
- Check: a new/changed parameter exists in all environments (dev, staging, prod) and for each tenant/customer; no copy-pasted wrong tenant names; schedules differ per tenant/job where intended; one naming for a given parameter (no near-duplicate keys).

**CFG-32 No secrets in the repo** - blocker, ~5
- Check: no committed passwords, tokens or credentials in config/values; local credential files are git-ignored with a committed `.example`.

## 6. Files that must not be committed (~15 comments)

**CFG-33 Junk and generated files** - major (blocker for credentials), ~30
- Check: no crash dumps (`hs_err_pid*`, `.attach_pid*`), logs, IDE folders, accidental files (stray editor commands, `credentials`), unintended lockfiles, large/unused test data; `.gitignore` updated.

**CFG-34 Test fixtures small and anonymous** - minor, ~10
- Check: sample files contain a handful of records (max ~100), are valid for the consumer, have simple names (no parentheses/special chars), and contain no real personal or card data.

**CFG-35 File-format mapping configs** - major, ~25 (conditional)
- Check: where the repo has parser/mapping configs (XML/JSON field layouts): repeating records are lists, unidentified records are rejected when the project requires, unused fields/records/regex removed, shared type handlers reused, field order sequential, spec version updated.

## 7. Docs, CI, Docker, IdP roles, test automation

**CFG-36 API and event docs follow code** - minor, ~10 (conditional)
- Check: OpenAPI/AsyncAPI descriptions and doc version updated for new/changed endpoints/events; no repeated descriptions already defined in messages; schema fields exist on the referenced type.

**CFG-37 CI workflows** - major, ~14
- Check: names/registry variables consistent across repos; images tagged explicitly (not `latest`, not reusable mutable tags like `dev`); deploy conditions use the project's branch/tag patterns; failing steps log useful output; unrelated workflow edits stay out of feature PRs.

**CFG-38 Dockerfiles** - minor, ~3
- Check: base images updated and pinned; runtime version aligned with the platform.

**CFG-39 Identity-provider roles and permissions** - major, ~74 (conditional)
- Check: role names follow one scheme (resource-plural-action, lower-kebab, typo-free verbs) consistent with API and front end; new roles assigned to the right composite/realm roles (read-only roles get read actions only); existing clients/attributes not redefined; change file numbered next free (rebase if taken, no spaces in name), one per PR; roles documentation updated.
- Why: role names are a public contract between API, front end and mapping.
- Example: `get-settlements` for a list endpoint -> `settlements-list`.

**CFG-40 Test automation scripts** - minor to major, ~20 (conditional)
- Check: file name equals class name, naming conventions followed; the project's API-test helper used; assertions have messages and verify the change in the response or DB, not just the status; tests keep working on the main branch environments.

**CFG-41 Scripts and README** - minor, ~8
- Check: scripts have a README with steps and required config; they fail on error without needless checks; local profile changes do not leak into prod config; batch scripts persist per-item progress and use the agreed batch size.
