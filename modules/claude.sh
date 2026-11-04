# Claude Code: settings, skills, agents, commands, keybindings, per-project memory.
# Credentials are left out on purpose: sign in again on the new machine.

MODULE_DESC[claude]="Claude Code settings, skills, agents, commands, keybindings, project memory"

CLAUDE_ITEMS=(settings.json CLAUDE.md keybindings.json statusline.sh agents commands skills)

claude_export() {
  local c=$HOME/.claude d=$DATA_DIR/claude x mem
  [[ -d $c ]] || return 0
  for x in "${CLAUDE_ITEMS[@]}"; do grab "$c/$x" "$d/$x" --exclude=synced; done
  rm -rf "$d/projects"
  for mem in "$c"/projects/*/memory; do
    [[ -d $mem && $mem != *scratch-workspaces* ]] || continue
    grab "$mem" "$d/projects/$(basename "$(dirname "$mem")")/memory"
  done
}

claude_install() {
  local d=$DATA_DIR/claude x
  [[ -d $d ]] || return 0
  for x in "${CLAUDE_ITEMS[@]}"; do put "$d/$x" "$HOME/.claude/$x"; done
  put "$d/projects" "$HOME/.claude/projects"
  has claude || info "install Claude Code: curl -fsSL https://claude.ai/install.sh | bash"
  info "run 'claude' and sign in; plugins in settings.json reinstall themselves"
}
