#!/usr/bin/env bash
# Lint y formato de GDScript con gdtoolkit (configuración en gdlintrc y gdformatrc).
#   ./tools/ci/lint.sh         Archivos .gd cambiados respecto a la base: bloqueante.
#   ./tools/ci/lint.sh --all   Todo src/ core/ scenes/ tests/: informe no bloqueante de la deuda heredada.
# Con STAGED=1 revisa solo los archivos preparados para commit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

if ! command -v gdlint >/dev/null 2>&1 || ! command -v gdformat >/dev/null 2>&1; then
    echo "==> Error: faltan gdlint/gdformat. Instala gdtoolkit: pip install gdtoolkit==4.5.0"
    exit 2
fi

if [ "${1:-}" = "--all" ]; then
    echo "==> Informe completo (no bloqueante)"
    gdformat --check src/ core/ scenes/ tests/ || echo "AVISO: gdformat encuentra diferencias de formato."
    gdlint src/ core/ scenes/ tests/ || echo "AVISO: gdlint encuentra avisos."
    exit 0
fi

CHANGED="$("${SCRIPT_DIR}/changed_files.sh" '\.gd$')" || exit 2
mapfile -t FILES < <(printf '%s\n' "${CHANGED}" | grep -vE '^addons/|^$' || true)
if [ "${#FILES[@]}" -eq 0 ]; then
    echo "==> lint: no hay archivos .gd cambiados."
    exit 0
fi

STATUS=0
echo "==> gdformat --check (${#FILES[@]} archivos cambiados)"
gdformat --check "${FILES[@]}" || STATUS=1
echo "==> gdlint (${#FILES[@]} archivos cambiados; máximo 300 líneas por archivo)"
gdlint "${FILES[@]}" || STATUS=1

if [ "${STATUS}" -ne 0 ]; then
    echo "==> Error: lint o formato fallan en archivos cambiados. 'gdformat <archivo>' corrige el formato."
    exit 1
fi
echo "==> Lint y formato correctos en los archivos cambiados."
