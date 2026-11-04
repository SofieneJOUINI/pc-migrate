#!/usr/bin/env python3
"""Scaffold a hexagonal / clean-architecture service.

Example:
    python3 scaffold.py --name billing-service --module billing --base-package com.acme.billing --output ~/projects
    python3 scaffold.py --name billing-service --multi-tenant --output ~/projects
"""
import argparse
import re
import shutil
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
TEMPLATES_DIR = SKILL_DIR / "templates"
OVERLAYS_DIR = SKILL_DIR / "overlays"
STACKS = tuple(sorted(path.name for path in TEMPLATES_DIR.iterdir() if path.is_dir()))
MODULE_PACKAGES = (
    "adapters",
    "commands",
    "database",
    "domain/entities",
    "domain/events",
    "domain/valueobjects",
    "errors",
    "ports",
    "queries",
    "services",
)
KEBAB_CASE = re.compile(r"^[a-z][a-z0-9]*(-[a-z0-9]+)*$")
JAVA_PACKAGE = re.compile(r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$")
PLACEHOLDER = re.compile(r"\{\{[A-Z_]+\}\}")
SINGLE_TENANT_NOTE = "Single-tenant: every request runs with a correlation id and a timestamp (`UseCaseContext`)."
MULTI_TENANT_NOTE = ("Multi-tenant: the tenant id is the first path segment (`/{tenantId}/...`). It is validated as a "
                     "`TenantId`, carried by `UseCaseContext` and every event, logged by the handlers, and every "
                     "tenant-owned table has a `tenant_id` column that all queries filter on.")


def parse_arguments():
    parser = argparse.ArgumentParser(description="Scaffold a hexagonal / clean-architecture service.")
    parser.add_argument("--name", required=True, help="project / artifactId in kebab-case, e.g. billing-service")
    parser.add_argument("--module", help="business module in kebab-case, e.g. billing (default: name without -service/-module)")
    parser.add_argument("--stack", default="java-spring", choices=STACKS, help="technology stack (default java-spring)")
    parser.add_argument("--base-package", default="com.example", help="root package (default com.example)")
    parser.add_argument("--group-id", help="Maven groupId (default: base package)")
    parser.add_argument("--version", default="0.0.1-SNAPSHOT", help="initial project version")
    parser.add_argument("--java-version", default="17", help="Java release (default 17)")
    parser.add_argument("--port", default="8080", help="HTTP port (default 8080)")
    parser.add_argument("--multi-tenant", action="store_true",
                        help="one deployment serves several tenants: tenant id in the context, events, logs and routes")
    parser.add_argument("--output", default=".", help="parent directory where the project folder is created")
    parser.add_argument("--force", action="store_true", help="overwrite an existing non-empty project directory")
    return parser.parse_args()


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def to_pascal_case(kebab):
    return "".join(part.capitalize() for part in kebab.split("-"))


def default_module_name(project_name):
    for suffix in ("-service", "-module", "-api"):
        if project_name.endswith(suffix) and project_name != suffix.lstrip("-"):
            return project_name.removesuffix(suffix)
    return project_name


def validate(arguments, module_kebab):
    if not KEBAB_CASE.match(arguments.name):
        fail(f"--name must be kebab-case, got '{arguments.name}'")
    if not KEBAB_CASE.match(module_kebab):
        fail(f"--module must be kebab-case, got '{module_kebab}'")
    if not JAVA_PACKAGE.match(arguments.base_package):
        fail(f"--base-package is not a valid package name: '{arguments.base_package}'")
    if arguments.multi_tenant and not multi_tenant_overlay_dir(arguments.stack).is_dir():
        fail(f"--multi-tenant is not available for the '{arguments.stack}' stack yet")


def build_replacements(arguments, module_kebab):
    tenant_prefix = "/{tenantId}" if arguments.multi_tenant else ""
    return {
        "{{PROJECT_NAME}}": arguments.name,
        "{{ARTIFACT_ID}}": arguments.name,
        "{{GROUP_ID}}": arguments.group_id or arguments.base_package,
        "{{VERSION}}": arguments.version,
        "{{JAVA_VERSION}}": arguments.java_version,
        "{{PORT}}": arguments.port,
        "{{BASE_PACKAGE}}": arguments.base_package,
        "{{BASE_PACKAGE_PATH}}": arguments.base_package.replace(".", "/"),
        "{{MODULE_PACKAGE}}": module_kebab.replace("-", ""),
        "{{MODULE_KEBAB}}": module_kebab,
        "{{APP_CLASS}}": f"{to_pascal_case(arguments.name)}Application",
        "{{DB_NAME}}": arguments.name.replace("-", "_"),
        "{{HEALTH_PATH}}": f"{tenant_prefix}/{module_kebab}/health",
        "{{HEALTH_EXAMPLE_PATH}}": f"{'/tenant-a' if arguments.multi_tenant else ''}/{module_kebab}/health",
        "{{TENANCY}}": MULTI_TENANT_NOTE if arguments.multi_tenant else SINGLE_TENANT_NOTE,
    }


def multi_tenant_overlay_dir(stack):
    return OVERLAYS_DIR / f"{stack}-multi-tenant"


def target_relative_path(template_relative_path, replacements):
    path = template_relative_path.as_posix()
    path = path.replace("__MAIN__", "src/main/java/__BASE__")
    path = path.replace("__TEST__", "src/test/java/__BASE__")
    path = path.replace("__BASE__", replacements["{{BASE_PACKAGE_PATH}}"])
    path = path.replace("__MODULE__", replacements["{{MODULE_PACKAGE}}"])
    path = path.replace("__APP__", replacements["{{APP_CLASS}}"])
    return Path(path)


def render(content, replacements):
    for placeholder, value in replacements.items():
        content = content.replace(placeholder, value)
    return content


def copy_template_tree(template_root, project_dir, replacements):
    for template_file in sorted(template_root.rglob("*")):
        if not template_file.is_file():
            continue
        destination = project_dir / target_relative_path(template_file.relative_to(template_root), replacements)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(render(template_file.read_text(encoding="utf-8"), replacements), encoding="utf-8")


def create_module_packages(project_dir, replacements):
    module_root = (project_dir / "src/main/java" / replacements["{{BASE_PACKAGE_PATH}}"]
                   / "modules" / replacements["{{MODULE_PACKAGE}}"])
    for package in MODULE_PACKAGES:
        package_dir = module_root / package
        package_dir.mkdir(parents=True, exist_ok=True)
        if not any(package_dir.iterdir()):
            (package_dir / ".gitkeep").touch()


def find_unrendered_placeholders(project_dir):
    return [
        path for path in project_dir.rglob("*")
        if path.is_file() and PLACEHOLDER.search(path.read_text(encoding="utf-8", errors="ignore"))
    ]


def prepare_project_dir(project_dir, force):
    if project_dir.exists() and any(project_dir.iterdir()):
        if not force:
            fail(f"'{project_dir}' already exists and is not empty (use --force to overwrite)")
        shutil.rmtree(project_dir)
    project_dir.mkdir(parents=True, exist_ok=True)


def print_next_steps(project_dir, replacements):
    print(f"Created project in {project_dir}")
    print(f"  application class : {replacements['{{BASE_PACKAGE}}']}.{replacements['{{APP_CLASS}}']}")
    print(f"  business module   : {replacements['{{BASE_PACKAGE}}']}.modules.{replacements['{{MODULE_PACKAGE}}']}")
    print(f"  health check      : GET {replacements['{{HEALTH_PATH}}']}")
    print("Next steps:")
    print(f"  cd {project_dir}")
    print("  mvn test -Dtest='!ContainersTest' -Dsurefire.failIfNoSpecifiedTests=false")
    print("  then build the first slice test-first (see SKILL.md, workflow B)")


def main():
    arguments = parse_arguments()
    module_kebab = arguments.module or default_module_name(arguments.name)
    validate(arguments, module_kebab)
    replacements = build_replacements(arguments, module_kebab)

    project_dir = Path(arguments.output).expanduser().resolve() / arguments.name
    prepare_project_dir(project_dir, arguments.force)
    copy_template_tree(TEMPLATES_DIR / arguments.stack, project_dir, replacements)
    if arguments.multi_tenant:
        copy_template_tree(multi_tenant_overlay_dir(arguments.stack), project_dir, replacements)
    create_module_packages(project_dir, replacements)

    unrendered = find_unrendered_placeholders(project_dir)
    if unrendered:
        fail("unrendered placeholders remain in: " + ", ".join(str(path) for path in unrendered))
    print_next_steps(project_dir, replacements)


if __name__ == "__main__":
    main()
