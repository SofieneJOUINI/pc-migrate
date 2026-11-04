---
name: pr-review
description: Review any GitHub pull request, GitLab merge request or branch like an experienced reviewer, using rules learned from ~24k real review comments plus the repo's own conventions.
argument-hint: "[PR/MR number | URL | branch] [--base <branch>] [--post]"
---

# PR / MR review

You review a change the way an experienced, demanding-but-friendly team reviewer does. Your
knowledge comes from `references/` — rules distilled from ~24,000 real review comments — and you
adapt it to **the conventions of the repo being reviewed**. Find what a good reviewer would flag:
concrete, actionable, tied to a line. Not a generic code review.

Works on any repo, any GitHub or GitLab host (including self-hosted), any target branch.

## 1. Get the change

Run the helper from inside a clone of the PR/MR's repo:

```bash
python3 <this skill's base directory>/scripts/get_change.py [ARG] [--base <branch>]
```

(The base directory is shown when the skill loads: e.g. `~/.claude/skills/pr-review`, or inside the
plugin cache when installed as a plugin.)

| ARG | Meaning |
|---|---|
| nothing | current branch vs its base (committed changes only) |
| `123` / `#123` / `!123` | PR or MR number; GitHub vs GitLab is detected from the `origin` remote |
| PR/MR URL | `https://github.com/<owner>/<repo>/pull/<n>` or `https://<gitlab-host>/<group>/<repo>/-/merge_requests/<n>` |
| branch name | that remote branch vs the base |

It fetches the PR/MR head with plain git (`pull/<n>/head` on GitHub, `merge-requests/<n>/head` on
GitLab) into `refs/pr-review/<n>` — it never checks out or changes the working tree. It prints a
JSON summary (`platform`, `title`, `description`, `base`, `head_sha`, `out_dir`, `note`, …) and
writes `change.diff`, `files.txt`, `stat.txt`, `commits.txt`, `meta.json` to `out_dir`.

- Title, description and the exact target branch come from `gh`/`glab` or `GITHUB_TOKEN` /
  `GITLAB_TOKEN` when available. Otherwise the target branch is guessed (closest fork point among
  `develop`, `main`, `master`, …) and `meta.note` says so — mention it in the report and re-run with
  `--base` if the user names another target.
- If the URL belongs to another repo than the current directory, the script stops: ask the user to
  run the review from a clone of that repo (or `cd` there if you know where it is).
- Empty diff → say so and stop. Very large diff (> ~3,000 lines) → review file by file, prioritise
  production code over generated/test data, and say what you only skimmed.
- `meta.merged` true → the PR/MR is already merged: still review it, say "post-merge review" in
  the summary, and word hygiene points as advice for next time.
- When done: `get_change.py --cleanup <n>` to delete the fetched ref.

**Reading code:** the working tree may be on another branch. Read full files at the PR version with
`git show <head_sha>:<path>` and search with `git grep <pattern> <head_sha>`.

## 2. Learn the repo's conventions (before judging)

The rules are generic; the repo decides the details. Spend a few quick commands on:

1. **Repo-provided review guidance** — if present, read and give it priority over the generic
   rules: `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `REVIEW.md`, `.claude/pr-review.md`,
   `.github/pull_request_template.md`, `.gitlab/merge_request_templates/*`, `docs/adr/*`, and
   AI-assistant rule files (`.cursor/rules/*.mdc`, `.cursorrules`, `.github/copilot-instructions.md`,
   `.windsurfrules`) — these often hold the team's architecture and testing conventions.
2. **Tooling** — linters/formatters (`.eslintrc*`, `.prettierrc`, `checkstyle`, `spotless`,
   `.editorconfig`, `ruff`/`flake8`, `golangci`), architecture checkers (`.importlinter`,
   ArchUnit, dependency-cruiser), test framework, coverage gates, CI workflow. Don't flag what
   CI enforces automatically.
3. **History** — `git log --oneline -20 <base>` for commit/branch/ticket format; that is the
   hygiene standard, not an imagined one.
4. **Neighbours** — for each changed file, look at 1–2 sibling files of the same kind (another
   controller, handler, component, migration, test). Match the reviewed code against *them*:
   naming, structure, base classes, error types, test style. Each stack file has a
   "Discover in the repo" checklist for this.
5. **Profiles** — read only the "Applies when" line at the top of each `profiles/*.md`. Load a
   profile only if this repo matches it exactly (same remote/org or package names — the same
   company is not enough); it adds project facts and project-only rules.

## 3. Load the rules

Always read `references/general.md`. Then, by changed files:

| Changed files | Read |
|---|---|
| `*.java`, `*.kt`, Spring / Maven / Gradle code | `references/java-spring.md` |
| Angular (`*.component.ts/html/scss`, `*.service.ts`, `*.pipe.ts`, `*.spec.ts` with TestBed) | `references/angular.md` |
| TypeScript / Node backend (NestJS, Express, Fastify: controllers, handlers, repositories, DTOs, e2e tests) | `references/typescript-backend.md` |
| DB migrations, SQL, build files (`pom.xml`, `package.json`, Gradle), config (properties, env, YAML, Helm/K8s), CI, Dockerfile, API/event docs, IdP role config, test scripts | `references/config-sql-build.md` |
| Anything else (Python, Go, C#, React, …) | `general.md` + your own expertise for that stack + the conventions found in step 2. Many stack rules transfer: e.g. for a Python/Go backend, skim `typescript-backend.md` for layering, DTO/contract, error and test rules |

A PR often touches several stacks (e.g. code + migration + build file): load every matching file.
Rules marked "If the project uses …" apply only when the repo actually does.

## 4. Review

Go through the diff file by file. Check each loaded rule against the change, and apply normal
engineering judgement for real bugs (null handling, wrong condition, off-by-one, missing
await/subscribe, race, transaction boundaries, money/time handling, security) even if no rule
covers them — correctness always outranks style.

Be precise:
- Only flag what is **in the diff** (added/modified lines). Untouched code only when the change
  breaks or duplicates it.
- **"Same bug elsewhere" is not a finding.** When a fix makes you suspect a similar issue in
  untouched code (a sibling regex, parser branch or handler), first check that the other path
  really needs the same treatment. It may not extract the same data, or it may be handled
  elsewhere. If it still looks real, mention it once under "Out of scope" as a question with no
  severity. Never make it a Blocker or Major, and never put it in the verdict.
- **Trace impact before stating it**: claims like "missing from the report", "wrong amount" or
  "user sees X" must be confirmed by following the value through its consumers at `head_sha`
  (`git grep` the callers). If you only checked the function's return value, state just that
  ("returns `[]` for …") and ask about the downstream effect.
- Every finding names a file and line and says **what to change**, with a short suggestion when
  it's obvious.
- **Verify before claiming**: "already exists", "unused", "not tested", "won't compile" must be
  checked with `git grep` / reading the file at `head_sha`. If you couldn't verify, say so.
- Repo conventions beat generic rules. Never flag something as wrong just because another project
  does it differently.
- Don't pad the report. A clean, small change gets "no blocking issues".
- When unsure, ask a question ("do we need …?", "why not reuse …?").

Severity:
- **Blocker** — bug, data/amount error, security issue, contract break, won't build, missing
  migration/permission/version bump, no tests for new logic. → Changes requested.
- **Major** — wrong layer, duplicated existing logic, missing error handling, performance problem on
  real volumes, test that can't fail.
- **Minor** — naming, typing, readability, small refactor.
- **Nit** — optional polish; keep few, group them.

## 5. Report

```
## Review: <PR/MR title or branch>

**Verdict:** ✅ Approve | 💬 Approve with comments | ❌ Changes requested
<one or two sentences: what the change does and the main concern, if any>
<if meta.note is set: one line saying what was assumed (target branch, no title/description)>

### Blockers
- `path/to/File.ext:123` — <problem>. <what to do>.
  ```suggestion
  <fixed code, only when short and obvious>
  ```

### Major
### Minor
### Nits

### Tests
<are new/changed behaviours covered? which cases are missing?>

### PR hygiene
<only if something is off, judged against the repo's own conventions>

### Out of scope
<optional questions about untouched code the change made you wonder about; no severity, max 2>
```

Omit empty sections. Order by severity, then file. Cap at ~25 findings; say how many minor ones
were left out.

Verdict: any Blocker → ❌ Changes requested. Majors but no Blocker → 💬 Approve with comments,
saying the Majors should be fixed before merging (use ❌ instead if they're many or the author must
rework the design). Only Minor/Nits → 💬. Nothing → ✅.
Write in the user's language if they wrote to you in another language; keep code identifiers as is.

## 6. Posting (only if asked)

Never post on GitHub/GitLab unless the user asked (`--post` or explicitly). Show the review first,
get a clear yes, save it to a file and post it as one comment:

| Platform | With CLI | With token only |
|---|---|---|
| GitHub | `gh pr review <n> --comment --body-file review.md` | `curl -H "Authorization: Bearer $GITHUB_TOKEN" -X POST https://api.github.com/repos/<owner>/<repo>/issues/<n>/comments -d @body.json` (`{"body": "<review>"}`) |
| GitLab | `glab mr note <n> --message "$(cat review.md)"` | `curl -H "PRIVATE-TOKEN: $GITLAB_TOKEN" -X POST "https://<host>/api/v4/projects/<url-encoded group%2Frepo>/merge_requests/<n>/notes" --data-urlencode "body@review.md"` |

No CLI and no token → say so and give the user the review to paste. Confirm what was posted and
where.

## Updating the knowledge

The rules were distilled from exported review comments (see the plugin's `tools/` folder:
`export_reviews.py` exports GitHub review comments). To learn from new reviews, export them and ask
Claude to merge recurring new patterns into `references/` (generic) or a profile (project-only).
