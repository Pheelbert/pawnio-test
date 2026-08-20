#!/usr/bin/env bash
#
# build.sh — compile every modules/*.p into build/*.amx.
#
# This is the compiler half of the project. It does NOT need Windows: the Pawn
# compiler runs anywhere, so you can build modules on Linux, macOS, WSL, or in
# CI, then copy the .amx files to a Windows box that has PawnIO installed.
#
# It finds a compiler in this order:
#   1. `pawncc` already on your PATH
#   2. a previously downloaded copy under .tools/
#   3. otherwise it downloads the exact pawncc used by the official modules
#      (CompuPhase Pawn 4.1.7152, packaged as an RPM) and extracts just the
#      binary — no system install required.
#
# Usage:  ./scripts/build.sh [module ...]     (default: all modules)
#
# SPDX-License-Identifier: 0BSD
set -euo pipefail

# --- locations ------------------------------------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES_DIR="$ROOT/modules"
INCLUDE_DIR="$MODULES_DIR/include"
OUT_DIR="$ROOT/build"
TOOLS_DIR="$ROOT/.tools"

# Pinned compiler: the same build the official PawnIO.Modules CI uses.
PAWNCC_VERSION="4.1.7152"
PAWNCC_RPM_URL="https://raw.githubusercontent.com/namazso/PawnIO.Modules/master/_pawn/pawn-${PAWNCC_VERSION}-1.el9.x86_64.rpm"

# The exact flags the official modules are built with:
#   -C64  64-bit cells        -;+  require semicolons
#   -(+   require parentheses  -p   block the default prefix include
PAWNCC_FLAGS=(-C64 "-;+" "-(+" -p)

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# --- find or fetch pawncc -------------------------------------------------
find_pawncc() {
    if command -v pawncc >/dev/null 2>&1; then
        echo "pawncc"; return
    fi
    local cached="$TOOLS_DIR/pawn/usr/bin/pawncc"
    if [[ -x "$cached" ]]; then
        echo "$cached"; return
    fi
    fetch_pawncc >&2
    echo "$cached"
}

fetch_pawncc() {
    log "Downloading pawncc $PAWNCC_VERSION ..."
    mkdir -p "$TOOLS_DIR"
    local rpm="$TOOLS_DIR/pawncc.rpm"
    curl -fsSL -o "$rpm" "$PAWNCC_RPM_URL" || die "failed to download pawncc rpm"

    local dest="$TOOLS_DIR/pawn"
    rm -rf "$dest"; mkdir -p "$dest"
    log "Extracting compiler (no system install) ..."
    if command -v rpm2cpio >/dev/null 2>&1 && command -v cpio >/dev/null 2>&1; then
        ( cd "$dest" && rpm2cpio "$rpm" | cpio -idm --quiet )
    elif command -v bsdtar >/dev/null 2>&1; then
        bsdtar -C "$dest" -xf "$rpm"
    elif command -v 7z >/dev/null 2>&1; then
        7z x -so "$rpm" | ( cd "$dest" && cpio -idm --quiet ) 2>/dev/null \
            || die "extraction failed; install 'rpm2cpio' + 'cpio' or 'libarchive-tools'"
    else
        die "no RPM extractor found. Install one of:
    Debian/Ubuntu:  sudo apt-get install -y rpm2cpio cpio   (or libarchive-tools for bsdtar)
    Fedora/RHEL:    already have rpm2cpio
    macOS:          brew install rpm2cpio cpio               (or libarchive)"
    fi
    [[ -x "$dest/usr/bin/pawncc" ]] || die "pawncc not found after extraction"
    log "Compiler ready: $dest/usr/bin/pawncc"
}

# --- build ----------------------------------------------------------------
main() {
    [[ -d "$INCLUDE_DIR" ]] || die "missing $INCLUDE_DIR (the PawnIO headers)"
    local pawncc; pawncc="$(find_pawncc)"
    log "Using compiler: $pawncc"
    "$pawncc" 2>&1 | head -1 || true

    mkdir -p "$OUT_DIR"

    # Which modules to build?
    local sources=()
    if (( $# > 0 )); then
        for m in "$@"; do sources+=("$MODULES_DIR/${m%.p}.p"); done
    else
        for f in "$MODULES_DIR"/*.p; do sources+=("$f"); done
    fi

    local failed=0 built=0
    for src in "${sources[@]}"; do
        [[ -f "$src" ]] || { warn "no such module: $src"; failed=1; continue; }
        local name; name="$(basename "$src" .p)"
        printf '  compiling %-12s ' "$name"
        if "$pawncc" "$src" "-i$INCLUDE_DIR" "${PAWNCC_FLAGS[@]}" \
                -o"$OUT_DIR/$name.amx" >"$OUT_DIR/$name.log" 2>&1; then
            printf '\033[1;32mok\033[0m  (%s bytes)\n' "$(wc -c <"$OUT_DIR/$name.amx")"
            built=$((built + 1))
        else
            printf '\033[1;31mFAILED\033[0m\n'
            sed 's/^/      /' "$OUT_DIR/$name.log"
            failed=1
        fi
    done

    echo
    log "Built $built module(s) into $OUT_DIR"
    (( failed == 0 )) || die "one or more modules failed to compile"
    cat <<EOF

Next steps:
  * These are RAW, UNSIGNED .amx files. They load only on the PawnIO
    'unrestricted' edition (test signing required). See docs/05-signing-and-editions.md
  * To use them:  pawnlab run build/<name>.amx <function> <outCount> [args...]
EOF
}

main "$@"
