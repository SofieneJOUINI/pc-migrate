# Vim and Neovim, restored exactly: config, plugin managers, every plugin pinned to its
# commit, Mason tools at their versions, Treesitter parsers, and the same Neovim release.
#
# data/vim/
#   vim/.vimrc .ideavimrc .vim/    config (plugged/ and undodir/ left out)
#   vim/plugins.lock               name, url, commit of each vim-plug plugin
#   nvim/config/                   copy of ~/.config/nvim
#   nvim/config.git                remote, branch, commit of ~/.config/nvim
#   nvim/version                   Neovim release, e.g. v0.12.4
#   nvim/plugins.lock              path under ~/.local/share/nvim, url, commit
#   nvim/mason.lock                Mason package, version
#   nvim/treesitter.txt            installed parsers

MODULE_DESC[vim]="vim + neovim: config, vim-plug/packer, every plugin at its exact commit, Mason tools, Treesitter parsers, nvim release"

NVIM_DATA=$HOME/.local/share/nvim
VIM_HOME_FILES=(.vimrc .ideavimrc)

# git_lock DIR: "name<TAB>url<TAB>commit" for every git checkout directly under DIR.
git_lock() {
  local p
  for p in "$1"/*/; do
    [[ -e $p.git ]] || continue
    printf '%s\t%s\t%s\n' "$(basename "$p")" "$(git -C "$p" remote get-url origin 2>/dev/null)" "$(git -C "$p" rev-parse HEAD)"
  done
}

# clone_at URL DIR COMMIT: clone DIR if missing, then check out COMMIT.
clone_at() {
  local url=$1 dir=$2 commit=$3
  if [[ ! -e $dir/.git ]]; then
    run git clone -q --filter=blob:none "$url" "$dir" || { warn "clone failed: $url"; return 1; }
  fi
  run git -C "$dir" -c advice.detachedHead=false checkout -q "$commit" 2>/dev/null && return 0
  run git -C "$dir" fetch -q origin "$commit" &&
    run git -C "$dir" -c advice.detachedHead=false checkout -q "$commit" ||
    warn "$(basename "$dir"): commit ${commit:0:9} not found, left on the default branch"
}

vim_export() {
  local d=$DATA_DIR/vim f p kind id
  rm -rf "$d"; mkdir -p "$d/vim" "$d/nvim"

  for f in "${VIM_HOME_FILES[@]}"; do grab "$HOME/$f" "$d/vim/$f"; done
  grab "$HOME/.vim" "$d/vim/.vim" --exclude=plugged --exclude=undodir --exclude=swap \
    --exclude=backup --exclude=view --exclude=.netrwhist
  if [[ -d $HOME/.vim/plugged ]]; then
    git_lock "$HOME/.vim/plugged" > "$d/vim/plugins.lock"
    ok "vim plugins: $(cut -f1 "$d/vim/plugins.lock" | paste -sd' ')"
  fi

  [[ -d $HOME/.config/nvim ]] || return 0
  grab "$HOME/.config/nvim" "$d/nvim/config"
  if git -C "$HOME/.config/nvim" rev-parse --git-dir >/dev/null 2>&1; then
    printf '%s\t%s\t%s\n' \
      "$(git -C "$HOME/.config/nvim" remote get-url origin 2>/dev/null)" \
      "$(git -C "$HOME/.config/nvim" symbolic-ref --short HEAD 2>/dev/null)" \
      "$(git -C "$HOME/.config/nvim" rev-parse HEAD)" > "$d/nvim/config.git"
    [[ -z $(git -C "$HOME/.config/nvim" status --porcelain) ]] ||
      warn "~/.config/nvim has uncommitted changes (captured here anyway)"
  fi
  if has nvim; then
    nvim --version | awk 'NR==1 {print $2}' > "$d/nvim/version"
    ok "neovim $(cat "$d/nvim/version")"
  fi

  # Plugins of any manager: packer/paq (site/pack/*/{start,opt}) and lazy.nvim (lazy/).
  : > "$d/nvim/plugins.lock"
  for p in "$NVIM_DATA"/site/pack/*/; do
    for kind in start opt; do
      [[ -d $p$kind ]] && git_lock "$p$kind" | sed "s|^|site/pack/$(basename "$p")/$kind/|" >> "$d/nvim/plugins.lock"
    done
  done
  [[ -d $NVIM_DATA/lazy ]] && git_lock "$NVIM_DATA/lazy" | sed 's|^|lazy/|' >> "$d/nvim/plugins.lock"
  ok "nvim plugins: $(wc -l < "$d/nvim/plugins.lock") pinned"

  if [[ -d $NVIM_DATA/mason/packages ]]; then
    for p in "$NVIM_DATA"/mason/packages/*/; do
      id=$(jq -r '.primary_source.id // .source.id // empty' "$p/mason-receipt.json" 2>/dev/null)
      printf '%s\t%s\n' "$(basename "$p")" "${id##*@}"
    done > "$d/nvim/mason.lock"
    ok "mason: $(cut -f1 "$d/nvim/mason.lock" | paste -sd' ')"
  fi

  find "$NVIM_DATA" -path '*/nvim-treesitter/parser/*.so' -printf '%f\n' 2>/dev/null |
    sed 's/\.so$//' | sort -u > "$d/nvim/treesitter.txt"
  [[ -s $d/nvim/treesitter.txt ]] && ok "treesitter: $(wc -l < "$d/nvim/treesitter.txt") parsers"
  return 0
}

vim_install() {
  local d=$DATA_DIR/vim f
  [[ -d $d ]] || return 0
  need_pkgs git curl

  for f in "${VIM_HOME_FILES[@]}"; do put "$d/vim/$f" "$HOME/$f"; done
  put "$d/vim/.vim" "$HOME/.vim"
  if [[ -s $d/vim/plugins.lock ]]; then
    need_pkgs vim
    # vim-plug installs each plugin and runs its post-install hook; then pin the commits.
    run vim -es -u "$HOME/.vimrc" -i NONE -c 'PlugInstall --sync' -c qa >/dev/null 2>&1 || true
    while IFS=$'\t' read -r name url commit; do
      clone_at "$url" "$HOME/.vim/plugged/$name" "$commit"
    done < <(lines "$d/vim/plugins.lock")
    ok "vim plugins at their exact commits: $(cut -f1 "$d/vim/plugins.lock" | paste -sd' ')"
  fi

  [[ -d $d/nvim/config ]] || return 0
  nvim_release_install "$(cat "$d/nvim/version" 2>/dev/null)"
  nvim_config_install "$d/nvim"
  nvim_plugins_install "$d/nvim"
}

# mason_install MASON_PLUGIN_PATH PKG...: Mason alone (-u NONE), so your config doesn't have
# to call mason.setup(). MasonInstall blocks until done when nvim runs headless.
mason_install() {
  local mason=$1; shift
  timeout 1200 nvim --headless -u NONE -c "set rtp+=$NVIM_DATA/$mason" -c "lua require('mason').setup()" \
    -c "MasonInstall $*" -c qa >/dev/null 2>&1 || true
}

# The same Neovim release as the old machine, from GitHub, into ~/.local/bin.
nvim_release_install() {
  local want=$1 have="" dir=$HOME/.local/bin asset
  export PATH=$dir:$PATH
  has nvim && have=$(nvim --version | awk 'NR==1 {print $2}')
  if [[ -n $have && ( -z $want || $have == "$want" ) ]]; then info "neovim $have already installed"; return 0; fi
  run mkdir -p "$dir"
  for asset in nvim-linux-x86_64 nvim-linux64; do   # the tarball was renamed in v0.10.4
    if run bash -c "curl -fsSL https://github.com/neovim/neovim/releases/download/${want:-stable}/$asset.tar.gz | tar -xz -C '$dir' 2>/dev/null"; then
      run ln -sfn "$dir/$asset/bin/nvim" "$dir/nvim"
      ok "neovim ${want:-stable} -> ~/.local/bin/nvim"
      return 0
    fi
  done
  warn "neovim ${want:-stable} download failed"
}

# Copy the config, then reconnect it to its GitHub repo so you can keep committing to it.
nvim_config_install() {
  local d=$1 cfg=$HOME/.config/nvim url branch commit
  put "$d/config" "$cfg"
  [[ -f $d/config.git && ! -e $cfg/.git ]] || return 0
  IFS=$'\t' read -r url branch commit < "$d/config.git"
  [[ -n $url ]] || return 0
  branch=${branch:-master}
  if run git -C "$cfg" init -q -b "$branch" && run git -C "$cfg" remote add origin "$url" &&
     run git -C "$cfg" fetch -q origin 2>/dev/null; then
    run git -C "$cfg" reset -q "origin/$branch"
    ok "~/.config/nvim linked to $url ($branch)"
  else
    rm -rf "$cfg/.git"
    warn "~/.config/nvim restored but not linked to $url (no GitHub access yet?). Rerun './migrate install vim' after 'bundle unpack'"
  fi
}

nvim_plugins_install() {
  local d=$1 path url commit n=0 spec
  while IFS=$'\t' read -r path url commit; do
    clone_at "$url" "$NVIM_DATA/$path" "$commit" && n=$((n+1))
  done < <(lines "$d/plugins.lock")
  ((n)) && ok "nvim plugins at their exact commits: $n"
  if [[ $DRY_RUN == 1 ]]; then info "[dry-run] then: recompile packer, build treesitter parsers, install Mason tools"; return 0; fi
  has nvim || return 0
  # Mason runs npm/java-based tools; make nvm's node visible when run on its own.
  [[ -s $HOME/.nvm/nvm.sh ]] && ! has npm && { set +u; . "$HOME/.nvm/nvm.sh"; set -u; }

  # packer_compiled.lua holds absolute paths: rebuild it if this home differs from the old one.
  spec=$(grep -rlE "require\(?['\"]packer['\"]\)?\.startup" "$HOME/.config/nvim/lua" 2>/dev/null | head -1)
  if [[ -n $spec ]] && ! grep -q "$HOME/" "$HOME/.config/nvim/plugin/packer_compiled.lua" 2>/dev/null; then
    spec=${spec#$HOME/.config/nvim/lua/}; spec=${spec%.lua}; spec=${spec//\//.}
    timeout 120 nvim --headless -c "lua require('$spec')" -c 'autocmd User PackerCompileDone quitall' \
      -c PackerCompile >/dev/null 2>&1 && ok "packer loader recompiled for $HOME" || warn "PackerCompile failed: run :PackerCompile in nvim"
  fi

  if [[ -s $d/treesitter.txt ]]; then
    need_pkgs gcc
    timeout 900 nvim --headless -c "TSInstallSync $(paste -sd' ' "$d/treesitter.txt")" -c qa >/dev/null 2>&1 &&
      ok "treesitter: $(wc -l < "$d/treesitter.txt") parsers built" || warn "treesitter parsers failed: run :TSUpdate in nvim"
  fi

  if [[ -s $d/mason.lock ]]; then
    local mason pkgs missing=()
    mason=$(lines "$d/plugins.lock" | awk -F'\t' '$1 ~ /\/mason\.nvim$/ {print $1; exit}')
    need_pkgs unzip wget
    pkgs=$(lines "$d/mason.lock" | awk -F'\t' '{print ($2 == "" ? $1 : $1 "@" $2)}' | paste -sd' ')
    mason_install "$mason" $pkgs
    # A pinned version can vanish upstream (e.g. Eclipse purges old jdtls snapshots): take the latest.
    while IFS=$'\t' read -r name _; do
      [[ -d $NVIM_DATA/mason/packages/$name ]] || missing+=("$name")
    done < <(lines "$d/mason.lock")
    if ((${#missing[@]})); then
      mason_install "$mason" "${missing[@]}"
      local still=()
      for name in "${missing[@]}"; do [[ -d $NVIM_DATA/mason/packages/$name ]] || still+=("$name"); done
      for name in "${missing[@]}"; do [[ " ${still[*]} " == *" $name "* ]] || warn "mason: $name pinned version no longer downloadable, installed the latest"; done
      ((${#still[@]})) && warn "mason: not installed: ${still[*]} (npm-based tools need the node module; open :Mason for details)"
    fi
    ok "mason: $(ls "$NVIM_DATA/mason/packages" 2>/dev/null | paste -sd' ')"
  fi
}
