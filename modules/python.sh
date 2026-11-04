# pip --user packages and uv tools.

MODULE_DESC[python]="pip --user packages, uv tools"

python_export() {
  local d=$DATA_DIR/python
  mkdir -p "$d"
  if has pip3; then
    pip3 list --user --not-required --format=freeze 2>/dev/null | cut -d= -f1 | sort -u > "$d/pip-user.txt"
    ok "pip --user: $(wc -l < "$d/pip-user.txt") top-level packages"
  fi
  if has uv; then
    uv tool list 2>/dev/null | awk '/^[^- ]/ {print $1}' > "$d/uv-tools.txt"
    ok "uv tools: $(paste -sd' ' "$d/uv-tools.txt")"
  fi
}

python_install() {
  local d=$DATA_DIR/python t
  if [[ -s $d/uv-tools.txt ]]; then
    need_pkgs curl
    has uv || run bash -c 'curl -LsSf https://astral.sh/uv/install.sh | INSTALLER_NO_MODIFY_PATH=1 sh'
    while read -r t; do run "$HOME/.local/bin/uv" tool install "$t" || warn "uv tool $t failed"; done < <(lines "$d/uv-tools.txt")
  fi
  if [[ -s $d/pip-user.txt ]]; then
    # Ubuntu 23.04+ refuses user installs into the system Python (PEP 668).
    run pip3 install --user $(lines "$d/pip-user.txt") ||
      warn "pip refused (PEP 668?). Prefer 'uv tool install' for CLIs, or rerun with --break-system-packages"
  fi
}
