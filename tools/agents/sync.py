#!/usr/bin/env python3
"""Genera los subagentes de Claude Code y opencode desde la fuente única.

Fuente: .agents/agents/<n>.md (también es un subagente válido de Antigravity).
Generados: .claude/agents/<n>.md y .opencode/agents/<n>.md.
Con --check no escribe nada y sale con 1 si algún generado difiere.
"""
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
FUENTE = RAIZ / ".agents" / "agents"
AVISO = "<!-- Generado por tools/agents/sync.py desde .agents/agents/{n}.md; no editar a mano. -->\n"

# Herramientas de Claude Code según el nivel de permisos neutral.
HERRAMIENTAS_CLAUDE = {
    "lectura": "Read, Grep, Glob, Bash",
    "escritura-docs": "Read, Grep, Glob, Write, Edit, Bash",
}

BASH_LECTURA = [
    "git status*", "git diff*", "git log*", "git show *", "git branch --list*",
    "ls*", "cat *", "head *", "tail *", "grep *", "find *", "wc *",
]
BASH_COMPROBACION = ["./tools/ci/*"]
RUTAS_DOCS = ["docs/gdd/*", "docs/playtests/*", "data/balance/*", "data/loot_tables/*", "data/levels/*"]


def leer_fuente(ruta: Path) -> tuple[dict, str]:
    m = re.match(r"---\n(.*?)\n---\n(.*)", ruta.read_text(encoding="utf-8"), re.S)
    if not m:
        sys.exit(f"{ruta}: falta el frontmatter")
    meta = {}
    for linea in m.group(1).splitlines():
        if re.match(r"^[A-Za-z]+:", linea):
            k, _, v = linea.partition(":")
            meta[k.strip()] = v.strip()
    for campo in ("name", "description", "permisos"):
        if campo not in meta:
            sys.exit(f"{ruta}: falta «{campo}» en el frontmatter")
    if meta["permisos"] not in HERRAMIENTAS_CLAUDE:
        sys.exit(f"{ruta}: permisos desconocidos «{meta['permisos']}»")
    return meta, m.group(2)


def para_claude(meta: dict, cuerpo: str) -> str:
    cab = (f"---\nname: {meta['name']}\ndescription: {meta['description']}\n"
           f"tools: {HERRAMIENTAS_CLAUDE[meta['permisos']]}\nmodel: opus\n---\n")
    return cab + AVISO.format(n=meta["name"]) + cuerpo


def bash_opencode(reglas: list[str]) -> str:
    # El comodín va primero: gana la última regla que coincide.
    return '  bash:\n    "*": deny\n' + "".join(f'    "{r}": allow\n' for r in reglas)


def para_opencode(meta: dict, cuerpo: str) -> str:
    if meta["permisos"] == "lectura":
        permiso = "  edit: deny\n" + bash_opencode(BASH_LECTURA + BASH_COMPROBACION)
    else:
        permiso = '  edit:\n    "*": deny\n' + "".join(f'    "{r}": allow\n' for r in RUTAS_DOCS)
        permiso += bash_opencode(BASH_LECTURA)
    cab = (f"---\ndescription: {meta['description']}\nmode: subagent\npermission:\n"
           f"{permiso}  webfetch: deny\n---\n")
    return cab + AVISO.format(n=meta["name"]) + cuerpo


def main() -> int:
    comprobar = "--check" in sys.argv[1:]
    distintos = []
    for fuente in sorted(FUENTE.glob("*.md")):
        meta, cuerpo = leer_fuente(fuente)
        n = meta["name"]
        salidas = {
            RAIZ / ".claude" / "agents" / f"{n}.md": para_claude(meta, cuerpo),
            RAIZ / ".opencode" / "agents" / f"{n}.md": para_opencode(meta, cuerpo),
        }
        for ruta, texto in salidas.items():
            actual = ruta.read_text(encoding="utf-8") if ruta.exists() else None
            if actual == texto:
                continue
            distintos.append(ruta.relative_to(RAIZ))
            if not comprobar:
                ruta.parent.mkdir(parents=True, exist_ok=True)
                ruta.write_text(texto, encoding="utf-8")
    if comprobar and distintos:
        print("Desactualizados (ejecuta python3 tools/agents/sync.py):")
        for d in distintos:
            print(f"  {d}")
        return 1
    print("Subagentes al día." if comprobar else f"Generados: {len(distintos)} archivo(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
