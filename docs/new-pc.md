# Moving to a new PC

## 1. On the old PC

```bash
cd ~/pc-migrate
./migrate export
```

Read the warnings at the end of the `repos` section. Any repo with uncommitted files, unpushed
commits or no remote at all exists **only on this disk**. Commit and push those first, then
export again until the warning is gone.

Check what changed, then commit and push this project:

```bash
git status
git add -A
git commit -m "export $(hostname)"
git push
```

The pre-commit hook scans what you commit and refuses it if it finds a secret.

Make the encrypted bundle (keys, credentials, KeePassXC database, fonts):

```bash
./migrate bundle pack
```

It asks for a passphrase and writes `~/pc-migrate-bundle-<date>.tar.gz.gpg`. Copy it to a USB
stick. Save the passphrase in KeePassXC: without it the file can't be opened.

## 2. On the new PC

Restore the bundle first. It holds the SSH key that lets you clone your private repos.
Only `gpg` and `tar` are needed, both preinstalled on Ubuntu:

```bash
gpg -d /media/$USER/<usb>/pc-migrate-bundle-*.tar.gz.gpg | tar -xz -C ~
chmod 700 ~/.ssh && chmod 600 ~/.ssh/* ~/keys/*
```

Clone this project and preview the install:

```bash
sudo apt install -y git
git clone git@github.com:<you>/pc-migrate.git ~/pc-migrate
cd ~/pc-migrate
./migrate install --dry-run
```

Then run it. It asks before each module:

```bash
./migrate install
```

Anything it replaces is saved first in `~/.pc-migrate-backup/<timestamp>/`.

## 3. Finish by hand

- **Passwords:** `~/.secrets.env` lists every password removed from your dotfiles, with empty
  values and where each is used. Fill in the ones you still need from KeePassXC.
- **GNOME:** log out and back in.
- **IntelliJ:** start it and accept the settings import, then reinstall the plugins the
  `jetbrains` module lists.
- **Claude Code:** run `claude` and sign in.
- **Apps from .deb files:** the `packages` module prints the ones it couldn't find in any repo
  (VPN clients, agents, ...). Download those from their vendors.

## Later

Keep the project current on whichever PC you use:

```bash
./migrate status
./migrate export
```
