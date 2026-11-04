#!/usr/bin/env python3
"""Collect the change to review (GitHub PR, GitLab MR, branch or current branch) without touching
the working tree.

Usage (run from inside the repo):
  get_change.py                      current branch vs its base
  get_change.py 1773                 PR (GitHub) or MR (GitLab) number, platform from the origin remote
  get_change.py <PR or MR URL>       https://github.com/o/r/pull/12 or https://gitlab.x/g/r/-/merge_requests/12
  get_change.py feature/ADAD-123     a remote branch
  options: --base <branch>   force the target branch
           --out <dir>       where to write the files (default: a temp dir)

Works with plain git over the existing remote (SSH or HTTPS). If available, it also uses
gh / glab or the GITHUB_TOKEN / GITLAB_TOKEN env vars to get the title, description and target
branch; without them it falls back to the remote's default branch.

Writes: change.diff, stat.txt, commits.txt, files.txt, meta.json and prints a summary.
Fetched PR/MR heads go to refs/pr-review/<n> (not a branch); remove with --cleanup <n>.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request


def git(*args, check=True):
    r = subprocess.run(["git", *args], capture_output=True, text=True)
    if check and r.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed:\n{r.stderr.strip()}")
    return r.stdout.strip()


def ref_exists(ref):
    return subprocess.run(["git", "rev-parse", "--verify", "-q", ref], capture_output=True).returncode == 0


def parse_remote(url):
    """git@host:group/sub/repo.git or https://host/group/repo(.git) -> (host, path)."""
    m = re.match(r"^(?:ssh://)?[^@/]+@([^:/]+)(?::\d+)?[:/](.+?)(?:\.git)?/?$", url) \
        or re.match(r"^https?://(?:[^@/]+@)?([^/]+)/(.+?)(?:\.git)?/?$", url)
    if not m:
        sys.exit(f"Cannot parse remote URL: {url}")
    return m.group(1).lower(), m.group(2)


def platform_of(host):
    if host == "github.com" or "github" in host:
        return "github"
    if "gitlab" in host:
        return "gitlab"
    # self-hosted with another name: probe for MR refs
    out = subprocess.run(["git", "ls-remote", "origin", "refs/merge-requests/1/head"], capture_output=True, text=True)
    return "gitlab" if out.stdout.strip() else "github"


def http_json(url, headers):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as r:
            return json.load(r)
    except Exception as e:  # metadata is optional
        print(f"  (could not read metadata from API: {e})", file=sys.stderr)
        return None


def cli_json(cmd):
    if not shutil.which(cmd[0]):
        return None
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        return None
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return None


def pr_metadata(platform, host, path, number):
    """Return dict(title, description, base, source, url) or None."""
    if platform == "github":
        d = cli_json(["gh", "pr", "view", str(number), "--repo", path,
                      "--json", "title,body,baseRefName,headRefName,url"])
        if d:
            return {"title": d["title"], "description": d["body"], "base": d["baseRefName"],
                    "source": d["headRefName"], "url": d["url"]}
        token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
        if token:
            d = http_json(f"https://api.github.com/repos/{path}/pulls/{number}",
                          {"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"})
            if d:
                return {"title": d["title"], "description": d.get("body") or "", "base": d["base"]["ref"],
                        "source": d["head"]["ref"], "url": d["html_url"]}
    else:
        d = cli_json(["glab", "mr", "view", str(number), "--repo", f"{host}/{path}", "--output", "json"])
        if d:
            return {"title": d["title"], "description": d.get("description") or "", "base": d["target_branch"],
                    "source": d["source_branch"], "url": d.get("web_url")}
        token = os.environ.get("GITLAB_TOKEN")
        if token:
            pid = urllib.parse.quote(path, safe="")
            d = http_json(f"https://{host}/api/v4/projects/{pid}/merge_requests/{number}", {"PRIVATE-TOKEN": token})
            if d:
                return {"title": d["title"], "description": d.get("description") or "", "base": d["target_branch"],
                        "source": d["source_branch"], "url": d.get("web_url")}
    return None


def default_branch():
    head = git("symbolic-ref", "--short", "refs/remotes/origin/HEAD", check=False)
    if head:
        return head.split("/", 1)[1]
    for b in ("develop", "main", "master"):
        if ref_exists(f"refs/remotes/origin/{b}"):
            return b
    sys.exit("Cannot determine the base branch, pass --base <branch>")


def is_ancestor(a, b):
    return subprocess.run(["git", "merge-base", "--is-ancestor", a, b], capture_output=True).returncode == 0


def guess_base(head_ref):
    """Without metadata: the usual target branch whose fork point with the head is the most recent."""
    best, best_time = None, -1
    for b in ("develop", "main", "master", "staging", "dev"):
        ref = f"refs/remotes/origin/{b}"
        if not ref_exists(ref):
            continue
        mb = git("merge-base", ref, head_ref, check=False)
        if not mb:
            continue
        t = int(git("show", "-s", "--format=%ct", mb))
        if t > best_time:
            best, best_time = b, t
    return best or default_branch()


def merged_range(base_ref, head_ref):
    """If head is already merged into base, return the start of the PR/MR's own changes."""
    if not is_ancestor(head_ref, base_ref):
        return None
    # the merge commit on base that brought the head in: its first parent is base before the merge
    for c in git("rev-list", "--ancestry-path", "--merges", "--reverse", f"{head_ref}..{base_ref}").splitlines():
        parents = git("show", "-s", "--format=%P", c).split()
        if len(parents) > 1 and head_ref and is_ancestor(head_ref, parents[1]) and not is_ancestor(head_ref, parents[0]):
            return git("merge-base", parents[0], head_ref)
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("target", nargs="?", help="PR/MR number or URL, branch, or nothing for the current branch")
    ap.add_argument("--base", help="target branch to diff against")
    ap.add_argument("--out", help="output directory")
    ap.add_argument("--cleanup", metavar="N", help="delete refs/pr-review/N and exit")
    args = ap.parse_args()

    os.chdir(git("rev-parse", "--show-toplevel"))
    if args.cleanup:
        git("update-ref", "-d", f"refs/pr-review/{args.cleanup}", check=False)
        print(f"removed refs/pr-review/{args.cleanup}")
        return

    host, path = parse_remote(git("remote", "get-url", "origin"))
    platform = platform_of(host)
    meta = {"platform": platform, "repo": f"{host}/{path}", "kind": None}
    t = args.target
    number = None

    if t and re.match(r"^https?://", t):
        u = urllib.parse.urlparse(t)
        m = re.match(r"^/(.+?)/(?:-/)?(pull|merge_requests)/(\d+)", u.path)
        if not m:
            sys.exit(f"Not a PR/MR URL: {t}")
        if m.group(1).lower() != path.lower() or u.hostname.lower() != host:
            sys.exit(f"The URL is for {u.hostname}/{m.group(1)} but this repo's origin is {host}/{path}.\n"
                     "Run the review from a clone of that repo.")
        platform = "github" if m.group(2) == "pull" else "gitlab"
        meta["platform"] = platform
        number = m.group(3)
    elif t and re.fullmatch(r"[#!]?\d+", t):
        number = t.lstrip("#!")

    git("fetch", "-q", "origin")
    if number:
        meta["kind"] = "pull_request" if platform == "github" else "merge_request"
        meta["number"] = int(number)
        src = f"pull/{number}/head" if platform == "github" else f"merge-requests/{number}/head"
        head_ref = f"refs/pr-review/{number}"
        r = subprocess.run(["git", "fetch", "-q", "-f", "origin", f"{src}:{head_ref}"], capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit(f"Could not fetch {src} from origin ({meta['repo']}). Check the number and your access.\n{r.stderr.strip()}")
        info = pr_metadata(platform, host, path, number)
        if info:
            meta.update(info)
        base = args.base or (info or {}).get("base") or guess_base(head_ref)
        if not info and not args.base:
            meta["note"] = (f"No gh/glab or API token: title/description unknown and target branch guessed as "
                            f"'{base}' (closest fork point). Use --base if the PR/MR targets another branch.")
    elif t:
        meta["kind"] = "branch"
        head_ref = f"refs/remotes/origin/{t}" if ref_exists(f"refs/remotes/origin/{t}") else t
        if not ref_exists(head_ref):
            sys.exit(f"Branch not found: {t}")
        meta["source"] = t
        base = args.base or default_branch()
    else:
        meta["kind"] = "current_branch"
        head_ref = "HEAD"
        meta["source"] = git("rev-parse", "--abbrev-ref", "HEAD")
        base = args.base or default_branch()
        if git("status", "--porcelain"):
            meta["note"] = "Working tree has uncommitted changes; they are NOT part of the diff (committed changes only)."

    base_ref = f"refs/remotes/origin/{base}" if ref_exists(f"refs/remotes/origin/{base}") else base
    if not ref_exists(base_ref):
        sys.exit(f"Base branch not found: {base}")
    merge_base = git("merge-base", base_ref, head_ref)
    if number and merge_base == git("rev-parse", head_ref):
        start = merged_range(base_ref, head_ref)
        if start:
            merge_base = start
            meta["merged"] = True
            meta["note"] = (meta.get("note", "") + " This PR/MR is already merged into "
                            f"'{base}'; showing its own changes as they were merged.").strip()
        else:
            meta["merged"] = True
            meta["note"] = (meta.get("note", "") + f" This PR/MR is already contained in '{base}' and its changes "
                            "can't be isolated (fast-forward, or it targets another branch). Ask the user for the "
                            "target branch (--base) or set GITHUB_TOKEN / GITLAB_TOKEN.").strip()
    meta.update({"base": base, "head_ref": head_ref, "head_sha": git("rev-parse", head_ref), "merge_base": merge_base})

    out = args.out or tempfile.mkdtemp(prefix="pr-review-")
    os.makedirs(out, exist_ok=True)
    rng = f"{merge_base}..{head_ref}"
    files = {
        "change.diff": git("diff", "--find-renames", rng),
        "stat.txt": git("diff", "--stat", rng),
        "files.txt": git("diff", "--name-status", "--find-renames", rng),
        "commits.txt": git("log", "--no-merges", "--format=%h %an %ad %s", "--date=short", rng),
    }
    for name, content in files.items():
        with open(os.path.join(out, name), "w") as f:
            f.write(content + "\n")
    with open(os.path.join(out, "meta.json"), "w") as f:
        json.dump(meta, f, indent=2)

    n_files = len([l for l in files["files.txt"].splitlines() if l.strip()])
    print(json.dumps({**meta, "out_dir": out, "files_changed": n_files,
                      "diff_lines": files["change.diff"].count("\n")}, indent=2))
    if not files["change.diff"].strip():
        print("EMPTY DIFF: nothing to review against this base.", file=sys.stderr)


if __name__ == "__main__":
    main()
