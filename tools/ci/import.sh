#!/usr/bin/env bash
# Importa el proyecto en headless y falla si Godot sale con error o informa de errores en el log.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

LOG="$(mktemp)"
trap 'rm -f "${LOG}"' EXIT

echo "==> Running Godot import in headless mode..."
STATUS=0
godot --headless --import 2>&1 | tee "${LOG}" || STATUS=$?

# Godot sale con 0 aunque informe de errores de importación: se analiza el log completo
"${SCRIPT_DIR}/scan_godot_log.sh" "${LOG}" || STATUS=1

if [ "${STATUS}" -ne 0 ]; then
    echo "==> Error: la importación de Godot tiene errores."
    exit 1
fi
echo "==> Godot import completed successfully."
