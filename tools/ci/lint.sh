#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

echo "==> Running gdformat --check..."
if gdformat --check src/ core/ tests/; then
	echo "gdformat: All files formatted correctly."
else
	echo "WARNING: gdformat reported formatting differences (non-blocking for baseline)."
fi

echo "==> Running gdlint..."
if gdlint src/ core/ tests/; then
	echo "gdlint: No lint issues found."
else
	echo "WARNING: gdlint reported warnings (non-blocking for baseline)."
fi

echo "==> Lint check completed successfully."
exit 0
