---
name: user-owns-commits-and-pushes
description: "Never git commit, create remote repos, or push; the user does all of that themselves"
metadata:
  node_type: memory
  type: feedback
  originSessionId: dd12e7f8-40dd-4348-b2cb-dde96541e588
  modified: 2026-11-04T13:35:41.980Z
---

Don't run `git commit`, create GitHub/GitLab repos, or `git push`. Leave changes in the working tree and let the user do it.

**Why:** The user said committing, creating the repo and pushing is their responsibility (pc-migrate project, 2026-11-04).

**How to apply:** Stop once the files are written and tested. Tell the user the work is ready to commit; don't offer commit/push buttons or run them. `git init` and local config like `core.hooksPath` are fine.
