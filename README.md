# pc-migrate

My whole Linux setup as code: packages, shell, Vim/Neovim, editors, IDE settings,
Claude Code, every git clone, GNOME. One command captures it, one command rebuilds it.

```bash
./migrate export          # old PC: capture everything into data/
./migrate install         # new PC: rebuild it, asking before each module
```

No password is ever stored, in git or anywhere else. Keys and credentials travel in an
encrypted bundle on a USB stick. See [docs/secrets.md](docs/secrets.md).

## Project layout

```
pc-migrate/
├── migrate               the CLI: export, install, status, bundle, scan, test
├── config/               WHAT to migrate: plain lists, edit these instead of code
│   ├── dotfiles.txt      files under ~ for the dotfiles module
│   ├── apps.txt          app config folders for the apps module
│   ├── dconf.txt         GNOME settings trees
│   ├── repos-ignore.txt  folders the repos module never searches
│   └── bundle.txt        secrets + large files that go in the encrypted bundle
├── modules/              HOW: one file per module, each with <name>_export and <name>_install
├── lib/                  shared code: common.sh (helpers), bundle.sh, redact.py, scan.py
├── data/                 captured state, written by export, one folder per module
├── hooks/pre-commit      refuses commits that contain a secret
├── tests/                unit tests + a Docker trial install
└── docs/                 guides
```

## Modules

Installed in this order (`./migrate list` prints the same):

| Module      | Captures                                                                                    |
|-------------|---------------------------------------------------------------------------------------------|
| `packages`  | apt packages you added, third-party apt repos + keys, snaps, flatpaks                        |
| `dotfiles`  | bash, git, tmux, starship (passwords removed), + zoxide, starship, fzf, aws cli it needs     |
| `node`      | nvm, every Node version, the default, global npm packages                                   |
| `python`    | `pip --user` packages, `uv` tools                                                           |
| `vim`       | Vim + Neovim: config, every plugin at its exact commit, Mason tools, Treesitter parsers, nvim release |
| `repos`     | every git clone under `~`, recloned to the same path                                        |
| `editors`   | VS Code + Cursor settings, keybindings, snippets, `mcp.json`, extensions                    |
| `jetbrains` | newest IntelliJ config: keymaps, code styles, templates, colors, options                    |
| `claude`    | Claude Code settings, skills, agents, commands, project memory                              |
| `apps`      | flameshot, keepassxc, htop, sublime, obs, default apps, launchers                           |
| `gnome`     | shortcuts, dock, appearance, keyboard/touchpad, terminal profiles, extensions               |

Details per module, and how to add one: [docs/modules.md](docs/modules.md).

## Commands

| Command                              | Where   | What                                                         |
|--------------------------------------|---------|--------------------------------------------------------------|
| `./migrate export [module...]`       | old PC  | capture into `data/`, then warn about unpushed work          |
| `./migrate status [module...]`       | any     | what changed on this PC since the last export                |
| `./migrate bundle pack [FILE]`       | old PC  | encrypt keys, credentials and fonts into one file            |
| `./migrate bundle unpack FILE`       | new PC  | restore that file into `~` (replaced files are backed up)    |
| `./migrate install [module...]`      | new PC  | rebuild; `--dry-run` to preview, `--yes` to skip questions   |
| `./migrate scan [PATH...]`           | any     | look for secrets (also runs before every commit)             |
| `./migrate test`                     | any     | unit tests                                                   |
| `./migrate test docker [VERSION]`    | any     | trial install on a throwaway Ubuntu container                |

## Moving to a new PC

Step by step, with the things to check before you wipe the old disk:
[docs/new-pc.md](docs/new-pc.md).
