#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

echo "==> Running GUT tests in headless mode..."
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit "$@"
