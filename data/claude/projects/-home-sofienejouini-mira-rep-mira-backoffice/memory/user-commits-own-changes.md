---
name: user-commits-own-changes
description: "User makes their own git commits and pushes; leave changes uncommitted and don't offer to commit or push"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 55b8dd7b-9206-49c1-90ba-e89d7d1adf3a
  modified: 2026-10-28T13:21:06.527Z
---

Leave changes in the working tree. Don't commit, push, or offer to.

**Why:** The user said "no I commit myself" when asked whether to fold a refactor into an existing commit, and declined a push after a rebase.

**How to apply:** After making edits, report what changed and stop. Rebases or other history work are fine when asked, but never commit or push on your own initiative.
