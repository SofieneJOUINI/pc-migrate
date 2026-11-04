#!/usr/bin/env python3
"""Strip literal secrets out of a shell file before it is committed.

    redact.py SRC DEST TEMPLATE

Secret values are dropped, never stored anywhere. Each one is replaced by a
variable, and the variable is listed (empty) in TEMPLATE so it can be filled
in by hand on the new machine:

  export KEYCLOAK_PASSWORD='...'        -> export KEYCLOAK_PASSWORD="$KEYCLOAK_PASSWORD_1"
  #export KEYCLOAK_PASSWORD="..."       -> same with _2, so uncommenting the line still works
  getToken() { curl --data password=... -> password="$GETTOKEN_PASSWORD"

Variable names come from the surrounding code, never from the value.
"""
import re
import sys

SECRET_NAME = re.compile(r"(PASS|PWD|TOKEN|SECRET|API_?KEY|PRIVATE|CREDENTIAL)", re.I)
EXPORT_LINE = re.compile(
    r"""^(?P<indent>\s*#?\s*)export\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)=(?P<value>'[^']*'|"(?:[^"\\]|\\.)*"|[^\s;#]*)\s*(?P<comment>#.*)?$"""
)
INLINE_KEY = re.compile(
    r"""(?P<key>\b(?:password|passwd|client_secret|client_assertion|api_?key|secret|access_token))=(?P<value>[^\s'"\\|;&$)]+)""",
    re.I,
)
FUNCTION_START = re.compile(r"^\s*(?:function\s+)?(?P<name>[A-Za-z_][\w-]*)\s*\(\)")
SOURCE_LINE = "[ -f ~/.secrets.env ] && . ~/.secrets.env  # pc-migrate: secrets live outside git"


def unquote(v):
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"":
        return v[1:-1]
    return v


def is_reference(value):
    return not value or value.startswith("$")


def inside_single_quotes(line, pos):
    return line[:pos].count("'") % 2 == 1


def env_name(*parts):
    return re.sub(r"\W", "_", "_".join(p for p in parts if p)).upper()


def redact(text, filename):
    out, wanted, manual = [], [], []
    used = {}
    func = None

    def new_var(base, where, numbered):
        used[base] = used.get(base, 0) + 1
        var = f"{base}_{used[base]}" if numbered or used[base] > 1 else base
        wanted.append((var, where))
        return var

    for lineno, line in enumerate(text.splitlines(keepends=True), 1):
        f = FUNCTION_START.match(line)
        if f:
            func = f["name"]
        where = f"{filename}:{lineno}"

        m = EXPORT_LINE.match(line.rstrip("\n"))
        if m and SECRET_NAME.search(m["name"]) and not is_reference(unquote(m["value"])):
            var = new_var(m["name"], where, numbered=True)
            comment = f' {m["comment"]}' if m["comment"] else ""
            out.append(f'{m["indent"]}export {m["name"]}="${var}"{comment}\n')
            continue

        def inline(mm):
            if inside_single_quotes(line, mm.start()):
                manual.append(lineno)
                return mm.group(0)
            var = new_var(env_name(func, mm["key"]), where, numbered=False)
            return f'{mm["key"]}="${var}"'

        out.append(INLINE_KEY.sub(inline, line))
    return "".join(out), wanted, manual


def main():
    src, dest, template = sys.argv[1:4]
    with open(src) as f:
        text = f.read()
    text, wanted, manual = redact(text, "~/" + src.rsplit("/", 1)[-1])
    if src.endswith(".bashrc") and SOURCE_LINE not in text:
        text = SOURCE_LINE + "\n" + text
    with open(dest, "w") as f:
        f.write(text)
    if wanted:
        with open(template, "a") as f:
            for var, where in wanted:
                f.write(f"export {var}=''  # {where}\n")
        print(f"removed {len(wanted)} secret(s)", file=sys.stderr)
    for n in manual:
        print(f"line {n}: secret inside single quotes, remove it by hand", file=sys.stderr)


if __name__ == "__main__":
    main()
