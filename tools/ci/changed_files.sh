#!/usr/bin/env bash
# Lista los archivos añadidos o modificados respecto a la base, uno por línea (sin borrados).
# Base: $BASE_REF, o la primera que exista de origin/master, master, origin/main, main.
# Incluye cambios sin commitear y archivos nuevos sin seguimiento.
# STAGED=1: solo los archivos preparados para commit (lo usa el hook de pre-commit).
# $1 (opcional): expresión regular para filtrar rutas, p. ej. '\.gd$'.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
FILTER="${1:-.}"

list_changes() {
    if [ "${STAGED:-0}" = "1" ]; then
        git diff --cached --name-only --diff-filter=ACMR
        return
    fi
    local base="${BASE_REF:-}"
    if [ -z "${base}" ]; then
        for candidate in origin/master master origin/main main; do
            if git rev-parse --verify --quiet "${candidate}" >/dev/null; then
                base="${candidate}"
                break
            fi
        done
    fi
    if [ -z "${base}" ] || ! git rev-parse --verify --quiet "${base}" >/dev/null; then
        echo "[changed_files] no encuentro la rama base '${base:-master}'; define BASE_REF" >&2
        exit 2
    fi
    local merge_base
    merge_base="$(git merge-base "${base}" HEAD)"
    git diff --name-only --diff-filter=ACMR "${merge_base}"
    git ls-files --others --exclude-standard
}

list_changes | { grep -E "${FILTER}" || true; } | sort -u | while IFS= read -r file; do
    if [ -f "${file}" ]; then
        printf '%s\n' "${file}"
    fi
done
