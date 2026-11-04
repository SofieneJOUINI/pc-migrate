#!/usr/bin/env python3
"""Look for secrets that should never be committed.

    scan.py PATH...        scan files and directories
    scan.py --staged       scan what is staged in git (used by the pre-commit hook)

Exits 1 when anything is found.
"""
import os
import re
import subprocess
import sys

PATTERNS = [
    ("private key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("AWS access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("GitHub token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b")),
    ("GitLab token", re.compile(r"\bglpat-[A-Za-z0-9_-]{20,}\b")),
    ("Anthropic key", re.compile(r"\bsk-ant-[A-Za-z0-9_-]{20,}\b")),
    ("OpenAI key", re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9]{32,}\b")),
    ("Slack token", re.compile(r"\bxox[abposr]-[A-Za-z0-9-]{10,}\b")),
    ("JWT", re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")),
    # KEY=value with no spaces (shell, .properties, .env), unquoted literal
    ("hard-coded secret", re.compile(
        r"""(?i)\b[\w.-]*(?:password|passwd|secret|token|api_?key)[\w-]*=(?![$<{%(]|os\.|process\.|true\b|false\b|null\b|password\b)[^\s"',;)]{6,}""")),
    # key: "value" / key = 'value' (code, JSON, YAML), quoted literal
    ("hard-coded secret", re.compile(
        r"""(?i)\b[\w.-]*(?:password|passwd|secret|token|api_?key)[\w-]*["']?\s*[:=]\s*["'](?![$<{%])[^"'\s]{6,}["']""")),
    # key: value at the start of a YAML line, unquoted literal
    ("hard-coded secret", re.compile(
        r"""(?i)^\s*[\w.-]*(?:password|passwd|secret|token|api_?key)[\w-]*:\s+(?![$<{%"'|>])[^\s#]{6,}\s*$""")),
]
SKIP_DIRS = {".git", "node_modules"}
MAX_BYTES = 2_000_000


def scan_text(name, text):
    hits = []
    for lineno, line in enumerate(text.splitlines(), 1):
        if "pc-migrate: allow" in line:
            continue
        for label, rx in PATTERNS:
            if rx.search(line):
                hits.append((name, lineno, label))
                break
    return hits


def read(path):
    try:
        if os.path.getsize(path) > MAX_BYTES:
            return None
        with open(path, "rb") as f:
            data = f.read()
        if b"\0" in data[:4096]:
            return None
        return data.decode("utf-8", "replace")
    except OSError:
        return None


def walk(paths):
    for p in paths:
        if os.path.isdir(p):
            for root, dirs, files in os.walk(p):
                dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
                for f in files:
                    yield os.path.join(root, f)
        elif os.path.isfile(p):
            yield p


def staged():
    names = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM", "-z"],
        capture_output=True, check=True,
    ).stdout.decode().split("\0")
    for n in filter(None, names):
        blob = subprocess.run(["git", "show", f":{n}"], capture_output=True).stdout
        if b"\0" not in blob[:4096] and len(blob) <= MAX_BYTES:
            yield n, blob.decode("utf-8", "replace")


def main():
    args = sys.argv[1:]
    if args == ["--staged"]:
        items = staged()
    else:
        items = ((p, read(p)) for p in walk(args or ["."]))
    hits = []
    for name, text in items:
        if text is not None:
            hits += scan_text(name, text)
    for name, lineno, label in hits:
        print(f"{name}:{lineno}: {label}")
    if hits:
        print(
            f"\n{len(hits)} possible secret(s). Move them to the bundle (see bundle.txt) or,"
            " if a line is safe, add a 'pc-migrate: allow' comment to it.",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
