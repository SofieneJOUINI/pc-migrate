# Shared helpers for the migrate CLI and its modules. Sourced, never executed.

CONFIG_DIR="$REPO_DIR/config"                   # what to migrate: lists you edit
DATA_DIR="${DATA_DIR:-$REPO_DIR/data}"          # captured machine state, one folder per module
SECRETS_TEMPLATE="${SECRETS_TEMPLATE:-$DATA_DIR/dotfiles/secrets.env.template}"  # names of removed secrets, no values
DRY_RUN="${DRY_RUN:-0}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.pc-migrate-backup/$(date +%Y%m%d-%H%M%S)}"

if [[ -t 1 ]]; then
  c_blue=$'\e[34m' c_green=$'\e[32m' c_yellow=$'\e[33m' c_red=$'\e[31m' c_dim=$'\e[2m' c_off=$'\e[0m'
else
  c_blue='' c_green='' c_yellow='' c_red='' c_dim='' c_off=''
fi
log()  { printf '%s==>%s %s\n' "$c_blue" "$c_off" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$c_green" "$c_off" "$*"; }
info() { printf '  %s%s%s\n' "$c_dim" "$*" "$c_off"; }
warn() { printf '  %s!%s %s\n' "$c_yellow" "$c_off" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$c_red" "$c_off" "$*" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }
tilde() { printf '%s' "${1/#$HOME/\~}"; }

# run CMD...: execute, or only print it in --dry-run mode.
run() {
  if [[ $DRY_RUN == 1 ]]; then printf '  %s[dry-run]%s %s\n' "$c_dim" "$c_off" "$*"; else "$@"; fi
}

# grab SRC DEST [rsync-args...]: copy a file or directory from this machine into the repo.
grab() {
  local src=$1 dest=$2; shift 2
  [[ -e $src ]] || return 0
  mkdir -p "$(dirname "$dest")"
  if [[ -d $src ]]; then
    rsync -a --delete --exclude=.git "$@" "$src/" "$dest/"
  else
    cp -pL "$src" "$dest"
  fi
  ok "$(tilde "$src")"
}

# put SRC DEST: copy a repo file or directory onto this machine, backing up what it replaces.
put() {
  local src=$1 dest=$2
  [[ -e $src ]] || return 0
  if [[ -d $src ]]; then
    run mkdir -p "$dest"
    run rsync -a --backup --backup-dir="$BACKUP_DIR/${dest#$HOME/}" "$src/" "$dest/" || { warn "$(tilde "$dest") copy failed"; return 0; }
  else
    if [[ -e $dest ]] && cmp -s "$src" "$dest"; then info "$(tilde "$dest") unchanged"; return 0; fi
    if [[ -e $dest ]]; then
      run mkdir -p "$BACKUP_DIR/$(dirname "${dest#$HOME/}")"
      run cp -p "$dest" "$BACKUP_DIR/${dest#$HOME/}"
    fi
    run mkdir -p "$(dirname "$dest")"
    run cp -p "$src" "$dest" || { warn "$(tilde "$dest") copy failed"; return 0; }
  fi
  ok "$(tilde "$dest")"
}

# lines FILE: print non-empty, non-comment lines.
lines() { [[ -f $1 ]] && grep -vE '^\s*(#|$)' "$1" || true; }

# config_list NAME: the entries of config/NAME.txt.
config_list() { lines "$CONFIG_DIR/$1.txt"; }

# need_pkgs PKG...: apt-get install whatever of PKG... is missing (e.g. curl on a fresh 24.04).
need_pkgs() {
  local p missing=()
  for p in "$@"; do has "$p" || missing+=("$p"); done
  ((${#missing[@]})) || return 0
  run sudo apt-get install -y -qq "${missing[@]}" >/dev/null || warn "could not install ${missing[*]}"
}

need_sudo() {
  [[ $DRY_RUN == 1 || $EUID == 0 ]] && return 0
  has sudo || die "sudo is required for this module"
  sudo -v
}
