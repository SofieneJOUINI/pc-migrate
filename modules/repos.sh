# Every git clone under $HOME (except config/repos-ignore.txt): recorded with its remote
# and branch, recloned on install. Export also warns about work that exists only here.

MODULE_DESC[repos]="every git clone under ~: recloned to the same path, with unpushed-work warnings"

REPO_SEARCH_DEPTH=4

repos_export() {
  local d=$DATA_DIR/repos prune=() p g dir url branch dirty ahead risky=0
  mkdir -p "$d"
  while read -r p; do prune+=(-path "$HOME/$p" -o); done < <(config_list repos-ignore)
  echo "# path<TAB>remote<TAB>branch" > "$d/repos.tsv"
  while read -r g; do
    dir=${g%/.git}
    url=$(git -C "$dir" remote get-url origin 2>/dev/null) || { warn "$(tilde "$dir"): no remote, it exists only here"; ((risky++)) || true; continue; }
    branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo HEAD)
    printf '%s\t%s\t%s\n' "${dir#$HOME/}" "$url" "$branch" >> "$d/repos.tsv"
    dirty=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l)
    # Commits that exist on no remote branch at all would be lost with this disk.
    ahead=$(git -C "$dir" rev-list --count HEAD --not --remotes 2>/dev/null || echo 0)
    if ((dirty || ahead)); then
      warn "$(tilde "$dir") [$branch]: ${dirty} uncommitted, ${ahead} unpushed"
      ((risky++)) || true
    fi
  done < <(find "$HOME" -maxdepth "$REPO_SEARCH_DEPTH" \( "${prune[@]}" -name node_modules \) -prune \
             -o -name .git -type d -prune -print 2>/dev/null | sort)
  ok "$(lines "$d/repos.tsv" | wc -l) repositories recorded"
  ((risky)) && warn "$risky repo(s) have work that only exists on this disk: commit and push before you wipe it"
  return 0
}

repos_install() {
  local path url branch
  while IFS=$'\t' read -r path url branch; do
    if [[ -d $HOME/$path/.git ]]; then info "~/$path already cloned"; continue; fi
    [[ $branch == HEAD ]] && branch=
    run git clone ${branch:+--branch "$branch"} "$url" "$HOME/$path" >/dev/null 2>&1 &&
      ok "~/$path" || warn "~/$path: clone of $url failed (SSH key restored? run 'bundle unpack' first)"
  done < <(lines "$DATA_DIR/repos/repos.tsv")
}
