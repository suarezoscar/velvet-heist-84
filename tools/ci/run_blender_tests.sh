#!/usr/bin/env bash
# Ejecuta la suite del validador de assets en Blender headless y propaga su código de salida.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

STATUS=0
blender -b --factory-startup --python-exit-code 1 -P tools/blender_scripts/test_validator.py \
    || STATUS=$?

if [ "${STATUS}" -ne 0 ]; then
    echo "==> Error: fallan tests del validador."
    exit "${STATUS}"
fi
echo "==> Tests del validador en verde."
