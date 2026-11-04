#!/usr/bin/env bash
# Try an install on a throwaway Ubuntu container, as a user with your uid.
#
#   tests/docker-install.sh [UBUNTU_VERSION] [MODULE...]
#
# The modules given (default: everything that needs no GNOME session or real
# credentials) install for real; the rest run as --dry-run.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${1:-24.04}; shift || true
REAL=${*:-dotfiles vim editors jetbrains claude apps gnome}

command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
echo "==> ubuntu:$VERSION: installing [$REAL] for real, the rest as a dry run"

docker run --rm -e HOST_UID="$(id -u)" -e REAL="$REAL" -v "$REPO_DIR":/repo:ro "ubuntu:$VERSION" bash -c '
  set -e
  apt-get update -qq >/dev/null
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq rsync python3 sudo git lsb-release >/dev/null
  U=$(getent passwd "$HOST_UID" | cut -d: -f1)
  [ -n "$U" ] || { useradd -m -u "$HOST_UID" -s /bin/bash tester; U=tester; }
  echo "$U ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/migrate
  REST=$(su - "$U" -c "/repo/migrate list" | awk "{print \$1}" | grep -vxF -f <(tr " " "\n" <<<"$REAL") | tr "\n" " ")

  su - "$U" -c "/repo/migrate install --yes $REAL"
  su - "$U" -c "/repo/migrate install --dry-run $REST" | tail -30

  echo; echo "==> checks"
  su - "$U" -c "bash -ic \"type vim ll cd >/dev/null && echo shell: ok\"" 2>&1 | grep -v "job control\|process group"
  if grep -qw vim <<<"$REAL"; then
    su - "$U" -c "PATH=\$HOME/.local/bin:\$PATH; nvim --version | head -1
      nvim --headless -c \"lua io.write(\\\"plugins loaded: \\\" .. #vim.tbl_keys(packer_plugins or {}) .. \\\"\\n\\\")\" -c qa 2>&1
      nvim --headless -c \"lua io.write(\\\"colorscheme: \\\" .. (vim.g.colors_name or \\\"none\\\") .. \\\"\\n\\\")\" -c qa 2>&1
      ls ~/.local/share/nvim/mason/packages 2>/dev/null | paste -sd\" \" | sed \"s/^/mason: /\"
      ls ~/.vim/plugged | paste -sd\" \" | sed \"s/^/vim plugins: /\""
  fi
'
