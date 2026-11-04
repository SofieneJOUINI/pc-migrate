# Per-app config listed in config/apps.txt, plus custom launchers (.desktop files).

MODULE_DESC[apps]="app configs from config/apps.txt (flameshot, keepassxc, htop, sublime, ...), launchers"

apps_export() {
  local d=$DATA_DIR/apps p f n=0
  rm -rf "$d"; mkdir -p "$d"
  while read -r p; do grab "$HOME/$p" "$d/home/$p"; done < <(config_list apps)
  for f in "$HOME"/.local/share/applications/*.desktop; do
    [[ -f $f ]] || continue
    mkdir -p "$d/home/.local/share/applications"; cp -p "$f" "$d/home/.local/share/applications/"; n=$((n+1))
  done
  if ((n)); then ok "~/.local/share/applications: $n launchers"; fi
}

apps_install() {
  local p
  while read -r p; do put "$DATA_DIR/apps/home/$p" "$HOME/$p"; done < <(config_list apps)
  put "$DATA_DIR/apps/home/.local/share/applications" "$HOME/.local/share/applications"
}
