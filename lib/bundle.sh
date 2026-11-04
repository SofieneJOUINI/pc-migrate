# The private bundle: an AES-256 gpg archive of everything that must not go to git
# (keys, credentials, password database, large files).

BUNDLE_LIST="$CONFIG_DIR/bundle.txt"

bundle_pack() {
  local out=${1:-$HOME/pc-migrate-bundle-$(date +%Y%m%d).tar.gz.gpg} paths=() p missing=()
  has gpg || die "gpg is required"
  while read -r p; do
    p=${p%/}
    if [[ -e $HOME/$p ]]; then paths+=("$p"); else missing+=("$p"); fi
  done < <(lines "$BUNDLE_LIST")
  ((${#missing[@]})) && info "not on this machine, skipped: ${missing[*]}"
  log "packing ${#paths[@]} paths"
  printf '    %s\n' "${paths[@]}"
  du -shc "${paths[@]/#/$HOME/}" 2>/dev/null | tail -1 | awk '{print "    total before compression: " $1}'
  # shellcheck disable=SC2086
  tar -czf - -C "$HOME" "${paths[@]}" |
    gpg --symmetric --cipher-algo AES256 ${GPG_OPTS:-} -o "$out"
  chmod 600 "$out"
  ok "wrote $(tilde "$out") ($(du -h "$out" | cut -f1)). Copy it by USB stick or scp, never to git."
  info "Forget the passphrase and this file is useless. Keep it somewhere safe (e.g. KeePassXC)."
}

bundle_unpack() {
  local in=${1:?usage: migrate bundle unpack FILE} tmp
  [[ -f $in ]] || die "no such file: $in"
  tmp=$(mktemp -d); chmod 700 "$tmp"
  # shellcheck disable=SC2086
  gpg --decrypt --quiet ${GPG_OPTS:-} -o "$tmp/.bundle.tgz" "$in" || { rm -rf "$tmp"; die "decryption failed (wrong passphrase?)"; }
  tar -xzf "$tmp/.bundle.tgz" -C "$tmp" && rm "$tmp/.bundle.tgz"
  chmod --reference="$HOME" "$tmp"   # rsync copies the top dir's mode onto ~
  log "restoring into ~ (anything replaced goes to $(tilde "$BACKUP_DIR"))"
  (cd "$tmp" && find . -mindepth 1 -maxdepth 2 | sed 's|^\./|    |' | sort | head -40)
  rsync -a --backup --backup-dir="$BACKUP_DIR" "$tmp/" "$HOME/"
  rm -rf "$tmp"
  [[ -d $HOME/.ssh ]] && { chmod 700 "$HOME/.ssh"; find "$HOME/.ssh" -type f ! -name '*.pub' -exec chmod 600 {} +; }
  [[ -d $HOME/keys ]] && find "$HOME/keys" -type f -exec chmod 600 {} +
  [[ -d $HOME/.local/share/fonts ]] && has fc-cache && fc-cache -f >/dev/null
  ok "bundle restored"
}
