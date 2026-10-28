#!/usr/bin/env bash
# Imprime la versión del juego para una compilación (FEAT-023):
#   - la variable VERSION si viene dada (la pipeline de release la saca de la etiqueta vX.Y.Z);
#   - la etiqueta vX.Y.Z si HEAD es exactamente esa etiqueta;
#   - si no, la versión base de project.godot con «-dev+<commit>» (compilación local).
# Uso: tools/build/version.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ -n "${VERSION:-}" ]]; then
	echo "${VERSION#v}"
	exit 0
fi
cd "${PROJECT_ROOT}"
if TAG="$(git describe --tags --exact-match --match 'v[0-9]*' 2>/dev/null)"; then
	echo "${TAG#v}"
	exit 0
fi
BASE="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)"
SHA="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
echo "${BASE:-0.0.0}-dev+${SHA}"
