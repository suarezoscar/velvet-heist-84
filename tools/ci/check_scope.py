#!/usr/bin/env python3
"""Comprueba el alcance de una rama de paquete de Velvet Heist '84.

En una rama `feat/XXX-pkgN` (o `feat/XXX-pkgqa`):
  1. Cada archivo añadido, modificado o borrado está en el bloque `allowed` de PKG-N en
     docs/tasks/FEAT-XXX-*.md.
  2. Cada uno pertenece al agente del paquete según .agents/ownership.yml, salvo que su línea
     de `allowed` lleve "# excepción: <motivo>".

Uso: python3 tools/ci/check_scope.py [--staged] [--branch NOMBRE]
Una rama que no es de paquete se informa y termina con 0.
Base del diff: la rama de integración de la FEAT (local u origin/), si no $BASE_REF, si no
origin/master o master. Código de salida: 0 correcto, 1 fuera de alcance, 2 error de uso o datos.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

BRANCH_RE = re.compile(r"^feat/(\d{3})-pkg(\d+|qa)$")
EXCEPTION_RE = re.compile(r"#\s*excepci[oó]n", re.IGNORECASE)


def fail(message: str) -> None:
    print(f"[check_scope] {message}", file=sys.stderr)
    sys.exit(2)


def git(root: Path, *args: str) -> str:
    result = subprocess.run(["git", *args], cwd=root, text=True, capture_output=True)
    if result.returncode != 0:
        fail(f"git {' '.join(args)}: {result.stderr.strip()}")
    return result.stdout


def ref_exists(root: Path, ref: str) -> bool:
    result = subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", ref], cwd=root, capture_output=True
    )
    return result.returncode == 0


def glob_to_regex(pattern: str) -> re.Pattern[str]:
    """Glob de rutas: `**` cruza carpetas, `*` y `?` no."""
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pattern.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pattern[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pattern[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pattern[i]), i + 1
    return re.compile(f"^{out}$")


def parse_ownership_minimal(text: str) -> dict:
    """Lector del subconjunto de YAML que usa ownership.yml, por si falta PyYAML."""
    owners: dict[str, dict] = {}
    current, in_paths = None, False
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        stripped = line.strip()
        if indent == 2 and stripped.endswith(":"):
            current, in_paths = stripped[:-1], False
            owners[current] = {"paths": []}
        elif indent == 4 and current and stripped.startswith("paths:"):
            in_paths = True
        elif indent == 4 and current and ":" in stripped:
            in_paths = False
            key, value = stripped.split(":", 1)
            owners[current][key.strip()] = value.strip()
        elif indent >= 6 and in_paths and current and stripped.startswith("- "):
            owners[current]["paths"].append(stripped[2:].strip().strip("\"'"))
    return {"owners": owners}


def load_ownership(path: Path) -> dict[str, list[re.Pattern[str]]]:
    text = path.read_text(encoding="utf-8")
    try:
        import yaml  # type: ignore

        data = yaml.safe_load(text)
    except ImportError:
        data = parse_ownership_minimal(text)
    owners = data.get("owners") or {}
    return {
        name: [glob_to_regex(p) for p in (spec or {}).get("paths", [])]
        for name, spec in owners.items()
    }


def package_section(text: str, pkg: str) -> str:
    heading = re.compile(rf"^###\s+PKG-{re.escape(pkg)}\b.*$", re.IGNORECASE | re.MULTILINE)
    match = heading.search(text)
    if not match:
        fail(f"no encuentro la sección '### PKG-{pkg.upper()}' en la FEAT")
    rest = text[match.end():]
    end = re.search(r"^#{2,3}\s", rest, re.MULTILINE)
    return rest[: end.start()] if end else rest


def first_code_span(line: str) -> str | None:
    match = re.search(r"`([^`]+)`", line)
    return match.group(1).strip() if match else None


def package_agent(section: str) -> str:
    for line in section.splitlines():
        if re.search(r"\*\*(Sub)?[Aa]gente\s*/\s*rama\*\*", line):
            agent = first_code_span(line)
            if agent:
                return agent
    fail("el paquete no declara '**Agente / rama**: `<agente>` / `<rama>`'")
    return ""


def allowed_entries(section: str) -> list[tuple[re.Pattern[str], str, bool]]:
    block = re.search(r"```allowed\s*\n(.*?)```", section, re.DOTALL)
    if not block:
        fail("el paquete no tiene bloque ```allowed```")
    entries = []
    for raw in block.group(1).splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        pattern = line.split("#", 1)[0].strip()
        if pattern:
            entries.append((glob_to_regex(pattern), pattern, bool(EXCEPTION_RE.search(line))))
    if not entries:
        fail("el bloque allowed está vacío")
    return entries


def integration_branch(text: str) -> str | None:
    for line in text.splitlines():
        if "**Rama de integración**" in line:
            return first_code_span(line)
    return None


def resolve_base(root: Path, integration: str | None) -> str:
    candidates: list[str] = []
    if integration:
        candidates += [integration, f"origin/{integration}"]
    if os.environ.get("BASE_REF"):
        candidates.append(os.environ["BASE_REF"])
    candidates += ["origin/master", "master"]
    for ref in candidates:
        if ref_exists(root, ref):
            return ref
    fail(f"no encuentro ninguna base entre: {', '.join(candidates)}")
    return ""


def changed_files(root: Path, base: str, staged: bool) -> list[str]:
    if staged:
        out = git(root, "diff", "--cached", "--no-renames", "--name-only")
    else:
        merge_base = git(root, "merge-base", base, "HEAD").strip()
        out = git(root, "diff", "--no-renames", "--name-only", merge_base)
        out += git(root, "ls-files", "--others", "--exclude-standard")
    return sorted({line for line in out.splitlines() if line.strip()})


def current_branch(root: Path, explicit: str | None) -> str:
    for value in (
        explicit,
        os.environ.get("SCOPE_BRANCH"),
        os.environ.get("GITHUB_HEAD_REF"),
        os.environ.get("GITHUB_REF_NAME"),
    ):
        if value:
            return value
    return git(root, "rev-parse", "--abbrev-ref", "HEAD").strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--staged", action="store_true", help="solo lo preparado para commit")
    parser.add_argument("--branch", help="nombre de rama (por defecto, la actual)")
    args = parser.parse_args()

    root = Path(git(Path.cwd(), "rev-parse", "--show-toplevel").strip())
    branch = current_branch(root, args.branch)
    match = BRANCH_RE.match(branch)
    if not match:
        print(f"==> check_scope: '{branch}' no es una rama de paquete (feat/XXX-pkgN); se omite.")
        return 0
    num, pkg = match.group(1), match.group(2)

    feats = sorted((root / "docs" / "tasks").glob(f"FEAT-{num}-*.md"))
    if len(feats) != 1:
        fail(f"esperaba un único docs/tasks/FEAT-{num}-*.md y hay {len(feats)}")
    feat_text = feats[0].read_text(encoding="utf-8")
    section = package_section(feat_text, pkg)
    agent = package_agent(section)
    entries = allowed_entries(section)

    owners = load_ownership(root / ".agents" / "ownership.yml")
    if agent not in owners:
        fail(f"el agente '{agent}' no está en .agents/ownership.yml")

    base = resolve_base(root, integration_branch(feat_text))
    files = changed_files(root, base, args.staged)
    label = f"PKG-{pkg.upper()} de {feats[0].relative_to(root)} ({agent}), base {base}"
    if not files:
        print(f"==> check_scope: sin cambios en {label}.")
        return 0

    out_of_scope: list[str] = []
    not_owned: list[str] = []
    for path in files:
        matching = [(pattern, exc) for regex, pattern, exc in entries if regex.match(path)]
        if not matching:
            out_of_scope.append(path)
            continue
        if any(exc for _, exc in matching):
            continue
        if not any(regex.match(path) for regex in owners[agent]):
            not_owned.append(path)

    print(f"==> check_scope: {len(files)} archivos en {label}")
    if out_of_scope:
        print("==> Fuera del bloque allowed del paquete:")
        for path in out_of_scope:
            print(f"  - {path}")
    if not_owned:
        print(f"==> Permitidos por el paquete pero no son de '{agent}' (falta '# excepción: motivo'):")
        for path in not_owned:
            print(f"  - {path}")
    if out_of_scope or not_owned:
        return 1
    print("==> Alcance y propiedad correctos.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
