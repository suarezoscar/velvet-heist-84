#!/usr/bin/env bash
# Analiza un log de Godot en busca de errores y códigos de fallo de importación o compilación.
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    echo "Uso: $0 <log>" >&2
    exit 2
fi

LOG_FILE="$1"

ERRORS="$(sed 's/\x1b\[[0-9;]*m//g' "${LOG_FILE}" | grep -nE 'ERROR:|SCRIPT ERROR|Parse Error|Failed loading resource' || true)"

if [ -n "${ERRORS}" ]; then
    echo "==> Errores en el log de Godot:"
    echo "${ERRORS}"
    exit 1
fi

exit 0
