#!/usr/bin/env bash
# Tests de aceptación para el analizador de logs de Godot (scan_godot_log.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCAN_SCRIPT="${SCRIPT_DIR}/scan_godot_log.sh"
FIXTURES_DIR="${PROJECT_ROOT}/tests/fixtures/ci"

cd "${PROJECT_ROOT}"

FAILED=0

run_test_code() {
    local name="$1"
    local expected_code="$2"
    shift 2
    local code=0
    set +e
    "${SCAN_SCRIPT}" "$@" >/dev/null 2>&1
    code=$?
    set -e
    if [ "${code}" -eq "${expected_code}" ]; then
        echo "PASS ${name}"
    else
        echo "FAIL ${name}"
        FAILED=1
    fi
}

run_test_output_contains() {
    local name="$1"
    local expected_substr="$2"
    shift 2
    local output=""
    set +e
    output="$("${SCAN_SCRIPT}" "$@" 2>&1)"
    set -e
    if [[ "${output}" == *"${expected_substr}"* ]]; then
        echo "PASS ${name}"
    else
        echo "FAIL ${name}"
        FAILED=1
    fi
}

# 1. clean -> código 0
run_test_code "clean" 0 "${FIXTURES_DIR}/godot_log_clean.log"

# 2. error -> código 1
run_test_code "error" 1 "${FIXTURES_DIR}/godot_log_error.log"

# 3. error_ansi -> código 1
run_test_code "error_ansi" 1 "${FIXTURES_DIR}/godot_log_error_ansi.log"

# 4. script_error -> código 1
run_test_code "script_error" 1 "${FIXTURES_DIR}/godot_log_script_error.log"

# 5. parse_error -> código 1
run_test_code "parse_error" 1 "${FIXTURES_DIR}/godot_log_parse_error.log"

# 6. failed_resource -> código 1
run_test_code "failed_resource" 1 "${FIXTURES_DIR}/godot_log_failed_resource.log"

# 7. no_args -> código 2
run_test_code "no_args" 2

# 8. missing_file -> código 2
run_test_code "missing_file" 2 "tests/fixtures/ci/no_existe.log"

# 9. prints_line -> la salida contiene broken.glb
run_test_output_contains "prints_line" "broken.glb" "${FIXTURES_DIR}/godot_log_error.log"

if [ "${FAILED}" -ne 0 ]; then
    exit 1
fi
exit 0
