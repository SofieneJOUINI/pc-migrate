# nvm Node versions, the default alias, and global npm packages.

MODULE_DESC[node]="nvm + every Node version + default + global npm packages"

NVM_VERSION=v0.40.3

node_export() {
  local d=$DATA_DIR/node nvm_dir=${NVM_DIR:-$HOME/.nvm}
  [[ -d $nvm_dir/versions/node ]] || return 0
  mkdir -p "$d"
  ls "$nvm_dir/versions/node" | sort -V > "$d/versions.txt"
  cat "$nvm_dir/alias/default" > "$d/default.txt" 2>/dev/null || true
  ok "nvm: $(paste -sd' ' "$d/versions.txt") (default $(cat "$d/default.txt" 2>/dev/null))"
  # shellcheck disable=SC1091
  ( set +u; . "$nvm_dir/nvm.sh"; nvm use default >/dev/null
    npm ls -g --depth=0 --json 2>/dev/null | jq -r '.dependencies // {} | to_entries[] | .key' ) |
    grep -vxE 'npm|corepack' > "$d/npm-global.txt" || true
  ok "npm global: $(paste -sd' ' "$d/npm-global.txt")"
}

node_install() {
  local d=$DATA_DIR/node v
  [[ -f $d/versions.txt ]] || return 0
  export NVM_DIR=$HOME/.nvm
  need_pkgs curl
  if [[ ! -s $NVM_DIR/nvm.sh ]]; then
    # PROFILE=/dev/null: our .bashrc already loads nvm, don't let the installer edit it.
    run bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | PROFILE=/dev/null bash"
  fi
  [[ $DRY_RUN == 1 ]] && { info "[dry-run] nvm install $(paste -sd' ' "$d/versions.txt"); npm i -g $(paste -sd' ' "$d/npm-global.txt")"; return 0; }
  # shellcheck disable=SC1091
  set +u; . "$NVM_DIR/nvm.sh"
  while read -r v; do nvm install "$v" >/dev/null && ok "node $v"; done < <(lines "$d/versions.txt")
  [[ -s $d/default.txt ]] && nvm alias default "$(cat "$d/default.txt")" >/dev/null
  nvm use default >/dev/null
  [[ -s $d/npm-global.txt ]] && npm install -g $(lines "$d/npm-global.txt") && ok "npm global packages"
  set -u
}
