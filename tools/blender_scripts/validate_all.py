#!/usr/bin/env python3
"""
tools/blender_scripts/validate_all.py
Validador por lotes de assets 3D para Velvet Heist '84 (FEAT-009).

Uso:
  blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/validate_all.py -- [--reports-dir <ruta>] [--specs-dir <ruta>]
"""

import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

SCRIPT_DIR = Path(__file__).resolve().parent
WORKSPACE_DIR = SCRIPT_DIR.parent.parent

for p in [str(SCRIPT_DIR), str(SCRIPT_DIR / "lib")]:
    if p not in sys.path:
        sys.path.insert(0, p)

try:
    import bpy
    from validate_asset import BLENDER_VERSION_ENV, check_blender_version, validate_asset
except ImportError as e:
    print(f"Error importando dependencias: {e}", file=sys.stderr)
    sys.exit(1)


def parse_arguments() -> Tuple[Optional[Path], Path, Path]:
    """Parsea los argumentos pasados tras '--'."""
    argv = sys.argv
    user_args = []
    if "--" in argv:
        user_args = argv[argv.index("--") + 1 :]

    reports_dir = None
    specs_dir = SCRIPT_DIR / "specs"
    models_dir = WORKSPACE_DIR / "assets" / "models"

    i = 0
    while i < len(user_args):
        arg = user_args[i]
        if arg == "--reports-dir" and i + 1 < len(user_args):
            reports_dir = Path(user_args[i + 1]).resolve()
            i += 2
        elif arg == "--specs-dir" and i + 1 < len(user_args):
            specs_dir = Path(user_args[i + 1]).resolve()
            i += 2
        elif arg == "--models-dir" and i + 1 < len(user_args):
            models_dir = Path(user_args[i + 1]).resolve()
            i += 2
        else:
            i += 1

    return reports_dir, specs_dir, models_dir


def main():
    ok, msg = check_blender_version(BLENDER_VERSION_ENV)
    if not ok:
        print(f"Error: {msg}", file=sys.stderr)
        sys.exit(2)

    reports_dir, specs_dir, models_dir = parse_arguments()

    if not specs_dir.is_dir():
        print(f"Error: El directorio de fichas no existe: {specs_dir}", file=sys.stderr)
        sys.exit(1)

    spec_files = sorted(specs_dir.glob("*.json"))

    if reports_dir:
        reports_dir.mkdir(parents=True, exist_ok=True)

    results: List[Dict[str, Any]] = []
    processed_names = set()

    for spec_file in spec_files:
        try:
            with open(spec_file, "r", encoding="utf-8") as f:
                spec_data = json.load(f)
        except Exception as e:
            name = spec_file.stem
            res = {
                "asset": name,
                "checks": [{"name": "spec_schema", "pass": False, "detail": f"Error leyendo ficha JSON: {e}"}],
                "pass": False,
            }
            results.append(res)
            processed_names.add(name)
            print(f"FAIL {name}: spec_schema")
            continue

        name = spec_data.get("name") or spec_file.stem
        processed_names.add(name)
        glb_path = models_dir / f"{name}.glb"

        if not glb_path.is_file():
            res = {
                "asset": name,
                "checks": [{"name": "execution", "pass": False, "detail": f"Archivo GLB no encontrado: {glb_path}"}],
                "pass": False,
            }
            results.append(res)
            print(f"FAIL {name}: execution")
            if reports_dir:
                report_path = reports_dir / f"{name}_validation.json"
                with open(report_path, "w", encoding="utf-8") as rf:
                    json.dump(res, rf, indent=2, ensure_ascii=False)
            continue

        try:
            res = validate_asset(str(glb_path), spec_data)
        except Exception as e:
            res = {
                "asset": name,
                "checks": [{"name": "execution", "pass": False, "detail": f"Excepción durante validación: {e}"}],
                "pass": False,
            }

        results.append(res)

        if res["pass"]:
            print(f"PASS {name}")
        else:
            failed_checks = [c["name"] for c in res.get("checks", []) if not c.get("pass", False)]
            failed_str = ", ".join(failed_checks) if failed_checks else "desconocido"
            print(f"FAIL {name}: {failed_str}")

        if reports_dir:
            report_path = reports_dir / f"{name}_validation.json"
            with open(report_path, "w", encoding="utf-8") as rf:
                json.dump(res, rf, indent=2, ensure_ascii=False)

    # Modelos GLB de primer nivel sin ficha se cuentan como fallo
    if models_dir.is_dir():
        first_level_glbs = sorted(p.stem for p in models_dir.glob("*.glb"))
        for glb_name in first_level_glbs:
            if glb_name not in processed_names:
                res = {
                    "asset": glb_name,
                    "checks": [{"name": "spec_schema", "pass": False, "detail": "Archivo GLB de primer nivel sin ficha técnica."}],
                    "pass": False,
                }
                results.append(res)
                print(f"FAIL {glb_name}: sin ficha")
                if reports_dir:
                    report_path = reports_dir / f"{glb_name}_validation.json"
                    with open(report_path, "w", encoding="utf-8") as rf:
                        json.dump(res, rf, indent=2, ensure_ascii=False)

    total = len(results)
    passed_count = sum(1 for r in results if r["pass"])
    print(f"==> {passed_count}/{total} assets en pass")

    if passed_count == total and total > 0:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
