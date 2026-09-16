# Gossamer for Helix

Helix uses tree-sitter natively. Add the language and grammar entries
from `languages.toml` here into your `~/.config/helix/languages.toml`,
then:

```bash
hx --grammar fetch
hx --grammar build
```

Copy the highlight queries from the grammar Helix just fetched, so the
queries and the grammar come from the same commit:

```bash
mkdir -p ~/.config/helix/runtime/queries/gossamer
cp ~/.config/helix/runtime/grammars/sources/gossamer/tree-sitter-gossamer/queries/*.scm \
   ~/.config/helix/runtime/queries/gossamer/
```

Open a `.gos` file to confirm.

## Updating

The `rev` in `languages.toml` is a commit hash, not a branch: Helix
fetches a revision once and does not advance a branch name on later
fetches. To pick up a newer grammar, copy the new `rev` into your
`languages.toml`, then re-run `hx --grammar fetch`, `hx --grammar build`,
and the query copy above. A query file from a different commit than the
grammar can name nodes the grammar does not have, and Helix then drops
highlighting for the whole file.

`../scripts/install-helix.sh` builds from this checkout instead, and
re-running it after a `git pull` updates the grammar and the queries
together.

## LSP

The `[language-server.gossamer-lsp]` block in `languages.toml` wires
Helix to launch `gos lsp` for `.gos` buffers. If `gos` is not on
`PATH`, Helix skips the LSP client and tree-sitter highlighting still
works.
