#!/usr/bin/env bash
# Empaqueta con Velopack (FEAT-036) lo que deja export.sh en build/windows y build/linux:
# el instalador de Windows (VelvetHeist84-win-Setup.exe), el AppImage de Linux y los paquetes
# e índices (releases.win.json, releases.linux.json) con los que el juego se actualiza desde
# el menú. Con GITHUB_TOKEN baja antes el índice y el paquete completo de la última release
# para calcular los paquetes de diferencias y seguir el índice. Todo queda en build/velopack.
# Requiere vpk (dotnet tool install -g vpk --version VPK_VERSION) y mksquashfs (squashfs-tools).
# Uso: VERSION=X.Y.Z [GITHUB_TOKEN=…] tools/build/velopack.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO_URL="https://github.com/suarezoscar/velvet-heist-84"
PACK_ID="VelvetHeist84"
TITLE="Velvet Heist '84"
OUT="build/velopack"

cd "${PROJECT_ROOT}"
: "${VERSION:?Falta VERSION (X.Y.Z)}"
for dir in build/windows build/linux; do
	if [[ ! -d "${dir}" ]]; then
		echo "Falta ${dir}: ejecuta antes tools/build/export.sh"
		exit 1
	fi
done
rm -rf "${OUT}"
mkdir -p "${OUT}"

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
	echo "==> Última release (para las diferencias)"
	vpk "[win]" download github --repoUrl "${REPO_URL}" --token "${GITHUB_TOKEN}" \
		--channel win --outputDir "${OUT}" || echo "Sin paquetes de Windows anteriores"
	vpk "[linux]" download github --repoUrl "${REPO_URL}" --token "${GITHUB_TOKEN}" \
		--channel linux --outputDir "${OUT}" || echo "Sin paquetes de Linux anteriores"
fi

echo "==> Windows"
vpk "[win]" pack --runtime win-x64 --packId "${PACK_ID}" --packVersion "${VERSION}" \
	--packDir build/windows --mainExe VelvetHeist84.exe --packTitle "${TITLE}" \
	--outputDir "${OUT}"
echo "==> Linux"
vpk "[linux]" pack --runtime linux-x64 --packId "${PACK_ID}" --packVersion "${VERSION}" \
	--packDir build/linux --mainExe VelvetHeist84.x86_64 --packTitle "${TITLE}" \
	--outputDir "${OUT}"
ls -la "${OUT}"
