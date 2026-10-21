#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

echo "==> Checking GDScript files with godot --headless --check-only..."

FILES=("$@")
if [ ${#FILES[@]} -eq 0 ]; then
    mapfile -t FILES < <(find src core tests scenes -type f -name "*.gd" 2>/dev/null | sort)
fi

FAILED=0
CHECKED=0

for file in "${FILES[@]}"; do
    clean_file="${file#./}"
    if [ ! -f "${clean_file}" ]; then
        continue
    fi
    CHECKED=$((CHECKED + 1))
    if ! godot --headless --check-only -s "res://${clean_file}" > /tmp/godot_check.log 2>&1; then
        echo "FAIL: ${clean_file}"
        cat /tmp/godot_check.log
        FAILED=$((FAILED + 1))
    fi
done

rm -f /tmp/godot_check.log

if [ ${FAILED} -gt 0 ]; then
    echo "==> Error: ${FAILED}/${CHECKED} scripts failed check-only."
    exit 1
fi

echo "==> All ${CHECKED} scripts passed check-only successfully."
exit 0
