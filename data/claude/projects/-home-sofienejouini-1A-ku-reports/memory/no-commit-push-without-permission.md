---
name: no-commit-push-without-permission
description: Never git commit or git push unless the user explicitly says to in that turn
metadata:
  node_type: memory
  type: feedback
  originSessionId: c6977e3c-8659-46d8-b18b-a786e5cb284e
  modified: 2026-10-27T14:20:01.968Z
---

Never run `git commit` or `git push` without the user's explicit permission. Vague wording like "refresh the git" is not permission: ask first.

**Why:** The user asked to "refresh the git"; I took it as permission to commit and push to origin/main, and they objected.

**How to apply:** Prepare the changes (edit files, `git add` only if asked), show what would be committed or pushed, and wait for an explicit "commit" or "push". Ask separately for each action, even if the user approved a similar one earlier.
