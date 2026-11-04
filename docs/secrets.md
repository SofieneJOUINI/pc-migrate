# How secrets are handled

Three rules: passwords are never stored, keys never go to git, and every commit is checked.

## Passwords in your dotfiles are removed, not moved

On export, shell rc files (`.bashrc`, `.bash_aliases`, `.profile`, `.zshrc`, ...) go through
[`lib/redact.py`](../lib/redact.py). Every literal password or token, including ones in
commented-out lines, is replaced by a variable, and its value is thrown away:

```bash
export KEYCLOAK_PASSWORD='…'          →  export KEYCLOAK_PASSWORD="$KEYCLOAK_PASSWORD_7"
#export KEYCLOAK_PASSWORD="…"          →  #export KEYCLOAK_PASSWORD="$KEYCLOAK_PASSWORD_1"
getRemoteTokenDev() { … password=…    →  password="$GETREMOTETOKENDEV_PASSWORD"
```

Variable names come from the surrounding code (the export name, the function), never from the
value, so nothing about a password can be guessed from the repo.

The names are listed, with empty values, in `data/dotfiles/secrets.env.template`, each with the
file and line it came from. On the new PC, install copies it to `~/.secrets.env` (mode 600),
which the exported `.bashrc` sources first thing. Fill in the ones you still need.

Your dotfiles on the old PC are not changed.

## Keys and credentials travel in an encrypted bundle

[`config/bundle.txt`](../config/bundle.txt) lists what never goes to git: `~/.ssh`, `~/keys`,
`~/.aws`, `~/.kube`, `~/.m2/settings.xml`, the KeePassXC database, and the fonts (too big for
git). `./migrate bundle pack` puts them in one `tar.gz` encrypted with `gpg` (AES-256, your
passphrase). Move it by USB stick or `scp`. `.gitignore` refuses `*.gpg` files.

## Every commit is checked

`./migrate export` sets `core.hooksPath` to `hooks/`, so [`hooks/pre-commit`](../hooks/pre-commit)
runs [`lib/scan.py`](../lib/scan.py) on what you stage. It refuses the commit when it finds
private keys, AWS/GitHub/GitLab/Anthropic/OpenAI/Slack tokens, JWTs, or hard-coded passwords
(`KEY=value`, `key: "value"`, YAML `password: value`). Variable references, `os.environ`
lookups and `${PLACEHOLDER}`s are not flagged.

If a flagged line is safe, add the comment `pc-migrate: allow` to it.
