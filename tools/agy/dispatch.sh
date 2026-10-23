#!/usr/bin/env bash
# Lanza un paquete PKG de una FEAT en un ejecutor headless (agy u opencode) dentro de su propio worktree.
#
# Uso: tools/agy/dispatch.sh FEAT-007 1 gameplay-engineer [--feedback ruta.md] [--executor agy|opencode]
#      tools/agy/dispatch.sh 007 qa qa-engineer
#
# Rama del paquete: feat/<num>-pkg<N|qa>, creada desde la rama de integración que declara la FEAT
# (por defecto master). La FEAT debe estar commiteada en esa rama.
# Salida: resumen en stdout; salida y stderr completos del ejecutor en .agy-runs/.
# Código de salida: 0 si el ejecutor terminó bien; distinto de 0 en cualquier otro caso.
set -euo pipefail

usage() { sed -n '2,10p' "$0" >&2; exit 2; }
[ $# -ge 3 ] || usage

ROOT="$(git rev-parse --show-toplevel)"
cd "${ROOT}"
# shellcheck source=/dev/null
source "${ROOT}/tools/agy/config.env"

FEAT_ARG="$1"; PKG_ARG="$2"; AGENT="$3"; shift 3
FEEDBACK=""
while [ $# -gt 0 ]; do
    case "$1" in
        --feedback) FEEDBACK="${2:?falta la ruta tras --feedback}"; shift 2 ;;
        --executor) EXECUTOR="${2:?falta agy u opencode tras --executor}"; shift 2 ;;
        *) echo "[dispatch] argumento desconocido: $1" >&2; usage ;;
    esac
done

NUM="$(printf '%s' "${FEAT_ARG}" | grep -oE '[0-9]{3}' | head -n1 || true)"
[ -n "${NUM}" ] || { echo "[dispatch] no reconozco el número de FEAT en '${FEAT_ARG}'" >&2; exit 2; }
PKG="$(printf '%s' "${PKG_ARG}" | tr '[:upper:]' '[:lower:]' | sed 's/^pkg-\{0,1\}//')"
[[ "${PKG}" =~ ^([0-9]+|qa)$ ]] || { echo "[dispatch] paquete inválido: ${PKG_ARG} (usa un número o qa)" >&2; exit 2; }
PKG_LABEL="PKG-$(printf '%s' "${PKG}" | tr '[:lower:]' '[:upper:]')"

mapfile -t FEAT_FILES < <(ls docs/tasks/FEAT-"${NUM}"-*.md 2>/dev/null || true)
[ "${#FEAT_FILES[@]}" -eq 1 ] || { echo "[dispatch] esperaba un único docs/tasks/FEAT-${NUM}-*.md y hay ${#FEAT_FILES[@]}" >&2; exit 2; }
FEAT_FILE="${FEAT_FILES[0]}"

EXECUTOR="${EXECUTOR:-agy}"
case "${EXECUTOR}" in
    agy)
        [ -n "${AGY_MODEL}" ] || { echo "[dispatch] AGY_MODEL está vacío en tools/agy/config.env (mira 'agy models')" >&2; exit 2; }
        command -v agy >/dev/null 2>&1 || { echo "[dispatch] no encuentro 'agy' en el PATH" >&2; exit 2; } ;;
    opencode)
        [ -n "${OPENCODE_MODEL:-}" ] || { echo "[dispatch] OPENCODE_MODEL está vacío en tools/agy/config.env (mira 'opencode models')" >&2; exit 2; }
        command -v opencode >/dev/null 2>&1 || { echo "[dispatch] no encuentro 'opencode' en el PATH" >&2; exit 2; } ;;
    *) echo "[dispatch] ejecutor desconocido: ${EXECUTOR} (usa agy u opencode)" >&2; exit 2 ;;
esac

# Rama de integración declarada en la cabecera de la FEAT: "- **Rama de integración**: `feat/XXX-slug`"
INTEGRATION="$(grep -m1 -E '^- \*\*Rama de integración\*\*' "${FEAT_FILE}" | grep -oE '`[^`]+`' | head -n1 | tr -d '`' || true)"
INTEGRATION="${INTEGRATION:-master}"
git rev-parse --verify --quiet "refs/heads/${INTEGRATION}" >/dev/null \
    || { echo "[dispatch] la rama de integración '${INTEGRATION}' no existe: créala con la FEAT commiteada" >&2; exit 2; }
git cat-file -e "${INTEGRATION}:${FEAT_FILE}" 2>/dev/null \
    || { echo "[dispatch] ${FEAT_FILE} no está commiteada en ${INTEGRATION}" >&2; exit 2; }

BRANCH="feat/${NUM}-pkg${PKG}"
WT_BASE="${AGY_WORKTREES:-$(dirname "${ROOT}")/$(basename "${ROOT}")-worktrees}"
WT_DIR="${WT_BASE}/${NUM}-pkg${PKG}"
mkdir -p "${WT_BASE}"
if [ ! -d "${WT_DIR}" ]; then
    if git rev-parse --verify --quiet "refs/heads/${BRANCH}" >/dev/null; then
        git worktree add "${WT_DIR}" "${BRANCH}" >&2
    else
        git worktree add -b "${BRANCH}" "${WT_DIR}" "${INTEGRATION}" >&2
    fi
fi

PROMPT="Eres el agente ${AGENT} de Velvet Heist '84. Ejecuta el paquete ${PKG_LABEL} de ${FEAT_FILE} en esta rama (${BRANCH}). Sigue .agents/rules/00-ejecucion-de-paquetes.md y termina con su informe de entrega."
if [ "${EXECUTOR}" = "opencode" ] || [ "${AGY_USE_AGENT_FLAG}" != "1" ]; then
    PROMPT="Lee .agents/agents/${AGENT}.md y actúa como ese agente. ${PROMPT}"
fi
ROUND=1
if [ -n "${FEEDBACK}" ]; then
    [ -f "${FEEDBACK}" ] || { echo "[dispatch] no existe ${FEEDBACK}" >&2; exit 2; }
    ROUND=$(( $(find "${ROOT}/.agy-runs" -maxdepth 1 -name "${NUM}-pkg${PKG}-*.err" 2>/dev/null | wc -l) + 1 ))
    PROMPT="${PROMPT}

Vuelta ${ROUND}. El revisor pidió estos cambios; aplícalos sin salir del bloque allowed del paquete:
$(cat "${FEEDBACK}")"
fi

mkdir -p "${ROOT}/.agy-runs"
LOG="${ROOT}/.agy-runs/${NUM}-pkg${PKG}-$(date +%Y%m%d-%H%M%S)"
echo "[dispatch] ${PKG_LABEL} de ${FEAT_FILE} → ${AGENT} con ${EXECUTOR} en ${WT_DIR} (rama ${BRANCH}, vuelta ${ROUND})" >&2

EXIT=0
if [ "${EXECUTOR}" = "opencode" ]; then
    # stdin cerrado: opencode run espera un mensaje por stdin si no es un terminal
    ( cd "${WT_DIR}" && OPENCODE_CONFIG="${ROOT}/tools/agy/opencode.json" \
        timeout --kill-after=60s "${OPENCODE_TIMEOUT:-60m}" opencode run --standalone -m "${OPENCODE_MODEL}" \
        --format json "${PROMPT}" </dev/null ) >"${LOG}.jsonl" 2>"${LOG}.err" || EXIT=$?
    python3 "${ROOT}/tools/agy/summarize_opencode.py" "${LOG}.jsonl" "${EXIT}" "${LOG}.err"
    exit $?
fi

ARGS=(-p "${PROMPT}" --model "${AGY_MODEL}" --output-format json --print-timeout "${AGY_TIMEOUT}")
if [ "${AGY_USE_AGENT_FLAG}" = "1" ]; then ARGS+=(--agent "${AGENT}"); fi
# shellcheck disable=SC2206
EXTRA=(${AGY_EXTRA_FLAGS})
ARGS+=("${EXTRA[@]}")

( cd "${WT_DIR}" && agy "${ARGS[@]}" ) >"${LOG}.json" 2>"${LOG}.err" || EXIT=$?

python3 - "${LOG}.json" "${LOG}.err" "${EXIT}" <<'PY'
import json, re, sys
out_path, err_path, agy_exit = sys.argv[1], sys.argv[2], int(sys.argv[3])
raw = open(out_path, encoding="utf-8", errors="replace").read().strip()
err = open(err_path, encoding="utf-8", errors="replace").read()
status, response, error = "SIN_JSON", "", ""
try:
    data = json.loads(raw) if raw else {}
    status = str(data.get("status", "SIN_STATUS"))
    response = str(data.get("response") or "")
    error = str(data.get("error") or "")
except json.JSONDecodeError:
    response = raw[-4000:]
denied = [l for l in err.splitlines() if re.search(r"denied|permission|not allowed", l, re.I)]
print(f"agy_exit={agy_exit} status={status}")
if error:
    print(f"error={error}")
if denied:
    print("AVISO: comandos o herramientas denegados al ejecutor:")
    for l in denied[:20]:
        print(f"  {l}")
print(f"log={out_path}")
print("----- informe del ejecutor -----")
print(response)
sys.exit(0 if (agy_exit == 0 and status == "SUCCESS") else 1)
PY
