# Angular — review rules
Scope: any Angular application (RxJS, Jasmine/Karma or Jest specs, TestBed). Distilled from ~8.4k real review comments on a large enterprise Angular codebase; counts ("~N comments in the source reviews") are approximate and show how often a rule was raised there — use them as priority hints, not as law for another repo. Walk the diff against each rule's "Check"; cite the rule ID in the finding; anything the repo's formatter (Prettier etc.) enforces is not listed. If a project profile fragment exists for the reviewed repo, apply it on top of these rules and let it win on conflicts.

## Discover in the repo before reviewing
Check these before suggesting new code or flagging conventions. Never assume a convention the repo does not follow.
- Shared/UI modules and components: list the shared folders (shared UI, design-system wrappers, table, dropdown, spinner, tag, copy button, export button). Most "new" components already exist.
- Services for toasts, confirm dialogs, dialogs, error display, permissions/auth: which ones does the app expose and how are they keyed/wired?
- Path aliases in `tsconfig.json` (`paths`): which aliases exist, when must cross-module imports use them instead of `../../..`?
- State/loading/error naming pattern: how do existing components name lists, loading flags, error messages, filters, pagination cursors?
- Test helpers and mocks: mock factories, spy-object conventions, mock pipes/components, HTTP testing helpers, `initMocks`-style setup.
- API client conventions: base path/versioning, how services build URLs, params, headers, bodies, and how errors are typed and mapped.
- i18n or hard-coded text: translation library in use (keys, pipes) or plain strings? Follow it.
- Lint/prettier config (`.eslintrc`, `.prettierrc`, hooks, Sonar/quality gates): what is already enforced mechanically and must not be re-flagged; whether imports/members/attributes are kept alphabetical.
- UI library (PrimeNG, Material, none) and utility CSS framework (PrimeFlex, Tailwind, none).

## Rules

### API contract, data and spec conformity
**FE-01 Models, DTOs, requests and filters must match the API spec** — Blocker · ~180 comments
Check: field names/spelling, types (dates and ids are usually strings), required vs optional (`?`), no fields absent from the DTO, no leftover fields the API dropped, request body shape (object, not bare array), endpoint path/version prefix, mandatory filters stay mandatory, front-only enum values (e.g. a UI-only `DELETED` state) are not sent to the API.
Why: a wrong shape hits the real API; reviewers verified against the OpenAPI/swagger file.

**FE-02 Deliver exactly what the ticket/design specify (no more, no less)** — Blocker · ~260 comments
Check: labels and wording, column order/width (narrow action columns), filter order/size/placement, default selections, button order/placement (primary positive, secondary negative, Cancel present), unique icons per menu item, no page title duplicating a breadcrumb, delete/edit columns hidden in create mode, table scrolls not the page; no extras nobody requested (additional inputs, tooltips, new input types, extra fields); default filters per ticket.
Why: acceptance is checked against the design and the API spec ("main target of the task is not done").

**FE-03 HTTP services: full resource path, JSON body, one service per resource** — Major · ~130 comments
Check: the base path constant holds the whole resource (`/v1/invoices`), spelling matches the API; POST/PUT body is a proper JSON object (e.g. `{ frequency }`), no body -> `null`; `new HttpParams().set(...)` for a single param; no unused `HttpHeaders`/`HttpParams`; a new method goes into the existing service of that resource (service named like the root endpoint), not a second service or a duplicate; services used by several features live in the shared area; newer API versions use their own base-path constant; deprecated services removed; no HTTP interceptor injection just to catch errors.
Why: wrong path/body confirmed as bugs against the API.
```ts
// flagged
this.http.put(url, frequency)
// expected
this.http.put(url, { frequency }, { headers })
```

**FE-04 Service maps DTOs to model instances** — Major · ~50 comments
Check: `get<OrderDTO>()` then `map(d => new Order(d))`; services return models (not DTOs/raw objects); list methods return model arrays; DTO class extends the front model and calls `super` where that pattern exists.

**FE-05 Wire new/renamed filters end to end** — Major · ~130 comments (incl. pagination)
Check: filter model + constructor default, "has the filter changed" logic (pipe/method) and its spec, request-param builder (arrays send all values), export/extraction filter (built from the applied-filter history, not the live form), load-more/reset (cursor or page), clear/reset logic, every context sharing the list (active, archived, audit variants). Paginated endpoints: cursor/page param + load-more disabled when no more data; non-paginated endpoints: no load-more/cursor. Assign filter changes by creating a new filter object so the reference changes (change detection); front-only filters are filtered in the front.
Why: filters were silently missing in export or in other contexts.

**FE-06 Zero is a valid number: never test numbers by truthiness** — Major · ~45 comments
Check: `x || default`, `if (!x)`, `!!x` on numeric fields/filters/percentages/amounts; division by zero; `|| 0` display of empty optional numbers.
Why: `0` (e.g. `minAge: 0`) silently dropped.
```ts
// flagged
this.n = dto?.n || 33;
// expected
this.n = typeof dto?.n === 'number' ? dto.n : 0;
```

**FE-07 Error handling via the app's typed error model** — Major · ~50 comments
Check: errors typed with the project's HTTP-error type (not `any`), branch on status code (409...) not on message text; new API error codes added to the error-code maps (one map/file per resource if that is the pattern, with tests); correct category (404 is not 400); explicit human-readable message; not-found/conflict mappings registered wherever the central error handler/interceptor expects them.
Why: a central layer usually transforms messages; string checks break.

**FE-08 Permissions: role per page/action, checked at the right place** — Blocker · ~105 comments
Check: each new page/action has its own role/permission (not copy-pasted from another feature) declared everywhere the project lists them (enums, auth-server config, role docs, route config); page access enforced at route level (guard), not re-checked in the component; actions hidden (not just disabled) via the project's permission directive/pipe; granular and top-level roles both handled; permission is the first/cheapest condition; separators/parent menus follow child visibility; the method deriving actions from permissions is private, called in `ngOnInit`, and has its own spec suite using the permission-service mock; the module exporting the permission directive is imported where used.
Why: a button shown without the role is a security regression.

**FE-09 Verify business logic and regressions** — Blocker · ~210 comments
Check: wrong currency/amount field (payment vs settlement vs accounting), inverted or wrong comparison (`>=` on the wrong field), `&&` vs `||` in validation/permission, checks on not-yet-loaded input, copy-pasted logic/labels from another feature, reload loop or double load on init, load-more disabled after a filter change, `stopPropagation`/click-outside hacks, missing error display on API failure, missing sort requirement; shared components (table, list, dialogs) changed -> other views still OK; no new request params where not needed (compare with the base branch); no fake/local-test data.

### RxJS, lifecycle and state
**FE-10 React to `@Input` in `ngOnChanges`, never mutate inputs** — Major · ~105 comments
Check: logic using an `@Input` inside `ngOnInit` (inputs may change later); guard with `changes.x?.currentValue` (not nested `&&`); no reassignment of an input (use a local attribute); input not passed as a parameter to the component's own methods; mandatory inputs not optional; implemented interfaces match hooks used; hook order `ngOnInit`, `ngOnChanges`, `ngOnDestroy` if that is the repo's habit.
Why: stale data and parent/child desync (also a static-analysis finding).
```ts
// flagged
ngOnInit() { this.load(this.filter); }
// expected
ngOnChanges(c: SimpleChanges): void { if (c.filter?.currentValue) { this.load(); } }
```

**FE-11 Subscriptions cleaned up, no needless RxJS/async hacks** — Major · ~40 comments
Check: subscription stored and unsubscribed in `ngOnDestroy` (and a spec asserts it), or `takeUntil`/`takeUntilDestroyed`/`async` pipe per project style; no `forkJoin`/`merge`/`add` around a single stream; no nested subscribes; no `Promise`/`setTimeout` workarounds.

**FE-12 Load/error/empty state handling on every load** — Major · ~115 comments
Check: before the call set the loading flag, clear the error message, empty the target list; hide the loader as the last statement of both `next` and `error`; no list reload after an error (user input lost); error feedback (toast/message) for failed actions; dependent dropdowns/filters/history reset on success, failure and rejection; no API call when a prerequisite id/type is undefined; no counts/empty-state box when the load failed; action buttons disabled while a request is pending; every load shows spinner, error display and empty state, rendered inside the content/table area.

**FE-13 Initialise state; guard templates** — Major · ~45 comments
Check: lists `= []`, strings `''`, models via constructors; `*ngIf="order?.id"` on mandatory objects before rendering content; no `?.` where already guaranteed; compare objects by id (not by reference or `JSON.stringify`).

**FE-14 Dropdown/select models are `T | null`, default `null`** — Major · ~40 comments
Check: selected value typed `Type | null = null` (not first item, `''`, `{}` or `undefined`); reset to `null` after load/reset; single-select uses an object or `null`, not parallel id/name fields; no `| ''` type; free-text filters not `| null`; send ids, not objects, to the API.
```ts
// flagged
selectedCustomerId = '';
// expected
selectedCustomerId: string | null = null;
```

**FE-15 UI state: few clear flags, no duplicated state** — Major · ~75 comments
Check: new attributes restating model/filter data (`this.customer.id`, `filter.status`); an extra boolean where a pipe/existing value can derive it; several inter-dependent booleans instead of one `isEditModeActive`; arrays rebuilt on each toggle; refresh from the API after save/cancel and leave edit mode on cancel; unused EventEmitters/getters in services.

### Component design and reuse
**FE-16 Reuse shared components, no raw HTML tables** — Major · ~100 comments
Check: `<table>/<td>` instead of the existing table component; a copied dropdown/template (extract a component); a new component/service similar to an existing one (inplace editor, spinner, tag/chip, text shortener, clipboard copy, export button, dropdown filters); a generic component depending on parent context, setting page filters or styling external components; reusable pieces not moved to the shared module (pure UI vs shared models/services, if the repo splits them) and not exported from its public index; component-specific condition logic living in the parent instead of the child.

**FE-17 Use the project's toast/dialog/permission/auth services** — Minor · ~75 comments
Check: the existing toast, confirm-dialog, dialog, permission and auth-handler services are used rather than ad-hoc ones; toasts raised through ONE private method taking the severity (not repeated `displayNotif` copies); a toast/dialog key (if the library uses keys) defined once and passed to children; every key has a matching toast/dialog element in the template; no extra confirm-dialog/toast where the parent already provides one.

**FE-18 Extract and de-duplicate logic; right layer** — Major · ~170 comments
Check: logic duplicated 2+ times, complex conditions, values computed twice; sort/group/normalise API lists in the service (not component/HTML); table-column and filter-changed logic in dedicated pipes/helpers (shared, not duplicated across modules); a method does one thing; no single-use transient variable (`const r = f(); return r;`); no param when the value is on `this`; pass pipes the whole object; one request object when there are 2+ params (`OrderChangeRequest`); pass only what is needed (an id, not the whole model or dialog data); don't mutate input objects.

**FE-19 Module hygiene** — Minor · ~35 comments
Check: unneeded imports (`FormsModule` etc.), needless `providers`, another module's component declared instead of exported from its module, duplicate declarations; `CUSTOM_ELEMENTS_SCHEMA` only when custom elements really exist.

**FE-20 Pipe conventions** — Major · ~90 comments
Check: pure, one job (split pipes doing two); typed minimal params (no `any`, mandatory not optional); no state, no `pure: false` without need; not declared as provider AND mocked in the spec (provider only if injected in a class); generic pipes in the shared area; internal-only pipes not exported; class name ends with `Pipe`, `name:` lowerCamel without the suffix, boolean pipes `is/has/can...`.

**FE-21 Scope changes to the ticket** — Major · ~85 comments
Check: lockfile churn (`package-lock.json`, `lockfileVersion`), `angular.json` default project, `.env.example`, unrelated `test.ts`/tsconfig changes, reordered or deleted untouched lines, changes already on the base branch, generated files, files from other repos, renames that cause regressions (removed `|| '-'` fallback, removed component).

### Typing and models
**FE-22 Model classes: constructors, defaults, no logic** — Major · ~180 comments
Check (if the repo models data as classes): classes (not interface + cast) with a constructor setting safe defaults (`''`, `[]`, `0`, `new Child(x?.child)`); no methods; no display defaults (`'-'`), `toUpperCase()` or date-library calls in the constructor (do it in template/pipe); built via `new X({...})` not literals/`Object.assign`/`{}`; no duplicate identical models; always-present attribute not optional/nullable; singular noun names (`InvoiceLine`); request models minimal; a model shared by several features lives in the shared area.
```ts
// flagged
orderTrack = { order: o };
// expected
orderTrack = new OrderTrack({ order: o });
```

**FE-23 Explicit return and parameter types** — Minor · ~150 comments
Check: every method (private, pipe `transform` included) declares a return type (`: void` too); lambda params typed (`(dto: OrderDTO) =>`); no arrow-function class members.
```ts
// flagged
onClose() {
// expected
onClose(): void {
```

**FE-24 No `any`, casts or untyped events** — Major · ~65 comments
Check: `any`, `as unknown`, `as any` (in specs call `ngOnChanges` with a `SimpleChange` instead), needless casts (`as Rule[]`), non-null `!` without need, `var`; UI-library events typed (`{ value: Account; index: number }`, `isChecked: boolean`). If unavoidable (e.g. chart libs) add `eslint-disable-next-line @typescript-eslint/no-explicit-any` with a reason.

**FE-25 No redundant types/initialisers or optional chaining** — Nit · ~110 comments
Check: `x: number = 0` / `Subscription = new Subscription()` (inferred); `isLoading = false` where a bare `boolean` suffices; `?` plus `| undefined`; `| null` when always set; `?.` after a guard; needless defaults for external inputs.

**FE-26 Simplify code and conditions** — Minor · ~210 comments
Check: `const` not `let`; `===`; `import` not `require`; shorthand `{ x }`; template strings not `+`; `for...of`/`map`/`some`/`filter` returned directly (no `forEach` pushing, `findIndex` for a boolean, `map` for side effects); `condition ? true : false`; `this.a = cond ? x : y` (not assignment in both branches); no nested ternaries; positive condition first, early guard return, no repeated earlier guard, no trailing `return;`; `switch` only for 3+ cases (braces in `case`), `if/else` for 2; long conditions into a named private method; `!list.length`.

**FE-27 Remove dead code and debug leftovers** — Minor · ~320 comments
Check: unused imports/variables/inputs/classes/providers/mock methods/mock pipes; empty `constructor() {}`/`ngOnInit() {}` (and the `OnInit` import); `console.log`, commented-out code, useless comments; `@deprecated` leftovers; duplicate declarations/exports; empty CSS classes.
Severity escalates to Blocker for `console.log`, fake data or local-test hacks.

### Unit tests
**FE-28 Every new/changed method and branch has a spec** — Blocker · ~240 comments
Check: new public methods (incl. permission/visibility logic), `ngOnInit`/lifecycle effects, each pipe branch, services (success+error, endpoint, params, body), model constructor (default values, every field incl. `id`, instantiation check first) and DTO conversion, the else-branch of every condition, each new filter attribute; outdated tests/mocks of removed code deleted.
Why: "code change should be visible in unit tests".

**FE-29 Assert before and after; assert the right things** — Major · ~300 comments
Check: initial state asserted (`not.toHaveBeenCalled`, attribute value, loading flag, error message, filter history) then the call then the new state; test values differ from defaults/expected values; services assert request method, body, params, headers and the flushed status; outputs asserted with real values and not emitted on failure; no self-equal assertions; prefer precise matchers (`toBeNull`, `toBeTrue`, `toBeFalse`, `not.toHaveBeenCalled`, `toHaveBeenCalledOnceWith`; Jest equivalents), `toEqual(expectedVar)` not a literal copy; inputs tested by calling `ngOnChanges(new SimpleChange(prev, cur, first))` with an unrelated key for the "not called" case; `ngOnInit`/`ngOnChanges` called inside the test, not in `beforeEach`.
Why: otherwise the test proves nothing ("fake coverage").
```ts
// flagged
component.ngOnInit(); expect(x).toBeTrue();
// expected
expect(x).toBeFalse(); component.ngOnInit(); expect(x).toBeTrue();
```

**FE-30 Test setup and structure** — Minor · ~240 comments
Check: data/spies initialised in `beforeEach` (shared data top-level, suite-local data in its own `describe`); shared constants never mutated; spies defined only where needed, no manual `calls.reset()`; tests order-independent; success/error grouped under suites mirroring the code branches and method order; "not called" case first; no single-test suites; private methods tested through their public caller; `fakeAsync`/`tick` only with observables; `httpMock.verify()` kept; no global `callThrough`.

**FE-31 Mocks and TestBed** — Minor · ~90 comments
Check: spy objects (`jasmine.createSpyObj` / `jest.fn`) named after the exact service, listing only used methods, variable `mockXxxService`; mock pipes/components only for those used in the template; `CUSTOM_ELEMENTS_SCHEMA` when custom components are used (drop `NO_ERRORS_SCHEMA`, don't import `FormsModule` just to compile); mocks of deleted services/pipes removed; `service`/`httpMock` initialised first in service specs.

**FE-32 Realistic, minimal, consistent test data** — Major · ~190 comments
Check: realistic ids/enums/currencies, valid models via constructors (not `{}`), different ids per item, fixed dates (never `new Date()`/now; mock the date library if output depends on today), the formats the code expects; 1–2 list items; no conditionals in test data/tests; data consistent with what is asserted (right mock index); no localhost URLs; no tests of third-party code (`join`, regex, date library, cron library); no copy-paste from another component without adapting the context (labels, inputs, services).

**FE-33 Test label wording** — Minor · ~500 comments
Check: follow the repo's existing label convention (root `describe` == class name; suites start uppercase, `it` starts `should ...`, or whatever the repo does). In teams that enforce it this is a very frequent comment. Labels readable by a non-technical person, matching what is asserted, no variable names/`null`/`undefined`/`true`/`array`/`called with`/UI words/`->`, no typos, no duplicates, no copied resource names (customers vs suppliers).

### Naming
**FE-34 Names express business meaning and exact resource** — Major · ~600 comments
Check: generic names (`data`, `item`, `x`, `index`, `ret`, `result`, `value`, `status`, `event`) and names copied from another context; technical/UI words in names or labels (`button`, `hide`, `array`, `null`, `trigger*` for non-events); method name = business action + exact resource (service/method/model match the endpoint resource); verbs for methods (`loadOrders`, `getInvoice`, `deleteOrder`); `And`/`Soft` in method names; a generic method name only for generic logic; loop variable singular and naming its item; magic values as `private readonly UPPER_SNAKE` constants; no wrong-language or misspelled domain words.
Why: readers must understand intent without reading the body; reviewers push several rename rounds.

**FE-35 Naming forms** — Minor · ~260 comments
Check: booleans `is/are/has/can/should/does...` reading as a question, positive form, no contradictory flag pairs (`isEditModeActive` not `isEditMode`); lists plural, single objects singular (a one-item list should be an object); resource services/files plural, single-item methods singular; methods camelCase, a returning method -> `get*`, a non-returning method -> `set*/update*/reset*` (a returning method must not start with `set`/`on`); UI action handlers `onXxxClick`/`onXxxChange`/`open...Popup`; `@Output` past-tense event or `xxxChange`, no aliasing, `EventEmitter<void>` without payload; template refs with a consistent suffix; spies `spy<ExactMethodName>`; no app-prefix in class names, no `Enum` in enum class name, no `ParentX` without hierarchy; PascalCase class/enum names, `Component` suffix kept, dialogs `XxxDialogComponent`, no `Page` in display components.

**FE-36 Renames must be complete** — Major · ~180 comments
Check: after renaming a class/model/method/filter/module/enum, all of these changed too: folder and every file, selector, class, spec `describe` and labels, spies/mocks/variables, module declarations, routes/menu labels, public `index.ts`, CSS root class, template usage, request-param/extraction builder methods.

**FE-37 Component-scoped class names and toast/dialog keys** — Major · ~130 comments
Check: if the repo uses a component-named CSS root class (BEM-like), the root class equals the component name without the `Component` suffix and children follow `Root-Child`; never generic (`container`, `grid-item`, `active-tag`) or lookalikes of utility-framework classes; dialog/toast `styleClass` follows the same rule; toast/confirm-dialog keys derive from the component name (`OrderListToast`) rather than one key shared by several components.
```html
<!-- flagged --> <div class="orderList">
<!-- expected --> <div class="OrderList">
```

### Templates, styles and copy
**FE-38 Template structure and logic** — Major · ~190 comments
Check: no function calls or `this.` in templates (use a pipe/precomputed field); no sorting/filtering in the template; one root element; consistent order: title, error display, spinner, content; `ng-container` + named `ng-template` with `else` (positive condition first) instead of repeating `!isLoading && !errorMessage`; `ng-container` only for conditions/templates, not as wrapper; templates used once inlined; useless `div/span` removed; plain columns rendered through `*ngSwitchDefault` with a `-` fallback; static values static (`class=`, `src=`), dynamic via `[prop]` not `prop="{{ }}"`; `ngClass`/`ngStyle` only for dynamic values; with PrimeNG-style selects, `optionLabel/optionValue` instead of mapping to a second list; utility classes passed through the component's `styleClass` (not `class`) where the library requires it; no unused `id/htmlFor/autofocus/tabindex`; uppercase heading tags (`H1-H3`) forbidden; images/icons need a meaningful `alt`.

**FE-39 Display fallback and formatting** — Minor · ~110 comments
Check: empty values show a placeholder (`{{ x ?? '-' }}`, not when the pipe already handles empty; not `0` for an empty optional number); amounts via the shared currency/amount pipe with the right currency and right alignment; dates via the app's date pipe/format (watch timezones); percent via the `percent` pipe; long ids shortened with a copy-to-clipboard control if the app has those components.

**FE-40 Required fields and forms** — Major · ~35 comments
Check: required inputs show invalid/dirty state while empty (use the existing pattern); the validation message lists exactly the mandatory fields in UI order, split per cause; valid values (0) not blocked; selection reset after create success/failure/rejection; user input not cleared on failure; reactive forms: validators on the control, `updateOn` and disabled states coherent, no manual value syncing that `formControl` already does.

**FE-41 Styling** — Major · ~220 comments
Check: utility classes already provided (flex/spacing/text helpers) used instead of new SCSS; no inline `style=""`; `.scss` not `.css` if the repo uses SCSS; `rem` not `px`, no unit on `0`; no `!important`; rules scoped under the component root class (`.Root ::ng-deep .Child`); no global styling of third-party widgets (datatable, spinner, checkbox) — use the project's wrapper classes; shared/generic components never style external components or hide scroll as a hack (fix in the caller context); no `display:none` hiding or fixed-pixel-height fixes; duplicate selectors merged, empty classes removed; no component CSS in layout components.

**FE-42 User-facing copy** — Minor · ~140 comments
Check: plain language, no technical terms or wrong-language text; table headers capitalised and singular/plural per spec; toasts with a consistent sentence style matching the action ("Order deleted successfully."); confirm messages worded consistently ("Are you sure that you want to ...?"); placeholders like `Select a payment type`; one term per view (customer vs client); option values from one list, not array indexes; if the app uses i18n, no new hard-coded text — add keys instead.

**FE-43 Self-review and PR hygiene** — Major · ~95 comments
Check: the same earlier comments left unaddressed or accepted suggestions not applied; copy-paste with the wrong context left in; evidence the feature was run locally (loading, error, empty, permission-less user); commit hooks bypassed; workflow/CI files: readable step names, upper-case env names, no files from other repos; branch/PR naming follows the team's ticket convention.

**FE-44 Ordering and file/test layout conventions** — Minor · ~900 comments
Check: follow the repo's existing ordering convention; do not impose alphabetical order if the repo does not use it. If the team keeps imports/members alphabetical (check existing files and lint rules), it was the single most frequent comment in the source reviews: imports, injected services, component methods (public first), `@Input`/`@Output` and model attributes, HTML attributes (structural directive first, `(event)` last), module `declarations/imports/providers/routes`, enum values, `switch` cases, spec variables/providers/mocks. Never alphabetical: statements in method bodies, `describe`/`it` blocks (follow method order), column definitions (follow the design). Also: cross-module imports via tsconfig path aliases, not `../../..`; merged imports from one path; in specs the file under test imported last and `component`/`fixture` (or `service`/`httpMock`) declared first; one blank line between test cases and blocks; don't remove separators on untouched lines.

## Not worth flagging
- Anything the formatter/linter fixes automatically (line width, quotes, trailing commas, semicolons).
- i18n keys or translation when the repo clearly hard-codes labels.
- State-management libraries, `trackBy`, performance micro-optimisations (rarely raised in these reviews, unless a real issue is visible).
- JSDoc/doc comments (reviewers remove useless comments rather than request them).
- Code that mirrors an existing sibling component is accepted; align with siblings rather than debate.
- UI details deferred to a follow-up under an existing ticket, and typo-only fixes (suggest, don't block).
- Interface vs class for a pure-data type with no logic and no constructor defaults needed (otherwise class, FE-22).
