#!/usr/bin/env bash
# Install Gossamer support for Helix:
#   - merges the [[language]] / [[grammar]] / [language-server.gossamer-lsp]
#     entries into ~/.config/helix/languages.toml (the grammar source is
#     rewritten to the local tree-sitter-gossamer/ directory so nothing
#     is fetched from GitHub)
#   - copies tree-sitter highlight queries into the runtime
#   - builds the grammar via `hx --grammar build`
#
# Re-runnable: any previously installed gossamer block is removed and
# replaced with the current version, so updates always overwrite.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_TOML="$ROOT/helix/languages.toml"
GRAMMAR_DIR="$ROOT/tree-sitter-gossamer"
QUERIES_SRC="$GRAMMAR_DIR/queries"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/helix"
TARGET_TOML="$CONFIG_DIR/languages.toml"
QUERIES_DST="$CONFIG_DIR/runtime/queries/gossamer"

BEGIN_MARKER="# --- BEGIN gossamer (gossamer-editor-support) ---"
END_MARKER="# --- END gossamer (gossamer-editor-support) ---"
LEGACY_MARKER="# --- gossamer (added by gossamer-editor-support) ---"

mkdir -p "$CONFIG_DIR"
rm -rf "$QUERIES_DST"
mkdir -p "$QUERIES_DST"

if [ ! -f "$GRAMMAR_DIR/src/parser.c" ]; then
    if ! command -v tree-sitter >/dev/null 2>&1; then
        echo "tree-sitter CLI not found and $GRAMMAR_DIR/src/parser.c is missing." >&2
        echo "install it with 'npm install -g tree-sitter-cli' (or 'cargo install tree-sitter-cli') and re-run." >&2
        exit 1
    fi
    (cd "$GRAMMAR_DIR" && tree-sitter generate)
    echo "generated $GRAMMAR_DIR/src/parser.c"
fi

if [ -f "$TARGET_TOML" ]; then
    # Strip current marker block (BEGIN..END inclusive).
    if grep -qF "$BEGIN_MARKER" "$TARGET_TOML"; then
        awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" '
            $0 == b { skip = 1; next }
            skip && $0 == e { skip = 0; next }
            !skip { print }
        ' "$TARGET_TOML" > "$TARGET_TOML.tmp"
        mv "$TARGET_TOML.tmp" "$TARGET_TOML"
        echo "removed previous gossamer block from $TARGET_TOML"
    fi
    # Strip legacy block (no end marker; the old script appended at EOF).
    if grep -qF "$LEGACY_MARKER" "$TARGET_TOML"; then
        awk -v m="$LEGACY_MARKER" '
            $0 == m { skip = 1; next }
            !skip { print }
        ' "$TARGET_TOML" > "$TARGET_TOML.tmp"
        mv "$TARGET_TOML.tmp" "$TARGET_TOML"
        echo "removed legacy gossamer block from $TARGET_TOML"
    fi
fi

{
    # One blank line separates the block from existing content; a re-run
    # finds that line already in place.
    if [ -s "$TARGET_TOML" ] && [ -n "$(tail -n 1 "$TARGET_TOML")" ]; then
        echo ""
    fi
    echo "$BEGIN_MARKER"
    sed "s|^source = { git = .*\$|source = { path = \"$GRAMMAR_DIR\" }|" "$SRC_TOML"
    echo "$END_MARKER"
} >> "$TARGET_TOML"
echo "wrote gossamer block to $TARGET_TOML"
echo "  grammar source: $GRAMMAR_DIR"

cp "$QUERIES_SRC"/*.scm "$QUERIES_DST/"
echo "copied highlight queries to $QUERIES_DST"

GRAMMAR_OUT="$CONFIG_DIR/runtime/grammars/gossamer.so"

if command -v hx >/dev/null 2>&1; then
    # `hx --grammar build` compiles every grammar in languages.toml; unrelated
    # grammars failing in the user's environment must not abort our install.
    hx --grammar build || echo "  (one or more unrelated grammars failed to build; continuing)"
    if [ ! -f "$GRAMMAR_OUT" ]; then
        echo "gossamer grammar did not build: $GRAMMAR_OUT not found" >&2
        exit 1
    fi
    echo "gossamer grammar built: $GRAMMAR_OUT"
else
    echo "hx not found on PATH; run 'hx --grammar build' manually"
fi

cat <<EOF

done. open a .gos file in helix to confirm.

LSP: helix will launch \`gos lsp\` for .gos buffers when the \`gos\`
CLI is on PATH. If it is missing the LSP client fails to start and
tree-sitter highlighting still works.
EOF
