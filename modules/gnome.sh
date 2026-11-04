# GNOME settings trees listed in config/dconf.txt (shortcuts, dock, appearance, input,
# terminal profiles) and user-installed shell extensions.

MODULE_DESC[gnome]="GNOME shortcuts, dock favourites, appearance, keyboard/touchpad, terminal profiles, extensions"

gnome_export() {
  has dconf || { warn "dconf not found, skipping"; return 0; }
  local d=$DATA_DIR/gnome p name dump
  rm -rf "$d"; mkdir -p "$d/dconf"
  while read -r p; do
    name=$(tr '/' '-' <<<"${p#/}"); name=${name%-}
    dump=$(dconf dump "$p")
    [[ -n $dump ]] || continue
    printf '# dconf-path: %s\n%s\n' "$p" "$dump" > "$d/dconf/$name.ini"
    ok "$p"
  done < <(config_list dconf)
  grab "$HOME/.local/share/gnome-shell/extensions" "$d/extensions"
}

gnome_install() {
  local d=$DATA_DIR/gnome f p
  put "$d/extensions" "$HOME/.local/share/gnome-shell/extensions"
  has dconf || { warn "dconf not found (not a GNOME desktop?), skipping settings"; return 0; }
  for f in "$d"/dconf/*.ini; do
    [[ -e $f ]] || continue
    p=$(sed -n '1s/^# dconf-path: //p' "$f")
    if [[ $DRY_RUN == 1 ]]; then info "[dry-run] dconf load $p < $(basename "$f")"; continue; fi
    mkdir -p "$BACKUP_DIR/dconf"
    dconf dump "$p" > "$BACKUP_DIR/dconf/$(basename "$f")" 2>/dev/null || true
    dconf load "$p" < "$f" && ok "$p"
  done
  info "log out and back in for shell/extension changes to take effect"
}
