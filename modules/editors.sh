# VS Code and Cursor: settings, keybindings, snippets, MCP config, extensions.

MODULE_DESC[editors]="VS Code + Cursor settings, keybindings, snippets, mcp.json, extensions"

# cli-name:config-dir
EDITORS=(code:Code cursor:Cursor)
EDITOR_FILES=(settings.json keybindings.json mcp.json tasks.json snippets)

editors_export() {
  local e cli dir f
  for e in "${EDITORS[@]}"; do
    cli=${e%%:*} dir=${e#*:}
    [[ -d $HOME/.config/$dir/User ]] || continue
    for f in "${EDITOR_FILES[@]}"; do
      grab "$HOME/.config/$dir/User/$f" "$DATA_DIR/editors/$cli/$f"
    done
    if has "$cli"; then
      "$cli" --list-extensions 2>/dev/null | sort > "$DATA_DIR/editors/$cli/extensions.txt"
      ok "$cli: $(wc -l < "$DATA_DIR/editors/$cli/extensions.txt") extensions"
    fi
  done
}

editors_install() {
  local e cli dir f ext
  for e in "${EDITORS[@]}"; do
    cli=${e%%:*} dir=${e#*:}
    [[ -d $DATA_DIR/editors/$cli ]] || continue
    for f in "${EDITOR_FILES[@]}"; do
      put "$DATA_DIR/editors/$cli/$f" "$HOME/.config/$dir/User/$f"
    done
    if ! has "$cli"; then
      warn "$cli is not installed: install it (packages module), then rerun './migrate install editors'"
      continue
    fi
    local installed; installed=$("$cli" --list-extensions 2>/dev/null)
    while read -r ext; do
      grep -qixF "$ext" <<<"$installed" && continue
      run "$cli" --install-extension "$ext" >/dev/null && ok "$cli: $ext" || warn "$cli: $ext failed"
    done < <(lines "$DATA_DIR/editors/$cli/extensions.txt")
  done
}
