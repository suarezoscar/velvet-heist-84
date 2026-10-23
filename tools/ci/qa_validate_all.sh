#!/usr/bin/env bash
# tools/ci/qa_validate_all.sh
# Verificación de aceptación para FEAT-009 y FEAT-010 (Criterios 4, 5, 6 y 8).
# 1. validate_all.py sobre el repo y espera 0.
# 2. validate_all.py con ficha adicional sin .glb en directorio temporal y espera 1.
# 3. Comprobación con Blender de cobertura >= 2% en las previews de todas las fichas.
# 4. validate_all.py con .glb sin ficha técnica y espera 1 ('FAIL orphan_asset: sin ficha').
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

TMP_SPECS_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_SPECS_DIR}"' EXIT

echo "=== [QA] Paso 1: Ejecutar validate_all.py sobre el repositorio (Criterio 6) ==="
TMP_REPORTS_DIR="${TMP_SPECS_DIR}/reports"
blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/validate_all.py -- --reports-dir "${TMP_REPORTS_DIR}"
if [ ! -f "${TMP_REPORTS_DIR}/wood_wedge_validation.json" ]; then
    echo "==> Error: --reports-dir no generó los JSON de validación."
    exit 1
fi
echo "==> Paso 1 superado: validate_all.py terminó con código 0 y escribió los JSON de validación."

echo "=== [QA] Paso 2: Ejecutar validate_all.py ante ficha sin .glb (Criterio 6) ==="

cp tools/blender_scripts/specs/*.json "${TMP_SPECS_DIR}/"

cat <<'EOF' > "${TMP_SPECS_DIR}/missing_asset.json"
{
  "name": "missing_asset",
  "dimensions": [1.0, 1.0, 1.0],
  "pivot": "bottom_center",
  "max_triangles": 100,
  "materials": ["Steel80s"],
  "collision": false,
  "source": {
    "origin": "procedural",
    "url": "tools/blender_scripts/gen_core_assets.py",
    "license": "propia",
    "author": "velvet-heist-84"
  }
}
EOF

MISSING_LOG="${TMP_SPECS_DIR}/validate_missing.log"
STATUS=0
blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/validate_all.py -- --specs-dir "${TMP_SPECS_DIR}" > "${MISSING_LOG}" 2>&1 || STATUS=$?
cat "${MISSING_LOG}"

if [ "${STATUS}" -ne 1 ]; then
    echo "==> Error: se esperaba código 1 pero se obtuvo ${STATUS}."
    exit 1
fi

if ! grep -q "FAIL missing_asset" "${MISSING_LOG}"; then
    echo "==> Error: la salida de validate_all.py no contiene 'FAIL missing_asset'."
    exit 1
fi

echo "==> Paso 2 superado: validate_all.py devolvió código 1 y contiene 'FAIL missing_asset'."

echo "=== [QA] Paso 3: Comprobar cobertura de previews >= 2% (Criterio 8) ==="
CHECK_SCRIPT="${TMP_SPECS_DIR}/check_previews.py"
cat <<'EOF' > "${CHECK_SCRIPT}"
import json
import sys
from pathlib import Path

sys.path.insert(0, "tools/blender_scripts")
from render_preview import PREVIEW_MIN_COVERAGE, compute_coverage

specs_dir = Path("tools/blender_scripts/specs")
previews_dir = Path("assets/previews")

failed = False
count = 0
for spec_file in sorted(specs_dir.glob("*.json")):
    count += 1
    with open(spec_file, "r", encoding="utf-8") as f:
        spec = json.load(f)
    name = spec.get("name", spec_file.stem)
    preview_file = previews_dir / f"{name}_iso.png"
    if not preview_file.is_file():
        print(f"ERROR: Preview no encontrada para '{name}': {preview_file}", file=sys.stderr)
        failed = True
        continue

    cov = compute_coverage(str(preview_file))
    pct = cov * 100.0
    print(f"QA PREVIEW {name}: {pct:.2f}% (min {PREVIEW_MIN_COVERAGE * 100.0:.1f}%)")
    if cov < PREVIEW_MIN_COVERAGE:
        print(
            f"ERROR: Cobertura insuficiente para '{name}': {pct:.2f}% < {PREVIEW_MIN_COVERAGE * 100.0:.1f}%",
            file=sys.stderr,
        )
        failed = True

if count < 24:
    print(f"ERROR: Se esperaba comprobar al menos 24 previews, pero se encontraron {count}", file=sys.stderr)
    failed = True

if failed:
    sys.exit(1)

print(f"==> Cobertura de previews verificada en las {count} fichas.")
sys.exit(0)
EOF

blender -b --factory-startup --python-exit-code 1 -P "${CHECK_SCRIPT}"
echo "==> Paso 3 superado: todas las previews cumplen la cobertura mínima del 2%."

echo "=== [QA] Paso 4: Ejecutar validate_all.py ante .glb de primer nivel sin ficha (Criterio 5) ==="
TMP_MODELS_DIR="${TMP_SPECS_DIR}/models"
mkdir -p "${TMP_MODELS_DIR}"
cp assets/models/*.glb "${TMP_MODELS_DIR}/"
cp assets/models/wood_wedge.glb "${TMP_MODELS_DIR}/orphan_asset.glb"

ORPHAN_LOG="${TMP_SPECS_DIR}/validate_orphan.log"
STATUS_ORPHAN=0
blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/validate_all.py -- --models-dir "${TMP_MODELS_DIR}" > "${ORPHAN_LOG}" 2>&1 || STATUS_ORPHAN=$?
cat "${ORPHAN_LOG}"

if [ "${STATUS_ORPHAN}" -ne 1 ]; then
    echo "==> Error: se esperaba código 1 pero se obtuvo ${STATUS_ORPHAN}."
    exit 1
fi

if ! grep -q "FAIL orphan_asset: sin ficha" "${ORPHAN_LOG}"; then
    echo "==> Error: la salida de validate_all.py no contiene 'FAIL orphan_asset: sin ficha'."
    exit 1
fi

echo "==> Paso 4 superado: validate_all.py devolvió código 1 y contiene 'FAIL orphan_asset: sin ficha'."
echo "=== [QA] qa_validate_all.sh completado con éxito. ==="
