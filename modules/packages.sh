# apt (manually installed + third-party repos and their keys), snap, flatpak.

MODULE_DESC[packages]="apt packages + third-party apt repos/keys, snaps, flatpaks"

# Snaps that only exist as runtimes for other snaps.
SNAP_RUNTIMES='^(bare|core[0-9]*|snapd|snapd-desktop-integration|snap-store|gtk-common-themes|gnome-[0-9-]+|kf[0-9]+-core[0-9]+|mesa-[0-9]+|lxqt-support-core[0-9]+|wine-platform-.*)$'

packages_export() {
  local d=$DATA_DIR/packages
  mkdir -p "$d"

  if has apt-mark; then
    local base=/var/log/installer/initial-status.gz
    {
      echo "# Packages you installed on top of a fresh Ubuntu. Delete lines you don't want."
      if [[ -r $base ]]; then
        comm -23 <(apt-mark showmanual | sort -u) <(gzip -dc "$base" | sed -n 's/^Package: //p' | sort -u)
      else
        apt-mark showmanual | sort -u
      fi | grep -vE '^linux-(image|headers|modules|generic|hwe)'
    } > "$d/apt.txt"
    ok "apt: $(lines "$d/apt.txt" | wc -l) packages"

    # Third-party repositories, and every key file they reference.
    rm -rf "$d/apt-sources" "$d/apt-keys"
    mkdir -p "$d/apt-sources" "$d/apt-keys"
    find /etc/apt/sources.list.d -maxdepth 1 -type f \( -name '*.list' -o -name '*.sources' \) \
      -exec cp -p {} "$d/apt-sources/" \;
    {
      grep -rhoE 'signed-by=[^] ]+' /etc/apt/sources.list.d/ 2>/dev/null | cut -d= -f2
      grep -rhE '^Signed-By: /' /etc/apt/sources.list.d/ 2>/dev/null | awk '{print $2}'
      find /etc/apt/trusted.gpg.d -maxdepth 1 -type f ! -name "*~" 2>/dev/null
    } | sort -u > "$d/apt-keys/paths.txt"
    while read -r key; do
      [[ -r $key && $key != *~ ]] && cp -p "$key" "$d/apt-keys/$(basename "$key")"
    done < "$d/apt-keys/paths.txt"
    ok "apt repos: $(ls "$d/apt-sources" | wc -l) source files, $(lines "$d/apt-keys/paths.txt" | wc -l) keys"
    lsb_release -cs > "$d/apt-codename" 2>/dev/null || true
  fi

  if has snap; then
    {
      echo "# name channel [classic]"
      snap list --unicode=never --color=never 2>/dev/null | awk 'NR>1 {print $1, $4, $6}' |
        awk -v rx="$SNAP_RUNTIMES" '$1 !~ rx {
          split($2, c, "/"); ch = c[1] "/" c[2]
          print $1, ch, ($3 ~ /classic/ ? "classic" : "")
        }'
    } > "$d/snap.txt"
    ok "snap: $(lines "$d/snap.txt" | wc -l) snaps"
  fi

  if has flatpak; then
    flatpak remotes --columns=name,url 2>/dev/null > "$d/flatpak-remotes.txt"
    flatpak list --app --columns=application,origin 2>/dev/null > "$d/flatpak.txt"
    ok "flatpak: $(lines "$d/flatpak.txt" | wc -l) apps"
  fi
}

packages_install() {
  local d=$DATA_DIR/packages tmp
  tmp=$(mktemp -d)
  need_sudo

  if [[ -f $d/apt.txt ]] && has apt-get; then
    local here; here=$(lsb_release -cs 2>/dev/null || echo unknown)
    if [[ -f $d/apt-codename && $(cat "$d/apt-codename") != "$here" ]]; then
      warn "repos were exported on $(cat "$d/apt-codename"), this is $here: some third-party repos may not have a $here release"
    fi
    while read -r key; do
      [[ -z $key || -e $key ]] && continue
      run sudo install -D -m 644 "$d/apt-keys/$(basename "$key")" "$key"
    done < <(lines "$d/apt-keys/paths.txt")
    for f in "$d"/apt-sources/*; do
      [[ -e /etc/apt/sources.list.d/$(basename "$f") ]] || run sudo cp "$f" /etc/apt/sources.list.d/
    done
    run sudo apt-get update || warn "apt-get update reported errors (often a repo without a release for $here)"

    if grep -q ':i386$' "$d/apt.txt" && ! dpkg --print-foreign-architectures | grep -qx i386; then
      run sudo dpkg --add-architecture i386 && run sudo apt-get update -qq
    fi
    lines "$d/apt.txt" | sort -u > "$tmp/want"
    apt-cache pkgnames | sort -u > "$tmp/known"
    # pkgnames has no :arch suffix; accept foo:i386 when foo exists
    sed -n 's/:i386$//p' "$tmp/want" | comm -12 - "$tmp/known" | sed 's/$/:i386/' >> "$tmp/known"
    sort -u -o "$tmp/known" "$tmp/known"
    comm -12 "$tmp/want" "$tmp/known" > "$tmp/ok"
    comm -23 "$tmp/want" "$tmp/known" > "$tmp/missing"
    if [[ -s $tmp/ok ]]; then
      # shellcheck disable=SC2046
      run sudo apt-get install -y $(cat "$tmp/ok") || warn "apt-get install failed, rerun it to see which package"
    fi
    if [[ -s $tmp/missing && $DRY_RUN == 1 ]]; then
      info "not found in the repos known right now (a dry run doesn't add your third-party repos, so most of these will resolve):"
      paste -sd' ' "$tmp/missing" | fold -s -w 90 | sed 's/^/      /'
    elif [[ -s $tmp/missing ]]; then
      warn "not in any apt repo here (installed from a .deb before?), get these by hand:"
      sed 's/^/      /' "$tmp/missing" >&2
    fi
  fi

  if [[ -f $d/snap.txt ]] && has snap; then
    while read -r name channel classic; do
      snap list "$name" >/dev/null 2>&1 && { info "snap $name already installed"; continue; }
      run sudo snap install "$name" --channel="$channel" ${classic:+--classic} || warn "snap $name failed"
    done < <(lines "$d/snap.txt")
  fi

  if [[ -s $d/flatpak.txt ]]; then
    has flatpak || run sudo apt-get install -y flatpak
    while read -r name url; do
      [[ $name == flathub ]] && url=https://dl.flathub.org/repo/flathub.flatpakrepo
      run sudo flatpak remote-add --if-not-exists "$name" "$url" || warn "flatpak remote $name failed"
    done < <(lines "$d/flatpak-remotes.txt")
    while read -r app origin; do
      run flatpak install -y --noninteractive "$origin" "$app" || warn "flatpak $app failed"
    done < <(lines "$d/flatpak.txt")
  fi
  rm -rf "$tmp"
}
