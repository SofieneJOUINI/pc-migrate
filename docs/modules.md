# Modules

Each module is one file in [`modules/`](../modules/) with two functions:

- `<name>_export` copies state from this PC into `data/<name>/`
- `<name>_install` restores it from `data/<name>/` onto this PC

They are built on helpers from [`lib/common.sh`](../lib/common.sh): `grab SRC DEST` (PC → repo),
`put SRC DEST` (repo → PC, backing up what it replaces), `run CMD` (skipped in `--dry-run`),
`need_pkgs`, `config_list NAME`. The install order is `MODULES` in [`migrate`](../migrate).

## packages
`data/packages/`: `apt.txt` (packages you installed on top of a fresh Ubuntu, from
`apt-mark showmanual` minus the installer's list), `apt-sources/` + `apt-keys/` (third-party
repos and their signing keys), `snap.txt` (name, channel, classic), `flatpak*.txt`.
Install adds the repos and keys first, then installs what exists, and lists what doesn't (apps
installed from a downloaded `.deb`). Delete lines from `apt.txt` to leave packages behind.

## dotfiles
`data/dotfiles/home/`: the files in [`config/dotfiles.txt`](../config/dotfiles.txt). Shell rc
files have their passwords removed ([secrets.md](secrets.md)). Install also installs the tools
the shell runs at startup if they're missing: zoxide (`cd` is aliased to it), starship, fzf, AWS CLI.

## node
`data/node/`: every nvm Node version, the default, global npm packages.

## python
`data/python/`: top-level `pip --user` packages and `uv` tools.

## vim
Restores Vim and Neovim exactly as they are, not "latest":

| File in `data/vim/`    | Content                                                             |
|------------------------|---------------------------------------------------------------------|
| `vim/.vimrc`, `.ideavimrc`, `.vim/` | config and vim-plug (`plugged/`, `undodir/` left out)  |
| `vim/plugins.lock`     | each vim-plug plugin: name, url, commit                              |
| `nvim/config/`         | full copy of `~/.config/nvim`                                        |
| `nvim/config.git`      | its GitHub remote, branch and commit                                 |
| `nvim/version`         | the Neovim release (e.g. `v0.12.4`)                                  |
| `nvim/plugins.lock`    | every plugin (packer, paq or lazy.nvim): path, url, commit           |
| `nvim/mason.lock`      | each Mason tool and its version                                      |
| `nvim/treesitter.txt`  | installed Treesitter parsers                                         |

Install, in order:
1. Vim config, then `:PlugInstall` (runs post-install hooks), then each plugin checked out at its commit.
2. The same Neovim release from GitHub into `~/.local/bin`.
3. The config copied to `~/.config/nvim`, then relinked to its GitHub repo so you can keep
   pushing (needs the SSH key: unpack the bundle first, or rerun later).
4. Every plugin cloned at its exact commit.
5. `packer_compiled.lua` is rebuilt if your home folder path changed (it stores absolute paths).
6. Treesitter parsers built with `:TSInstallSync` (installs `gcc`).
7. Mason tools at their versions with `:MasonInstall` (installs `unzip`, `wget`; npm-based
   tools need the node module, which runs first).

## repos
`data/repos/repos.tsv`: path, remote and branch of every git clone under `~` (4 levels deep,
minus [`config/repos-ignore.txt`](../config/repos-ignore.txt)). Export warns about uncommitted
files, commits on no remote, and repos with no remote: work that would die with the disk.

## editors
`data/editors/{code,cursor}/`: settings, keybindings, snippets, `mcp.json`, extension list.

## jetbrains
`data/jetbrains/<IDE dir>/`: options, keymaps, code styles, templates, colors from the most
recently used IDE (machine-specific files like recent projects left out), plus the plugin list.
Restored under the same folder name, so a newer IDE offers to import it.

## claude
`data/claude/`: Claude Code `settings.json`, skills, agents, commands, keybindings, and
per-project memory. Credentials are left out: sign in again.

## apps
`data/apps/home/`: the paths in [`config/apps.txt`](../config/apps.txt), plus custom launchers
from `~/.local/share/applications`.

## gnome
`data/gnome/dconf/*.ini`: one `dconf dump` per tree in [`config/dconf.txt`](../config/dconf.txt),
restored with `dconf load`. Plus user shell extensions.

## Adding a module

1. Create `modules/<name>.sh` with `MODULE_DESC[<name>]="..."`, `<name>_export` writing to
   `$DATA_DIR/<name>/`, and `<name>_install`.
2. Add `<name>` to `MODULES` in `migrate`, where its install should run.
3. If it tracks a list of paths, put the list in `config/<name>.txt` and read it with `config_list`.
4. Check it: `./migrate export <name>`, `./migrate install --dry-run <name>`, `./migrate test docker 24.04 <name>`.
