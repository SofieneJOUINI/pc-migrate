# Shell, git and terminal dotfiles listed in config/dotfiles.txt.
# Shell rc files go through redact.py so no password reaches git.

MODULE_DESC[dotfiles]="bash (aliases, functions, prompt), git, tmux, starship + the CLI tools they call"

is_shell_rc() {
  case $1 in .bashrc|.bash_aliases|.bash_profile|.profile|.zshrc|.zprofile) return 0 ;; esac
  return 1
}

dotfiles_export() {
  local d=$DATA_DIR/dotfiles f msg
  rm -rf "$d/home"; mkdir -p "$d/home"
  {
    echo "# Secrets removed from your dotfiles by pc-migrate. Values are never stored."
    echo "# Copied to ~/.secrets.env on install: fill in the ones you still need."
  } > "$SECRETS_TEMPLATE"
  while read -r f; do
    [[ -f $HOME/$f ]] || continue
    mkdir -p "$(dirname "$d/home/$f")"
    if is_shell_rc "$f"; then
      msg=$(python3 "$REPO_DIR/lib/redact.py" "$HOME/$f" "$d/home/$f" "$SECRETS_TEMPLATE" 2>&1)
      ok "~/$f${msg:+  ($msg)}"
    else
      grab "$HOME/$f" "$d/home/$f"
    fi
  done < <(config_list dotfiles)
}

dotfiles_install() {
  local d=$DATA_DIR/dotfiles f n
  while read -r f; do put "$d/home/$f" "$HOME/$f"; done < <(config_list dotfiles)
  if [[ ! -f $HOME/.secrets.env && -f $SECRETS_TEMPLATE ]]; then
    run install -m 600 "$SECRETS_TEMPLATE" "$HOME/.secrets.env"
    n=$(lines "$SECRETS_TEMPLATE" | wc -l)
    warn "~/.secrets.env created with $n empty secret(s): fill in the ones you need (the comment says where each is used)"
  fi
  if grep -q 'tmux-plugins/tpm' "$d/home/.tmux.conf" 2>/dev/null && [[ ! -d $HOME/.tmux/plugins/tpm ]]; then
    run git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  fi
  shell_tools_install
}

# Tools the shell config calls on startup. Without them a new terminal prints errors,
# and `alias cd=z` leaves you without a working cd. (nvim comes with the vim module.)
shell_tools_install() {
  local rc; rc=$(cat "$DATA_DIR"/dotfiles/home/.bash* 2>/dev/null)
  need_pkgs curl git
  if grep -q 'zoxide' <<<"$rc" && ! has zoxide; then
    run sudo apt-get install -y -qq zoxide >/dev/null || warn "zoxide install failed: 'cd' is aliased to it"
  fi
  if grep -q 'starship init' <<<"$rc" && ! has starship; then
    run bash -c 'curl -fsSL https://starship.rs/install.sh | sudo sh -s -- -y -b /usr/local/bin >/dev/null' && ok starship || warn "starship install failed"
  fi
  if grep -q 'fzf' <<<"$rc" && ! has fzf && [[ ! -x $HOME/.fzf/bin/fzf ]]; then
    [[ -d $HOME/.fzf ]] || run git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    run "$HOME/.fzf/install" --bin >/dev/null 2>&1 && ok fzf || warn "fzf install failed"
  fi
  if grep -qE '(^|[^-[:alnum:]_])aws ' <<<"$rc" && ! has aws; then
    need_pkgs unzip
    run bash -c 'cd "$(mktemp -d)" && curl -fsSLo awscli.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && unzip -q awscli.zip && sudo ./aws/install >/dev/null' &&
      ok "aws cli v2" || warn "aws cli install failed"
  fi
}
