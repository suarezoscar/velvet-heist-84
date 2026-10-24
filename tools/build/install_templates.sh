#!/usr/bin/env bash
# Descarga e instala las plantillas de exportación oficiales de la versión de Godot fijada en
# tools/ci/godot_version.env (unos 1 GB). Hace falta una vez por máquina antes de exportar.
# Uso: tools/build/install_templates.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../ci/godot_version.env
source "${SCRIPT_DIR}/../ci/godot_version.env"

TARGET="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
if [[ -f "${TARGET}/version.txt" ]]; then
	echo "==> Plantillas ${GODOT_VERSION} ya instaladas en ${TARGET}"
	exit 0
fi

URL="https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE_TAG}/Godot_v${GODOT_RELEASE_TAG}_export_templates.tpz"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

echo "==> Descargando ${URL}"
curl -fL --progress-bar -o "${WORK}/templates.tpz" "${URL}"
echo "==> Instalando en ${TARGET}"
mkdir -p "${TARGET}"
unzip -q "${WORK}/templates.tpz" -d "${WORK}/unzipped"
cp -r "${WORK}/unzipped/templates/." "${TARGET}/"
echo "==> Listo: $(cat "${TARGET}/version.txt")"
