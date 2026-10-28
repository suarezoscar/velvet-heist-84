#!/usr/bin/env bash
# Siguiente versión para la release automática de master (FEAT-023):
#   - si la versión base de project.godot (X.Y.Z) aún no tiene etiqueta, esa;
#   - si ya la tiene, la mayor X.Y.N etiquetada + 1 (las pre-releases, con guion, no cuentan).
# Así cada integración sube el último número, y cambiar la base en project.godot da el salto.
# Uso: tools/build/next_version.sh   (necesita las etiquetas: git fetch --tags)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/../.."

BASE="$(sed -n 's/^config\/version="\([0-9]*\.[0-9]*\.[0-9]*\)"$/\1/p' project.godot)"
if [[ -z "${BASE}" ]]; then
	echo "No hay una versión base X.Y.Z en project.godot (config/version)" >&2
	exit 1
fi
if ! git rev-parse -q --verify "refs/tags/v${BASE}" >/dev/null; then
	echo "${BASE}"
	exit 0
fi
MINOR="${BASE%.*}"
LAST="$(git tag -l "v${MINOR}.*" | grep -E "^v${MINOR//./\\.}\.[0-9]+$" | sed "s/^v${MINOR}\.//" | sort -n | tail -1)"
echo "${MINOR}.$((LAST + 1))"
