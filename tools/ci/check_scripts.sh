#!/usr/bin/env bash
# Compila los scripts GDScript dentro del proyecto (con autoloads) y falla ante cualquier error.
# Sin argumentos revisa src/, core/, tests/ y scenes/; con argumentos, solo esos archivos.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

echo "==> Compilando scripts GDScript con los autoloads del proyecto..."

FILES=("$@")
if [ ${#FILES[@]} -eq 0 ]; then
    mapfile -t FILES < <(find src core tests scenes -type f -name "*.gd" 2>/dev/null | sort)
fi

RES_PATHS=()
for file in "${FILES[@]}"; do
    clean_file="${file#./}"
    clean_file="${clean_file#res://}"
    if [ -f "${clean_file}" ]; then
        RES_PATHS+=("res://${clean_file}")
    fi
done

LOG="$(mktemp)"
trap 'rm -f "${LOG}"' EXIT

STATUS=0
godot --headless -s res://tools/ci/check_scripts.gd -- "${RES_PATHS[@]}" > "${LOG}" 2>&1 || STATUS=$?

# Godot también informa de errores de compilación por stderr sin cambiar el código de salida
if grep -E "SCRIPT ERROR|Parse Error|Compile Error|^FAIL:" "${LOG}"; then
    STATUS=1
fi
grep -E "^==>" "${LOG}" || true

if [ ${STATUS} -ne 0 ]; then
    echo "==> Error: hay scripts que no compilan."
    exit 1
fi
echo "==> Todos los scripts compilan correctamente."
