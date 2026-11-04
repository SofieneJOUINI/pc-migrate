# Setting up the new PC by hand

Step-by-step instructions to rebuild this PC without `./migrate`. Use them when the script
fails, or to redo a single part.

Each **section** is a topic (shell, Node, GNOME, ...). Each **setup** inside it is one thing to
configure, with its own numbered steps. Every step shows the value you had on the old PC.

The values come from the export of **Nov 4, 2026** (Ubuntu 22.04, laptop
`sofienejouini-Latitude-5530`). If you exported again since, the files in `~/pc-migrate/data/`
are the source of truth.

**Before you start**

- `~` means your home folder (`/home/sofienejouini`).
- In Files, press **Ctrl+H** to show hidden files and folders (the ones starting with a dot).
- Do the sections in order the first time: later ones need tools from earlier ones (git, Node,
  SSH key).

**Sections**

1. [Get the project](#1-get-the-project)
2. [Keys and credentials](#2-keys-and-credentials)
3. [Software sources](#3-software-sources)
4. [apt packages](#4-apt-packages)
5. [Snap apps](#5-snap-apps)
6. [Shell](#6-shell)
7. [Terminal look](#7-terminal-look)
8. [Node](#8-node)
9. [Python](#9-python)
10. [Vim and Neovim](#10-vim-and-neovim)
11. [Git repositories](#11-git-repositories)
12. [VS Code and Cursor](#12-vs-code-and-cursor)
13. [IntelliJ](#13-intellij)
14. [Claude Code](#14-claude-code)
15. [App settings](#15-app-settings)
16. [GNOME desktop](#16-gnome-desktop)
17. [Last resort: copy from the old PC](#17-last-resort-copy-from-the-old-pc)

---

## 1. Get the project

### 1.1 Install git

1. Open a terminal (**Ctrl+Alt+T**).
2. Run `sudo apt install -y git`.
3. Check: `git --version` prints a version.

### 1.2 Copy the project folder

Pick one way:

1. **USB stick** (simplest): copy the whole `pc-migrate` folder from the old PC into your home
   folder.
2. **Browser:** open <https://github.com/SofieneJOUINI/pc-migrate>, sign in, click **Code →
   Download ZIP**, extract it in your home folder and rename the folder to `pc-migrate`.
3. **git over SSH** (only after section 2):
   `git clone git@github.com:SofieneJOUINI/pc-migrate.git ~/pc-migrate`

---

## 2. Keys and credentials

These never go to git. They travel in the encrypted bundle
`pc-migrate-bundle-<date>.tar.gz.gpg` on your USB stick.

### 2.1 Unpack the bundle

1. Plug in the USB stick.
2. In a terminal, run:
   `gpg -d /media/$USER/<usb>/pc-migrate-bundle-*.tar.gz.gpg | tar -xz -C ~`
3. Type the bundle passphrase (saved in KeePassXC on the old PC or your phone).

No bundle? Copy each path named in 2.2 to 2.7 from the old PC by USB stick instead.

### 2.2 SSH keys: `~/.ssh`

1. Check the folder is there: `ls ~/.ssh`
2. Lock the folder: `chmod 700 ~/.ssh`
3. Lock the private keys: `chmod 600 ~/.ssh/id_*` then `chmod 644 ~/.ssh/*.pub`
4. Check GitHub: `ssh -T git@github.com` answers *Hi SofieneJOUINI!*
5. Check GitLab: `ssh -T git@gitlab.cicd.adad.io` answers *Welcome to GitLab*.

### 2.3 Server keys: `~/keys`

1. Check the folder is there: `ls ~/keys` (holds `prod-key.pem`, used by the SSH tunnel aliases).
2. Lock the keys: `chmod 600 ~/keys/*`

### 2.4 AWS and Kubernetes: `~/.aws`, `~/.kube`

1. Check: `ls ~/.aws` shows `config` and `credentials`.
2. Check: `ls ~/.kube` shows `config`.
3. They're used once the AWS CLI (6.9) and kubectl (4.7) are installed.

### 2.5 Developer logins

1. Check these files are in your home folder (Ctrl+H in Files):
   - `.docker/config.json`: Docker registry logins
   - `.m2/settings.xml`: Maven repositories and credentials
   - `.npmrc`: npm registry token
   - `.git-credentials`: saved git HTTPS logins
   - `.pgpass`: PostgreSQL passwords
   - `.config/gh/`: GitHub CLI login
2. Lock the password files: `chmod 600 ~/.pgpass ~/.git-credentials`

### 2.6 Password database

1. Check `~/Documents/Settings/Passwords.kdbx` is there.
2. You open it with KeePassXC once it's installed (4.8).

### 2.7 Fonts

1. Check `~/.local/share/fonts` has your Nerd Fonts (JetBrainsMono, 0xProto).
2. Refresh the font list: `fc-cache -f`

---

## 3. Software sources

Third-party apps come from their vendors' apt repositories. Each needs a **key file** and a
**source file**, both saved in `~/pc-migrate/data/packages/`. Run every command in this section
from the keys folder:

`cd ~/pc-migrate/data/packages/apt-keys`

### 3.1 Prepare the folders

1. Run `sudo mkdir -p /etc/apt/keyrings /usr/share/keyrings /usr/share/postgresql-common/pgdg`

### 3.2 Docker

1. Key: `sudo cp docker.gpg /etc/apt/keyrings/`
2. Source: `sudo cp ../apt-sources/docker.list /etc/apt/sources.list.d/`

### 3.3 Kubernetes (kubectl)

1. Key: `sudo cp kubernetes-apt-keyring.gpg /etc/apt/keyrings/`
2. Source: `sudo cp ../apt-sources/kubernetes.list /etc/apt/sources.list.d/`

### 3.4 Lens and Freelens

1. Keys: `sudo cp lens-archive-keyring.gpg /usr/share/keyrings/` and
   `sudo cp freelens.asc /etc/apt/keyrings/`
2. Sources: `sudo cp ../apt-sources/lens.list ../apt-sources/freelens.sources /etc/apt/sources.list.d/`

### 3.5 Google Chrome

1. Key: `sudo cp google-chrome.gpg /usr/share/keyrings/`
2. Source: `sudo cp ../apt-sources/google-chrome.sources /etc/apt/sources.list.d/`

### 3.6 Brave

1. Key: `sudo cp brave-browser-archive-keyring.gpg /usr/share/keyrings/`
2. Source: `sudo cp ../apt-sources/brave-browser-release.list /etc/apt/sources.list.d/`

### 3.7 VS Code

1. Key: `sudo cp microsoft.gpg /usr/share/keyrings/`
2. Source: `sudo cp ../apt-sources/vscode.sources /etc/apt/sources.list.d/`

### 3.8 Cursor

1. Key: `sudo cp anysphere.gpg /usr/share/keyrings/`
2. Source: `sudo cp ../apt-sources/cursor.sources /etc/apt/sources.list.d/`

### 3.9 Claude Desktop

1. Key: `sudo cp claude-desktop-archive-keyring.asc /usr/share/keyrings/`
2. Source: `sudo cp ../apt-sources/claude-desktop.list /etc/apt/sources.list.d/`

### 3.10 Sublime Text

1. Key: `sudo cp sublimetext-keyring.gpg /usr/share/keyrings/`
2. Source: `sudo cp ../apt-sources/sublime-text.list /etc/apt/sources.list.d/`

### 3.11 PostgreSQL client and pgAdmin

1. Keys: `sudo cp apt.postgresql.org.asc /usr/share/postgresql-common/pgdg/` and
   `sudo cp packages-pgadmin-org.gpg /usr/share/keyrings/`
2. Sources: `sudo cp ../apt-sources/pgdg.list ../apt-sources/pgadmin4.list /etc/apt/sources.list.d/`

### 3.12 Node.js (NodeSource)

1. Key: `sudo cp nodesource.gpg /usr/share/keyrings/`
2. Source: `sudo cp ../apt-sources/nodesource.list /etc/apt/sources.list.d/`

### 3.13 Spotify

1. Key: `sudo cp spotify.gpg /etc/apt/trusted.gpg.d/`
2. Source: `sudo cp ../apt-sources/spotify.list /etc/apt/sources.list.d/`

### 3.14 Python 3.12 (deadsnakes) and Neovim PPAs

Only on Ubuntu 22.04. On a newer Ubuntu, skip this: Python 3.12 is built in, and section 10
installs its own Neovim.

1. Run `sudo add-apt-repository ppa:deadsnakes/ppa`
2. Run `sudo add-apt-repository ppa:neovim-ppa/stable`

### 3.15 ScreenRec

1. Source: `sudo cp ../apt-sources/archive_uri-https_screenrec_com_download_ubuntu-jammy.list /etc/apt/sources.list.d/`

### 3.16 Refresh and fix errors

1. Run `sudo apt update`.
2. **Error *does not have a Release file*** (newer Ubuntu than 22.04):
   1. Find your version's name: `lsb_release -cs` (`noble` for 24.04).
   2. Open the file named in the error: `sudo nano /etc/apt/sources.list.d/<file>`
   3. Replace `jammy` with that name, save (**Ctrl+O**, Enter) and quit (**Ctrl+X**).
   4. Run `sudo apt update` again.
3. **Warning *configured multiple times***: delete the second file for that repo in
   `/etc/apt/sources.list.d/`, then run `sudo apt update` again.

---

## 4. apt packages

If apt says *Unable to locate package X*, remove X from that command and run it again.

### 4.1 Command-line basics

1. Run `sudo apt install -y apt-transport-https curl git jq ripgrep tmux vim xclip zoxide htop hwinfo net-tools dos2unix csvkit redis-tools xgrep`
2. Check: `rg --version` and `zoxide --version` print versions.

### 4.2 Java 17 and 21, Maven, Gradle

1. Run `sudo apt install -y openjdk-17-jdk openjdk-21-jdk maven gradle`
2. Check: `java -version` shows **21** once your `.bashrc` is in place (section 6.2 sets
   `JAVA_HOME` to Java 21).

### 4.3 Python 3.12

1. On Ubuntu 22.04, run `sudo apt install -y python3-pip python3.10-venv python3.12 python3.12-dev python3.12-venv`
2. On Ubuntu 24.04 or later, run `sudo apt install -y python3-pip python3-venv python3-dev`

### 4.4 Node (system) and database clients

1. Run `sudo apt install -y nodejs node-typescript libpq-dev postgresql-client-17`
2. Check: `psql --version` shows **17**.

### 4.5 Docker

1. Run `sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
2. Let yourself use Docker without sudo: `sudo usermod -aG docker $USER`
3. Log out and back in.
4. Check: `docker run hello-world`

### 4.6 Browsers and editors

1. Run `sudo apt install -y google-chrome-stable brave-browser code cursor sublime-text claude-desktop`

### 4.7 Kubernetes and database apps

1. Run `sudo apt install -y lens freelens pgadmin4 pgadmin4-desktop mongodb-compass`
2. If `mongodb-compass` isn't found, download the `.deb` from
   <https://www.mongodb.com/try/download/compass> and double-click it.
3. For `kubectl`: `sudo apt install -y kubectl` (from the repo in 3.3).

### 4.8 Desktop apps

1. Run `sudo apt install -y keepassxc flameshot parcellite filezilla peek simplescreenrecorder vlc psensor kigo gnugo`
2. Run `sudo apt install -y flatpak gnome-software-plugin-flatpak gir1.2-ayatanaappindicator3-0.1 gstreamer1.0-fdkaac`

### 4.9 Antivirus

1. Run `sudo apt install -y clamav clamav-daemon`

### 4.10 Wine

1. Turn on 32-bit packages: `sudo dpkg --add-architecture i386`
2. Run `sudo apt update`
3. Run `sudo apt install -y wine32:i386`

### 4.11 AWS Session Manager plugin

Needed by the `start_ssm_session_*` aliases.

1. Download <https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb>
2. Double-click it in Files, then **Install**.
3. Check: `session-manager-plugin --version`

### 4.12 Scrut endpoint agent and `efs`

1. `scrut-endpoint-agent` isn't in any public repo: ask IT for the installer.
2. If `efs` wasn't found, look it up on the old PC with `apt show efs` to see where it came from.

---

## 5. Snap apps

### 5.1 Regular snaps

1. Run `sudo snap install cups drawio firefox fx kapman onlyoffice-desktopeditors outlook-ew pgadmin4 redisinsight spotify teams-for-linux yq`

### 5.2 IntelliJ IDEA Community

1. Run `sudo snap install intellij-idea-community --classic`

### 5.3 Obsidian

1. Run `sudo snap install obsidian --classic`

### 5.4 Postman 10

1. Run `sudo snap install postman --channel=v10/stable` (pinned to version 10 like before).

---

## 6. Shell

The config files are in `~/pc-migrate/data/dotfiles/home/`. Open that folder in Files and press
**Ctrl+H**. If you want to keep the new PC's originals, rename them first (e.g. `.bashrc` →
`.bashrc.orig`).

### 6.1 `.profile`: PATH

1. Copy `.profile` into your home folder, choose **Replace**.
2. What it sets: adds `~/bin` and `~/.local/bin` to your PATH, and loads `.bashrc`.

### 6.2 `.bashrc`: prompt, Java, Node, tokens

1. Copy `.bashrc` into your home folder, choose **Replace**.
2. What it sets:
   - **Prompt:** **Starship** (line 2: `eval "$(starship init bash)"`), set up in 6.6. A
     `PS1` further down (green `user@host`, git branch, random emoji) is a leftover: Starship
     replaces it on every command, so you never see it.
   - **History:** 1,000 commands in memory, 2,000 in `~/.bash_history`.
   - **Java:** `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`, added to PATH.
   - **Node:** loads nvm from `~/.nvm` (section 8).
   - **fzf:** loads `~/.fzf.bash` (6.8).
   - **Angular:** `ng` tab completion (section 8).
   - **Keycloak:** `KEYCLOAK_user='sofiene'` and `KEYCLOAK_PASSWORD` (MIRA), from
     `~/.secrets.env` (6.7). Six older ones (dev, UAT, prod, local, staging, keycloak-cli) are
     commented out.
   - **AWS CodeArtifact:** `CODEARTIFACT_AUTH_TOKEN` fetched from AWS (domain `adad`, account
     `185849290566`, region `eu-west-3`) each time a terminal opens. Needs the AWS CLI (6.9).
   - **Secrets:** its first line loads `~/.secrets.env`.

### 6.3 `.bash_aliases`: your shortcuts

1. Copy `.bash_aliases` into your home folder, choose **Replace**.
2. What you get:
   - `cd` → `z`, `cdi` → `zi` (zoxide, 6.10)
   - `vim <file>` → opens Neovim in a tmux session named `vim-<folder>`
   - `ll`, `la`, `l`, colored `ls` and `grep`
   - `getLocalToken`, `getRemoteTokenDev`, `getRemoteTokenUat`: Keycloak tokens
   - `switchAwsProfileDev` / `Uat` / `Prod` / `Staging` / `Poc` / `MiraDev`: set the AWS profile
     and region and point kubectl at that EKS cluster
   - `createSSHTunnelDev` / `Uat` / `UattoProd`, `ssh_tunnel_prod_dt`, `ssh_tunnel_prod_8x_cpd`:
     database tunnels on `localhost:15432` with `~/keys/prod-key.pem`
   - `get_bastion_id`: finds the running `mnc-ec2-bastion` instance
   - `start_ssm_session_rds_*` (prod dt/pr/sk/5j/ay/8x, dev, perf, mira, staging, uat,
     ay_poc_uat, skiling), `start_ssm_session_sftp_*` (prod, dev, staging, uat),
     `start_ssm_session_queue_*` (dev, prod): port forwarding through the bastion
   - `run_adad_upstream_projects`: runs `~/adad_projects/runUpstreamProjects.sh` (11.8)
   - `log-viewer`: runs `~/log-viewer.sh`, which was already missing on the old PC, so this one
     does nothing
   - `restart_virtual_camera`: reloads the OBS virtual camera

### 6.4 `.gitconfig`: your git identity

1. Copy `.gitconfig` into your home folder.
2. Check: `git config user.name` shows `SofieneJOUINI`, `git config user.email` shows
   `sofiene.jouini.code@gmail.com`.

### 6.5 `.tmux.conf`: tmux settings

1. Copy `.tmux.conf` into your home folder.
2. What it sets: system clipboard on, no Escape delay (for Neovim), 1,000,000 lines of history,
   mouse on, status bar refreshed every 3 seconds, `prefix` + `v` splits top/bottom.

### 6.6 Starship: your prompt

Your prompt is drawn by **Starship** (version 1.20.1 on the old PC), configured in
`~/.config/starship.toml`. Without Starship installed, every new terminal prints
*starship: command not found*.

1. Install the **same version**, 1.20.1, so the prompt looks exactly the same (a newer version
   can change default icons and modules):
   `curl -fsSL https://starship.rs/install.sh | sh -s -- -v v1.20.1` and answer **y**.
2. Check: `starship --version` shows `starship 1.20.1`.
   - Don't run the installer again without `-v`: that updates Starship to the latest version.
3. Copy `~/pc-migrate/data/dotfiles/home/.config/starship.toml` into `~/.config/`.
4. Install the font from 7.1 first: the prompt uses Nerd Font icons, which show as empty boxes
   without it.
5. Open a new terminal. Your prompt should look like this, on one line:
   - **Folder** in bold blue (`#61afef`), only the last **2** folders, with `…/` in front when
     it's cut. Some folder names show as icons: `Documents` → 󰈙, `Downloads` → , `Pictures` →
     , `adad_projects` → its own icon.
   - **Git status** in green after the folder: changes, staged, stash, ahead/behind.
   - **AWS profile** in yellow, with an AWS icon, renamed: `default` → **DEV/STAGING**,
     `adad-uat` → **UAT**, `adad-prod` → **PROD**. Handy to see which environment the
     `switchAwsProfile*` functions put you in.
   - **Lua** version with its icon, in Lua folders.
   - No blank line between commands.

What's in `starship.toml`, if you want to change something:

| Setting                         | Value                                       |
|---------------------------------|---------------------------------------------|
| `palette`                       | `onedark` (a `nord` palette is also defined: change this line to switch) |
| `[line_break] disabled`         | `true`: prompt on one line                   |
| `[directory] truncation_length` | `2` folders shown                            |
| `[directory] style`             | `bold fg:dark_blue`                         |
| `[git_status] style`            | `fg:green`                                  |
| `[aws] style`                   | `yellow`                                    |
| onedark colors                  | dark_blue `#61afef`, blue/cyan `#56b6c2`, red `#e06c75`, green `#98c379`, purple `#c678dd`, orange `#be5046`, yellow `#e5c07b`, gray `#828997`, white `#abb2bf`, black `#2c323c` |

### 6.7 `~/.secrets.env`: your passwords

1. Copy `~/pc-migrate/data/dotfiles/secrets.env.template` into your home folder.
2. Rename it to `.secrets.env`.
3. Make it readable only by you: `chmod 600 ~/.secrets.env`
4. Open it: `nano ~/.secrets.env`
5. Fill in, between the quotes, the values you still use (from KeePassXC):
   - `KEYCLOAK_PASSWORD_7`: the active MIRA Keycloak password
   - `GETLOCALTOKEN_PASSWORD`, `GETLOCALTOKEN_CLIENT_ASSERTION`: for `getLocalToken`
   - `GETREMOTETOKENDEV_PASSWORD`, `GETREMOTETOKENDEV_CLIENT_ASSERTION`: for `getRemoteTokenDev`
   - `GETREMOTETOKENUAT_PASSWORD`, `GETREMOTETOKENUAT_CLIENT_ASSERTION`: for `getRemoteTokenUat`
   - `KEYCLOAK_PASSWORD_1` to `_6`: only if you uncomment the old Keycloak lines in `.bashrc`
6. Save (**Ctrl+O**, Enter) and quit (**Ctrl+X**).

### 6.8 fzf: fuzzy search

1. Run `git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf`
2. Run `~/.fzf/install` and answer **y** to all three questions.
3. Check in a new terminal: **Ctrl+R** opens the history search.

### 6.9 AWS CLI v2

1. Download <https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip>
2. In Files, right-click it → **Extract Here**.
3. In a terminal, go to that folder: `cd ~/Downloads`
4. Run `sudo ./aws/install`
5. Check: `aws --version`, then `aws sts get-caller-identity` (works once `~/.aws` is restored).

### 6.10 zoxide: your `cd`

1. Installed in 4.1. Check: `zoxide --version`
2. Without it, `cd` doesn't work in your shell, because it's aliased to `z`.

### 6.11 tmux plugin manager

1. Run `git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`
2. Open `tmux` and press **prefix** then **I** to install the plugins.

### 6.12 Check the shell

1. Close every terminal and open a new one.
2. You should see your Starship prompt (blue folder, green git status, yellow AWS profile) and
   no error lines.
3. *ng: command not found* is normal until section 8.
4. Any other error names the file and line to look at.

---

## 7. Terminal look

GNOME Terminal profile **Sofiene**: dark purple background, white text, a custom 16-color palette,
3% transparency, **JetBrainsMono Nerd Font 12**, 100×50 window.

### 7.1 Font: JetBrainsMono Nerd Font

Skip this setup if you restored the bundle: the font is already in `~/.local/share/fonts`.

1. In Files, open `pc-migrate`, then `data`, then `fonts`. The four files the terminal uses
   (Regular, Bold, Italic, Bold Italic) are there.
2. Double-click `JetBrainsMonoNerdFont-Regular.ttf`. The Fonts window opens: click **Install**.
3. Do the same for the other three files.
4. Log out and back in, so apps see the new font.

If **Install** doesn't appear: in Files press **Ctrl+H**, go to your home folder → `.local` →
`share`, create a `fonts` folder if it doesn't exist, and paste the four files into it.

Need the other weights (Light, Medium, ...)? Download the full font from
<https://www.nerdfonts.com/font-downloads> (**JetBrainsMono**, about 200 MB unzipped).

### 7.2 Profile

1. Open **Terminal**.
2. Click the **☰** menu (top right), then **Preferences**.
3. In the left column under *Profiles*, click your profile (or **+** to make a new one named
   `Sofiene`).
4. Click the **▾** next to the profile name and choose **Set as default**.

### 7.3 Font and window size (Text tab)

1. *Initial terminal size*: **100** columns, **50** rows.
2. Tick **Custom font**, click the font button, search `JetBrainsMono Nerd Font`, pick
   **Regular**, size **12**, click **Select**.
3. Untick **Terminal bell**.

### 7.4 Text and background colors (Colors tab)

1. Untick **Use colors from system theme**.
2. *Built-in schemes*: leave it on **Custom**.
3. Click the **Text** color, then **+** under *Custom*, type `#FFFFFF`, press Enter, click
   **Select**.
4. Same for **Background**: `#110E1C` (very dark purple).

### 7.5 Transparency (Colors tab)

1. Untick **Use transparency from system theme**.
2. Tick **Use transparent background**.
3. Drag the slider almost all the way to the left (your setting is 3%: only a hint of see-through).

### 7.6 Palette (Colors tab)

1. Under *Palette*, click each of the 16 color squares in turn and type its value, the same way
   as in 7.4:

   | Square | Row 1     | Row 2     |
   |--------|-----------|-----------|
   | 1      | `#171421` | `#1A0D3E` |
   | 2      | `#C01C28` | `#F66151` |
   | 3      | `#26A269` | `#33DA7A` |
   | 4      | `#6D370B` | `#E9AD0C` |
   | 5      | `#12488B` | `#2A7BDE` |
   | 6      | `#A347BA` | `#C061CB` |
   | 7      | `#2AA1B3` | `#33C7DE` |
   | 8      | `#D0CFCC` | `#FFFFFF` |

2. Tick **Show bold text in bright colors**.

### 7.7 Check the look

1. Close the Preferences window and every terminal window.
2. Open a new terminal: dark purple background, the new font, prompt icons drawn properly.

---

## 8. Node

### 8.1 nvm v0.40.3

1. Run `curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | PROFILE=/dev/null bash`
   (`PROFILE=/dev/null` stops it editing your `.bashrc`, which already loads nvm.)
2. Close the terminal and open a new one.
3. Check: `nvm --version` shows `0.40.3`.

### 8.2 Node versions

1. Run `nvm install 16.20.2`
2. Run `nvm install 18.20.7`
3. Run `nvm install 20.19.5`
4. Run `nvm install 22.14.0`
5. Run `nvm install 22.23.4`
6. Check: `nvm ls` lists all five.

### 8.3 Default version: 22.14.0

1. Run `nvm alias default 22.14.0`
2. Open a new terminal. Check: `node --version` shows `v22.14.0`.

### 8.4 Angular CLI

1. Run `npm install -g @angular/cli`
2. Check: `ng version`

---

## 9. Python

### 9.1 uv

1. Run `curl -LsSf https://astral.sh/uv/install.sh | sh`
2. Open a new terminal. Check: `uv --version`

### 9.2 CrewAI (uv tool)

1. Run `uv tool install crewai`
2. Check: `crewai --version`

### 9.3 Your pip packages (22)

1. Run `pip3 install --user boto3 CairoSVG colorlog comm debugpy Flask ipython jupyter_client nest-asyncio openpyxl pandas psutil psycopg2-binary pydantic pytest python-docx python-dotenv python-pptx SQLAlchemy tabulate typer ulid-py`
2. If it's refused with *externally-managed-environment* (Ubuntu 23.04 and later), either:
   - run the same command with `--break-system-packages` added, or
   - install them per project in a virtual environment: `python3 -m venv .venv`, then
     `.venv/bin/pip install <packages>`.

### 9.4 pyenv and its plugins

1. Run `git clone https://github.com/pyenv/pyenv.git ~/.pyenv`
2. Run `git clone https://github.com/pyenv/pyenv-doctor.git ~/.pyenv/plugins/pyenv-doctor`
3. Run `git clone https://github.com/pyenv/pyenv-update.git ~/.pyenv/plugins/pyenv-update`
4. Run `git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv`

---

## 10. Vim and Neovim

### 10.1 Vim config

1. In Files, open `~/pc-migrate/data/vim/vim/` (Ctrl+H).
2. Copy `.vimrc`, `.ideavimrc` and the `.vim` folder into your home folder.
   - `.vimrc`: Vim config, with the **fzf** and **fzf.vim** plugins (vim-plug).
   - `.ideavimrc`: Vim keys inside IntelliJ (section 13).

### 10.2 Vim plugins

1. Open `vim`.
2. Type `:PlugInstall` and press Enter.
3. When it says done, type `:qa` to quit.

### 10.3 Neovim v0.12.4

1. Download <https://github.com/neovim/neovim/releases/download/v0.12.4/nvim-linux-x86_64.tar.gz>
2. In Files, create the folder `~/.local/bin` if it doesn't exist.
3. Extract the download into `~/.local/bin`. You get `~/.local/bin/nvim-linux-x86_64/`.
4. Make a shortcut so `nvim` works anywhere:
   `ln -s ~/.local/bin/nvim-linux-x86_64/bin/nvim ~/.local/bin/nvim`
5. Open a new terminal. Check: `nvim --version` starts with `NVIM v0.12.4`.

### 10.4 Neovim config

Your config is its own GitHub repo: `git@github.com:SofieneJOUINI/nvim.git`, branch `master`.

1. Run `git clone git@github.com:SofieneJOUINI/nvim.git ~/.config/nvim`
2. No GitHub access yet? Copy the folder `~/pc-migrate/data/vim/nvim/config` to `~/.config/` and
   rename it to `nvim`.

### 10.5 Plugin manager: packer

1. Run `git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim`

### 10.6 Neovim plugins (24)

Your plugins: cmp-buffer, cmp_luasnip, cmp-nvim-lsp, cmp-nvim-lua, cmp-path, friendly-snippets,
harpoon, indent-blankline, lsp-zero, LuaSnip, mason, mason-lspconfig, nvim-cmp, nvim-lspconfig,
nvim-tree, nvim-treesitter, nvim-web-devicons, playground, plenary, rose-pine, telescope,
toggleterm, undotree, vim-fugitive.

1. Open `nvim`. Errors about missing plugins are normal the first time: press Enter past them.
2. Type `:PackerSync` and press Enter.
3. Wait until the list shows every plugin as done, then `:qa`.
4. Open `nvim` again: no errors, rose-pine colors.

The exact commit of each plugin you had is in `~/pc-migrate/data/vim/nvim/plugins.lock`, if a
newer version breaks something.

### 10.7 Language servers (Mason)

1. Check Node works (section 8), then run `sudo apt install -y unzip wget`.
2. In `nvim`, type this and press Enter:
   `:MasonInstall eslint-lsp@4.10.0 jdtls@v1.38.0 json-lsp@4.10.0 typescript-language-server@4.3.3 typos@v1.24.6 typos-lsp@v0.1.23 yaml-language-server@1.15.0`
3. Wait until the Mason window shows all 7 as installed.
4. If one version can't be downloaded anymore (jdtls often), install the latest: `:MasonInstall jdtls`

### 10.8 Syntax parsers (Treesitter)

1. Run `sudo apt install -y gcc`
2. In `nvim`, type this and press Enter:
   `:TSInstall bash c css csv diff dockerfile git_config gitignore html ini java javascript json jsonc lua markdown markdown_inline properties python query requirements rust scss sql ssh_config tmux toml typescript vim vimdoc xml yaml`
3. Wait for the 32 parsers to finish, then `:qa`.

---

## 11. Git repositories

68 clones in total, at the same paths and branches as before. `.fzf` (6.8) and `.pyenv` (9.4)
are done in their own sections. Needs your SSH key (2.2).

If a clone fails with *Remote branch … not found*, that branch was merged and deleted, or never
pushed: run the same command without `-b <branch>` to get the default branch.

### 11.1 Personal and tools

1. `git clone -b main git@github.com:SofieneJOUINI/claude-skills.git ~/claude-skills`
2. `git clone -b master git@github.com:SofieneJOUINI/tools.git ~/tools`
3. `git clone -b master git@github.com:SofieneJOUINI/problem-solving.git ~/problemSolving/problem-solving`
4. `git clone -b master git@github.com:hendrixroa/mock-openapi-in-aws-api-gateway.git ~/apiGateWay/mock-openapi-in-aws-api-gateway`

### 11.2 `~/my_scripts`

1. `git clone -b main git@github.com:MnC-Aero/adad-monitoring-kpis.git ~/my_scripts/adad-monitoring-kpis`
2. `git clone -b main git@github.com:MnC-Aero/kpi_dashboard.git ~/my_scripts/adad-reconciliation-kpis`
3. `git clone -b main git@github.com:SofieneJOUINI/cost-auditor.git ~/my_scripts/cost-auditor`
4. `git clone -b main git@github.com:SofieneJOUINI/db-sync.git ~/my_scripts/db-sync`
5. `git clone -b main git@github.com:SofieneJOUINI/settlement-graph.git ~/my_scripts/settlement-graph-explorer`

### 11.3 `~/1A`

1. `git clone -b main git@github.com:automation-agentic-labs/dt-adm-pricing.git ~/1A/DT-pricing`
2. `git clone -b main git@github.com:SofieneJOUINI/flown-report-reconciliation.git ~/1A/flown-report-reconciliation`
3. `git clone -b main git@github.com:SofieneJOUINI/outward-billing-other-routing-coupons.git ~/1A/Interline/Outward_Other_Routing_Pattern`
4. `git clone -b main git@github.com:automation-agentic-labs/ku_reports.git ~/1A/ku_reports`
5. `git clone -b main git@github.com:automation-agentic-labs/sales-and-refunds-report.git ~/1A/sales-and-refund--report`

### 11.4 `~/mira-rep` (GitLab)

1. `git clone -b develop git@gitlab.cicd.adad.io:agentic-ai/mira-backend.git ~/mira-rep/mira-backend`
2. `git clone -b develop git@gitlab.cicd.adad.io:agentic-ai/mira-backoffice.git ~/mira-rep/mira-backoffice`
3. `git clone -b Fix/MIRA-429 git@gitlab.cicd.adad.io:agentic-ai/mira-chatbot.git ~/mira-rep/mira-chatbot`
4. `git clone git@gitlab.cicd.adad.io:agentic-ai/mira-db-migrations.git ~/mira-rep/mira-db-migrations`
   (it was on a detached commit, so no branch.)
5. `git clone -b master git@gitlab.cicd.adad.io:agentic-ai/mira-keycloak-cli.git ~/mira-rep/mira-keycloak-cli`
6. `git clone -b main git@gitlab.cicd.adad.io:agentic-ai/mira-local.git ~/mira-rep/mira-local`
7. `git clone -b main git@github.com:ed-donner/agents.git ~/mira-rep/ai-engineer-agentic-training/agents`

### 11.5 `~/adad_projects`

1. `git clone -b feature/ADAD-13287 git@github.com:MnC-Aero/adad-api.git ~/adad_projects/adad-api`
2. `git clone -b feature/ADAD-13619 git@github.com:MnC-Aero/adad-core.git ~/adad_projects/adad-core`
3. `git clone -b main git@github.com:MnC-Aero/adad-domain.git ~/adad_projects/adad-domain`
4. `git clone -b develop git@github.com:MnC-Aero/adad-frontend.git ~/adad_projects/adad-frontend`
5. `git clone -b develop git@github.com:MnC-Aero/adad-helm-configs.git ~/adad_projects/adad-helm-configs`
6. `git clone -b main git@github.com:MnC-Aero/adad-local.git ~/adad_projects/adad-local`
7. `git clone -b feature/ADAD-7474 git@github.com:MnC-Aero/adad-migration.git ~/adad_projects/adad-local/migration`
   (after step 6: it goes inside `adad-local`.)
8. `git clone -b develop git@github.com:MnC-Aero/adad-migration.git ~/adad_projects/adad-migration`
9. `git clone -b main git@github.com:MnC-Aero/adad-scripts.git ~/adad_projects/adad-scripts`
10. `git clone -b main git@github.com:MnC-Aero/adad-test-api.git ~/adad_projects/adad-test-api`
11. `git clone -b master git@github.com:MnC-Aero/batch-migration.git ~/adad_projects/batch-migration`
12. `git clone -b main git@github.com:MnC-Aero/-data-anonymization.git ~/adad_projects/data-anonymization`
13. `git clone -b master git@github.com:MnC-Aero/keycloak-cli.git ~/adad_projects/keycloak-cli`
14. `git clone -b main git@github.com:adorsys/keycloak-config-cli.git ~/adad_projects/keycloak-config-cli`
15. `git clone -b action/lock git@github.com:MnC-Aero/redis-reactive-cache.git ~/adad_projects/redis-reactive-cache`
16. `git clone -b main git@github.com:MnC-Aero/sale-accounting-reconicliation.git ~/adad_projects/sale-accounting-reconciliation-scripts`
17. `git clone -b main git@github.com:MnC-Aero/sk-exchange-rate-converter.git ~/adad_projects/sk-exchange-rate-converter`
18. `git clone -b fix/ADAD-10128 git@github.com:MnC-Aero/ssm-store.git ~/adad_projects/ssm-store`

### 11.6 `~/adad_projects/upstream` (main branch)

1. `git clone -b main git@github.com:MnC-Aero/accounting-module.git ~/adad_projects/upstream/accounting-module`
2. `git clone -b main git@github.com:MnC-Aero/audit-track.git ~/adad_projects/upstream/audit-track`
3. `git clone -b main git@github.com:MnC-Aero/bank-reconciliation.git ~/adad_projects/upstream/bank-reconciliation`
4. `git clone -b main git@github.com:MnC-Aero/secondary-matching.git ~/adad_projects/upstream/secondary-matching`
5. `git clone -b master git@github.com:MnC-Aero/events-dependency.git ~/adad_projects/upstream/events-dependency`
6. `git clone -b master git@github.com:MnC-Aero/master_data_cloner.git ~/adad_projects/upstream/master_data_cloner`

### 11.7 `~/adad_projects/upstream` (develop and feature branches)

1. `git clone -b develop git@github.com:MnC-Aero/data-enrichment-plugins.git ~/adad_projects/upstream/data-enrichment-plugins`
2. `git clone -b develop git@github.com:MnC-Aero/etl-module.git ~/adad_projects/upstream/etl-module`
3. `git clone -b develop git@github.com:MnC-Aero/featurization-module.git ~/adad_projects/upstream/featurization-module`
4. `git clone -b develop git@github.com:MnC-Aero/fees-module.git ~/adad_projects/upstream/fees-module`
5. `git clone -b develop git@github.com:MnC-Aero/file-watcher.git ~/adad_projects/upstream/file-watcher`
6. `git clone -b feature/ADAD-12380 git@github.com:MnC-Aero/ftp-uploader-module.git ~/adad_projects/upstream/ftp-uploader-module`
7. `git clone -b develop git@github.com:MnC-Aero/fx-rate-converter.git ~/adad_projects/upstream/fx-rate-converter`
8. `git clone -b develop git@github.com:MnC-Aero/hash-calculator.git ~/adad_projects/upstream/hash-calculator`
9. `git clone -b develop git@github.com:MnC-Aero/Integration-factory-core.git ~/adad_projects/upstream/Integration-factory-core`
10. `git clone -b develop git@github.com:MnC-Aero/integration-factory-interfaces.git ~/adad_projects/upstream/integration-factory-interfaces`
11. `git clone -b develop git@github.com:MnC-Aero/integration-factory-plugins.git ~/adad_projects/upstream/integration-factory-plugins`
12. `git clone -b develop git@github.com:MnC-Aero/kpi-module.git ~/adad_projects/upstream/kpi-module`
13. `git clone -b develop git@github.com:MnC-Aero/latam-accounting-module.git ~/adad_projects/upstream/latam-accounting-module`
14. `git clone -b develop git@github.com:MnC-Aero/latam-data-enrichment-module.git ~/adad_projects/upstream/latam-data-enrichment-module`
15. `git clone -b develop git@github.com:MnC-Aero/matching-module.git ~/adad_projects/upstream/matching-module`
16. `git clone -b develop git@github.com:MnC-Aero/monetary-amount-rounding.git ~/adad_projects/upstream/monetary-amount-rounding`
17. `git clone -b develop git@github.com:MnC-Aero/reporting-module.git ~/adad_projects/upstream/reporting-module`
18. `git clone -b feature/ADAD-12206 git@github.com:MnC-Aero/template-renderer.git ~/adad_projects/upstream/template-renderer`

### 11.8 `runUpstreamProjects.sh`

This script isn't in any repo, so nothing above restores it.

1. Copy `~/adad_projects/runUpstreamProjects.sh` from the old PC by USB stick.
2. Make it runnable: `chmod +x ~/adad_projects/runUpstreamProjects.sh`
3. Check: `run_adad_upstream_projects` starts it.

---

## 12. VS Code and Cursor

### 12.1 VS Code settings

1. Open VS Code once, then close it (this creates its settings folder).
2. In Files, copy `settings.json` and `mcp.json` from `~/pc-migrate/data/editors/code/` into
   `~/.config/Code/User/`, choose **Replace**.
3. Open VS Code. Check:
   - Theme: **Community Material Theme Palenight** (after 12.9)
   - Icons: **Material Icon Theme** (after 12.9)
   - Draw.io theme: **atlas**

### 12.2 VS Code extensions: the quick way

1. Click the account icon (bottom left) → **Backup and Sync Settings**, sign in with the same
   account as on the old PC.
2. If Settings Sync was on before, your 51 extensions come back by themselves: skip to 12.10.
   Otherwise do 12.3 to 12.9. For each ID: **Ctrl+Shift+X**, paste the ID, click **Install**.

### 12.3 Angular extensions

1. `angular.ng-template`
2. `johnpapa.angular2`
3. `loiane.angular-extension-pack`
4. `nrwl.angular-console`
5. `cyrilletuzi.angular-schematics`
6. `1tontech.angular-material`
7. `alexiv.vscode-angular2-files`
8. `angulardoc.angulardoc-vscode`
9. `infinity1207.angular2-switcher`
10. `john-crowson.angular-file-changer`
11. `obenjiro.arrr`

### 12.4 Java extensions

1. `redhat.java`
2. `vscjava.vscode-java-pack`
3. `vscjava.vscode-java-debug`
4. `vscjava.vscode-java-dependency`
5. `vscjava.vscode-java-test`
6. `vscjava.vscode-maven`
7. `vscjava.vscode-gradle`

### 12.5 JavaScript, TypeScript and test extensions

1. `dbaeumer.vscode-eslint`
2. `esbenp.prettier-vscode`
3. `firsttris.vscode-jest-runner`
4. `vitest.explorer`
5. `rctay.karma-problem-matcher`
6. `steoates.autoimport`
7. `stringham.move-ts`
8. `oouo-diogo-perdigao.docthis`
9. `simontest.simontest`
10. `quicktype.quicktype`

### 12.6 Git and AI extensions

1. `eamodio.gitlens`
2. `mhutchie.git-graph`
3. `github.copilot-chat`
4. `visualstudioexptteam.vscodeintellicode`
5. `visualstudioexptteam.intellicode-api-usage-examples`

### 12.7 Code quality extensions

1. `sonarsource.sonarlint-vscode`
2. `streetsidesoftware.code-spell-checker`
3. `gruntfuggly.todo-tree`
4. `editorconfig.editorconfig`

### 12.8 Editing extensions

1. `alefragnani.bookmarks`
2. `cardinal90.multi-cursor-case-preserve`
3. `christian-kohler.path-intellisense`
4. `formulahendry.auto-close-tag`
5. `formulahendry.auto-rename-tag`
6. `ue.alphabetical-sorter`
7. `pucelle.vscode-css-navigation`

### 12.9 Look and other extensions

1. `equinusocio.vsc-community-material-theme`
2. `pkief.material-icon-theme`
3. `humao.rest-client`
4. `hediet.vscode-drawio`
5. `asyncapi.asyncapi-preview`
6. `adpyke.vscode-sql-formatter`
7. `peter00.p5-project-creator`

### 12.10 Cursor settings

1. Open Cursor once, then close it.
2. Copy `settings.json` from `~/pc-migrate/data/editors/cursor/` into `~/.config/Cursor/User/`,
   choose **Replace**.

### 12.11 Cursor extensions (8)

For each ID: open Cursor's Extensions view, paste the ID, click **Install**.

1. `ms-python.python`
2. `anysphere.cursorpyright`
3. `ms-toolsai.jupyter`
4. `ms-toolsai.jupyter-renderers`
5. `ms-toolsai.vscode-jupyter-cell-tags`
6. `ms-toolsai.vscode-jupyter-slideshow`
7. `anysphere.remote-ssh`
8. `anysphere.remote-containers`

---

## 13. IntelliJ

Your settings come from **IntelliJIdea2026.2**.

### 13.1 Copy the settings before the first start

1. In Files, open `~/.config/` (Ctrl+H) and create a folder named `JetBrains`.
2. Copy the folder `~/pc-migrate/data/jetbrains/IntelliJIdea2026.2` into `~/.config/JetBrains/`.
3. The snap from 5.2 is the **Community** edition, which reads `IdeaIC2026.2` instead: if that's
   the one you use, rename the copied folder to `IdeaIC2026.2` (or the version it shows on first
   start).

### 13.2 First start

1. Start IntelliJ.
2. If it asks to import settings, choose the copied folder.

### 13.3 Code styles

1. **Settings** (Ctrl+Alt+S) → *Editor → Code Style*.
2. Check the *Scheme* list has **Adad** and **Influans**. Pick the one your project uses.

### 13.4 Color scheme and fonts

1. *Settings → Editor → Color Scheme*: your custom dark scheme is selected.
2. *Settings → Editor → Font* and *Tools → Terminal*: the fonts are as on the old PC.

### 13.5 Keymap

1. *Settings → Keymap*: your GNOME keymap with your custom **Redo** and **inline proposal**
   shortcuts is selected.

### 13.6 Memory

1. *Help → Change Memory Settings*: the value comes from your `idea64.vmoptions`.

### 13.7 Plugins

1. *Settings → Plugins → Marketplace*. Search and install each:
   1. **IdeaVim** (uses your `~/.ideavimrc` from 10.1)
   2. **Claude Code**
   3. **GitHub Copilot**
   4. **JHipster**
   5. **LSP4IJ**
   6. **OpenAPI Specifications**
   7. **Python** (or **Python Community Edition**)
2. *Settings → Plugins → Installed*: turn on the bundled ones you used, if you want them: AI
   Assistant, macOS keymap, Mercurial, Perforce, Subversion.
3. Restart IntelliJ.

---

## 14. Claude Code

### 14.1 Install

1. Run `curl -fsSL https://claude.ai/install.sh | bash`
2. Open a new terminal. Check: `claude --version`

### 14.2 Settings and plugins

1. In Files, create the folder `~/.claude` if it doesn't exist (Ctrl+H).
2. Copy `~/pc-migrate/data/claude/settings.json` into `~/.claude/`.
3. It holds your settings, enabled plugins and plugin marketplaces. The plugins install
   themselves the first time you run `claude`.

### 14.3 Skills

1. Copy the folder `~/pc-migrate/data/claude/skills` into `~/.claude/`.
2. You get your 3 skills: **clean-hexagonal-any-stack**, **clean-hexagonal-java**, **pr-review**.

### 14.4 Project memory

1. Copy the folder `~/pc-migrate/data/claude/projects` into `~/.claude/`.
2. It's Claude's memory for 6 projects: `1A/ku_reports`, `claude-skills`, `mira-backend`,
   `mira-backoffice`, `mira-db-migrations`, `mira-keycloak-cli`. Each only applies when the
   project is at the same path, which section 11 restores.

### 14.5 Sign in

1. Run `claude`.
2. Sign in when it asks.

---

## 15. App settings

Close each app before copying its settings, or it may overwrite them when it quits. Every folder
here is in `~/pc-migrate/data/apps/home/.config/` (Ctrl+H) and goes into `~/.config/`.

### 15.1 Flameshot

1. Copy the `flameshot` folder into `~/.config/`, choose **Replace**.

### 15.2 KeePassXC

1. Copy the `keepassxc` folder into `~/.config/`.
2. Open KeePassXC: it reopens `~/Documents/Settings/Passwords.kdbx` (2.6).

### 15.3 htop

1. Copy the `htop` folder into `~/.config/` (your columns and colors).

### 15.4 Parcellite (clipboard manager)

1. Copy the `parcellite` folder into `~/.config/`.

### 15.5 Sublime Text

1. Copy the `sublime-text` folder into `~/.config/`, choose **Merge** (your user settings and
   packages).

### 15.6 OBS Studio

1. Copy the `obs-studio` folder into `~/.config/` (your scenes and profiles).

### 15.7 Default apps

1. Copy `mimeapps.list` into `~/.config/` (which app opens which file type).

### 15.8 User folders

1. Copy `user-dirs.dirs` into `~/.config/` (where Documents, Downloads, ... are).

### 15.9 Launchers

1. Open `~/pc-migrate/data/apps/home/.local/share/applications/`.
2. Copy these 3 into `~/.local/share/applications/`: `com.anthropic.Claude.desktop`,
   `claude-code-url-handler.desktop`, `jetbrainsd.desktop`.

---

## 16. GNOME desktop

Everything here is in **Settings** (the gear app) unless said otherwise.

### 16.1 Keyboard layout

1. *Settings → Keyboard → Input Sources*.
2. Add **French (AZERTY)** and remove any other layout.

### 16.2 Num Lock on at login

1. Run `sudo apt install -y gnome-tweaks`
2. Open **Tweaks** → *Keyboard & Mouse*.
3. Turn **Num Lock** on.

### 16.3 Touchpad

1. *Settings → Mouse & Touchpad*.
2. Turn **Two-finger Scrolling** on.

### 16.4 Theme

1. *Settings → Appearance*.
2. Style: **Light**.
3. Color: **Bark** (gives the Yaru-bark theme and icons).

### 16.5 Battery percentage

1. *Settings → Power*.
2. Turn **Show Battery Percentage** on.

### 16.6 Screen never blanks

1. *Settings → Power* (or *Privacy → Screen*).
2. **Screen Blank**: **Never**.

### 16.7 No automatic suspend

1. *Settings → Power → Automatic Suspend*.
2. Turn it **off** both on battery and plugged in.
3. Turn **Automatic Power Saver** (on low battery) **off**.

### 16.8 Fractional scaling

1. *Settings → Displays*.
2. Turn **Fractional Scaling** on, then pick the scale you used (125% or 150%).

### 16.9 Dock position and size

1. *Settings → Appearance* (or *Ubuntu Desktop*) → *Dock*.
2. Position on screen: **Bottom**.
3. **Auto-hide the Dock**: on.
4. Icon size: **50**.

### 16.10 Dock favorites (22 apps)

1. Open each app, right-click its icon in the dock → **Pin to Dash**, in this order:
   1. KeePassXC
   2. pgAdmin 4
   3. Outlook
   4. Teams for Linux
   5. Lens
   6. Freelens
   7. FileZilla
   8. Files
   9. Terminal
   10. Peek
   11. Flameshot
   12. Ubuntu Software
   13. LibreOffice Calc
   14. RedisInsight
   15. IntelliJ IDEA Community
   16. draw.io
   17. Spotify
   18. Brave
   19. Sublime Text
   20. Cursor
   21. Google Chrome
   22. Claude
2. Drag the icons in the dock if the order is off.

### 16.11 Files: list view

1. Open **Files** → **☰** → **Preferences**.
2. Default view: **List View**.

### 16.12 Lock screen picture

Not captured by the project.

1. Copy `~/.local/share/backgrounds/2026-06-10-16-31-00-panda.png` from the old PC by USB stick
   into the same folder.
2. *Settings → Background* → **Add Picture** → pick it.

### 16.13 Text Editor (gedit)

1. Open **Text Editor** → **☰** → **Preferences** → *Fonts & Colors*.
2. Color scheme: **Yaru**.

### 16.14 Apply

1. Log out and back in.

---

## 17. Last resort: copy from the old PC

If the old PC still works, any file or folder can be copied straight across.

### 17.1 Prepare the old PC

1. On the old PC, run `sudo apt install -y openssh-server`
2. Note its address: `hostname -I`

### 17.2 Connect from the new PC

1. Open **Files** → **Other Locations**.
2. At the bottom, in *Connect to Server*, type `sftp://sofienejouini@<address>` and click
   **Connect**.
3. Enter your old PC password.
4. Browse the old PC's home folder and drag what you need across.
