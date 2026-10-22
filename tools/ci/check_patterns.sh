#!/usr/bin/env bash
# Busca patrones prohibidos por la regla 01 en GDScript.
#   ./tools/ci/check_patterns.sh         Archivos .gd cambiados respecto a la base: bloqueante.
#   ./tools/ci/check_patterns.sh --all   Todo src/ core/ scenes/ tests/: informe no bloqueante.
# Con STAGED=1 revisa solo los archivos preparados para commit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

# Pares: expresión regular | qué hacer en su lugar
PATTERNS=(
    'get_parent\(\)\.get_parent\(\)'
    "get_parent().get_parent(): comunica por SignalBus o inyecta con @export"
    "[\"']/root/"
    "ruta absoluta /root/: usa el autoload por su nombre, SignalBus o @export"
)

ALL=0
if [ "${1:-}" = "--all" ]; then
    ALL=1
    mapfile -t FILES < <(find src core scenes tests -type f -name "*.gd" 2>/dev/null | sort)
else
    CHANGED="$("${SCRIPT_DIR}/changed_files.sh" '\.gd$')" || exit 2
    mapfile -t FILES < <(printf '%s\n' "${CHANGED}" | grep -vE '^addons/|^$' || true)
fi

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "==> check_patterns: no hay archivos .gd que revisar."
    exit 0
fi

FOUND=0
for ((i = 0; i < ${#PATTERNS[@]}; i += 2)); do
    regex="${PATTERNS[i]}"
    advice="${PATTERNS[i + 1]}"
    if hits="$(grep -nE "${regex}" "${FILES[@]}" /dev/null)"; then
        FOUND=1
        echo "==> Prohibido: ${advice}"
        printf '%s\n' "${hits}"
    fi
done

if [ "${FOUND}" -ne 0 ]; then
    if [ "${ALL}" -eq 1 ]; then
        echo "==> AVISO: hay patrones prohibidos en el código heredado (informe no bloqueante)."
        exit 0
    fi
    echo "==> Error: patrones prohibidos en archivos cambiados."
    exit 1
fi
echo "==> check_patterns: sin patrones prohibidos (${#FILES[@]} archivos)."
