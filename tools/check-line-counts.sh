#!/usr/bin/env bash
# Fails if any src/**/*.zig file exceeds the project's 500-line-per-file
# limit (see CLAUDE.md). Run via `zig build lint` or directly.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

LIMIT=500
violations=0

while IFS= read -r -d '' f; do
  lines=$(wc -l < "$f")
  if [ "$lines" -gt "$LIMIT" ]; then
    echo "  $f: $lines lines (limit $LIMIT)"
    violations=$((violations + 1))
  fi
done < <(find src -name '*.zig' -print0)

if [ "$violations" -gt 0 ]; then
  echo "FAIL: $violations file(s) over the ${LIMIT}-line limit"
  exit 1
fi

echo "OK: all src/**/*.zig files are within the ${LIMIT}-line limit"
