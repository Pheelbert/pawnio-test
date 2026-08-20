#!/usr/bin/env bash
# Refresh the vendored PawnIO headers from upstream (namazso/PawnIO.Modules).
# SPDX-License-Identifier: 0BSD
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/modules/include"
BASE="https://raw.githubusercontent.com/namazso/PawnIO.Modules/master/include"

mkdir -p "$DEST"
for f in core.inc util.inc ntstatus.inc native.inc extra.inc pawnio.inc; do
    curl -fsSL -o "$DEST/$f" "$BASE/$f"
    printf '  updated %-14s %s bytes\n' "$f" "$(wc -c <"$DEST/$f")"
done
echo "Done. Review 'git diff modules/include' before committing."
