#!/usr/bin/env bash
# Install the Gossamer VSCode extension (development install via symlink).
# Installs node_modules so the LSP client can launch `gos lsp` for .gos
# buffers. Re-runnable: any prior install is removed first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/../vscode" && pwd)"

case "$(uname -s)" in
    Darwin|Linux) EXT_DIR="$HOME/.vscode/extensions" ;;
    MINGW*|MSYS*|CYGWIN*) EXT_DIR="$APPDATA/Code/User/extensions" ;;
    *) echo "unsupported platform: $(uname -s)" >&2; exit 1 ;;
esac

VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SRC_DIR/package.json" | head -1)"
TARGET="$EXT_DIR/gossamer-lang.gossamer-$VERSION"

mkdir -p "$EXT_DIR"

if [ -L "$TARGET" ] || [ -e "$TARGET" ]; then
    rm -rf "$TARGET"
fi

if [ ! -d "$SRC_DIR/node_modules/vscode-languageclient" ]; then
    if command -v npm >/dev/null 2>&1; then
        (cd "$SRC_DIR" && npm install --omit=dev --no-audit --no-fund --silent) \
            && echo "installed vscode-languageclient in $SRC_DIR/node_modules" \
            || echo "warning: npm install failed; LSP client will be inactive (syntax-only)"
    else
        echo "warning: npm not found; LSP client will be inactive."
        echo "         install Node.js and run 'npm install --omit=dev' in $SRC_DIR"
        echo "         to enable the language server, then reload VSCode."
    fi
fi

ln -s "$SRC_DIR" "$TARGET"

echo "installed: $TARGET -> $SRC_DIR"
echo "reload VSCode (Cmd/Ctrl+Shift+P -> 'Developer: Reload Window') and open a .gos file."
echo
echo "LSP: the client launches 'gos lsp'. Override with the"
echo "     'gossamer.lsp.command' / 'gossamer.lsp.args' settings."
