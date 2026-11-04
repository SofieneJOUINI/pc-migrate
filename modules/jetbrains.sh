# JetBrains IDE settings from the most recently used IDE config directory.
# Restored under the same directory name, so a newer IDE offers to import it on first start.

MODULE_DESC[jetbrains]="IntelliJ keymaps, code styles, live templates, colors, options, plugin list"

JB_DIRS=(options keymaps codestyles templates colors fileTemplates inspection quicklists)
JB_SKIP=(recentProjects.xml recentSolutions.xml security.xml updates.xml usage.statistics.xml
         actionSummary.xml window.state.xml other.xml trusted-paths.xml features.usage.statistics.xml
         log-categories.xml github.xml)

jetbrains_export() {
  local latest name d x ex=()
  latest=$(ls -td "$HOME"/.config/JetBrains/*/ 2>/dev/null | head -1)
  [[ -n $latest ]] || return 0
  name=$(basename "$latest")
  rm -rf "$DATA_DIR/jetbrains"
  d=$DATA_DIR/jetbrains/$name
  for x in "${JB_SKIP[@]}"; do ex+=(--exclude="$x"); done
  for x in "${JB_DIRS[@]}"; do grab "$latest$x" "$d/$x" "${ex[@]}"; done
  [[ -f $latest/idea64.vmoptions ]] && grab "$latest/idea64.vmoptions" "$d/idea64.vmoptions"
  if [[ -d $HOME/.local/share/JetBrains/$name ]]; then
    ls "$HOME/.local/share/JetBrains/$name" > "$DATA_DIR/jetbrains/plugins.txt"
    ok "$(wc -l < "$DATA_DIR/jetbrains/plugins.txt") plugins listed"
  fi
}

jetbrains_install() {
  local d
  for d in "$DATA_DIR"/jetbrains/*/; do
    [[ -d $d ]] || continue
    put "${d%/}" "$HOME/.config/JetBrains/$(basename "$d")"
  done
  if [[ -f $DATA_DIR/jetbrains/plugins.txt ]]; then
    info "reinstall these from Settings > Plugins: $(paste -sd, "$DATA_DIR/jetbrains/plugins.txt" | sed 's/,/, /g')"
  fi
}
