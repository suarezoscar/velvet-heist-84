#!/usr/bin/env bash
# Exporta Velvet Heist '84 para Linux y/o Windows (presets de export_presets.cfg) y deja un
# paquete por plataforma en build/ (Linux .tar.gz, Windows .zip) con el juego, el script para
# arrancar el servidor y un LEEME. Los paquetes llevan la versión en el nombre
# (tools/build/version.sh); la versión se graba en el juego solo durante la exportación.
# Uso: [VERSION=X.Y.Z] tools/build/export.sh [linux|windows|all]   (por defecto all)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../ci/godot_version.env
source "${SCRIPT_DIR}/../ci/godot_version.env"
TARGETS="${1:-all}"
TEMPLATES="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.stable"

if [[ ! -f "${TEMPLATES}/version.txt" ]]; then
	echo "Faltan las plantillas de exportación de Godot ${GODOT_VERSION}."
	echo "Instálalas una vez con: tools/build/install_templates.sh"
	exit 1
fi

cd "${PROJECT_ROOT}"
GAME_VERSION="$("${SCRIPT_DIR}/version.sh")"
echo "==> Versión ${GAME_VERSION}"
# Graba la versión en project.godot mientras se exporta y deja el archivo como estaba al salir
cp project.godot build.project.godot.bak
trap 'mv -f build.project.godot.bak project.godot' EXIT
sed -i "s/^config\/version=.*/config\/version=\"${GAME_VERSION}\"/" project.godot
mkdir -p build
rm -f build/VelvetHeist84-*.tar.gz build/VelvetHeist84-*.zip
echo "==> Importando recursos"
godot --headless --path . --import >/dev/null 2>&1 || true

export_one() {
	local preset="$1" dir="$2" binary="$3"
	rm -rf "build/${dir}"
	mkdir -p "build/${dir}"
	echo "==> Exportando ${preset}"
	godot --headless --path . --export-release "${preset}" "build/${dir}/${binary}" 2>&1 \
		| grep -E "ERROR|WARNING|DONE" | grep -v "MCPServer\|MCPRegistry" || true
	{ echo "Versión ${GAME_VERSION}"; echo; cat "${SCRIPT_DIR}/package/LEEME.txt"; } \
		>"build/${dir}/LEEME.txt"
	cp "${SCRIPT_DIR}/package/${4}" "build/${dir}/"
	chmod +x "build/${dir}/${binary}" "build/${dir}/${4}" 2>/dev/null || true
	package "${dir}"
}

# Linux en .tar.gz (conserva los permisos de ejecución); Windows en .zip
package() {
	local dir="$1"
	if [[ "${dir}" == "linux" ]]; then
		tar -czf "build/VelvetHeist84-${GAME_VERSION}-${dir}.tar.gz" -C build "${dir}"
		echo "==> build/VelvetHeist84-${GAME_VERSION}-${dir}.tar.gz"
	else
		(cd build && python3 -m zipfile -c "VelvetHeist84-${GAME_VERSION}-${dir}.zip" "${dir}")
		echo "==> build/VelvetHeist84-${GAME_VERSION}-${dir}.zip"
	fi
}

if [[ "${TARGETS}" == "linux" || "${TARGETS}" == "all" ]]; then
	export_one "Linux" "linux" "VelvetHeist84.x86_64" "servidor.sh"
fi
if [[ "${TARGETS}" == "windows" || "${TARGETS}" == "all" ]]; then
	export_one "Windows" "windows" "VelvetHeist84.exe" "servidor.bat"
fi
