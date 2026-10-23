#!/usr/bin/env bash
# Lanza el servidor dedicado headless del PoC (FEAT-014).
# Uso: tools/net/run_server.sh [puerto]   (por defecto 7777)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

# El binario `godot` es el de la versión fijada en tools/ci/godot_version.env.
godot --headless --path "${PROJECT_ROOT}" -- --server --port "${1:-7777}"
