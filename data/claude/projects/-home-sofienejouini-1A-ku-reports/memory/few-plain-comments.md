---
name: few-plain-comments
description: "Keep comments rare and in plain readable words, without symbols like | ` -> or ctx.params"
metadata:
  node_type: memory
  type: feedback
  originSessionId: c6977e3c-8659-46d8-b18b-a786e5cb284e
  modified: 2026-10-27T14:22:37.712Z
---

Add a comment only when it is needed. Write it as a plain sentence a non-developer can read, without special characters such as `|`, backticks, arrows or code references.

**Why:** The user found the YAML configs over-commented and hard to read, for example `select: one  # all | one (exactly one file must match) | shortest`.

**How to apply:** For config files and templates, leave self-explanatory keys uncommented. Keep a short plain comment only where it tells the reader something they need, and point to the README for the details of each key.
