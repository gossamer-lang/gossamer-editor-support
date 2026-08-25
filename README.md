# gossamer-editor-support

Editor integrations for the [Gossamer programming language](https://github.com/gossamer-lang/gossamer):
syntax highlighting, file detection, comments, brackets, and (where the
editor supports it) tree-sitter queries.

(Support is built in for [Lite Anvil](https://github.com/danpozmanter/lite-anvil/)).
## Editors

| Editor                     | Path                       | Mechanism             |
|----------------------------|----------------------------|-----------------------|
| **Visual Studio Code**     | `vscode/`                  | TextMate grammar      |
| **Tree-sitter (library)**  | `tree-sitter-gossamer/`    | tree-sitter grammar   |
| **Vim**                    | `vim/`                     | Vim syntax + ftplugin |
| **Neovim**                 | `neovim/`                  | tree-sitter wrapper   |
| **Helix**                  | `helix/`                   | tree-sitter + config  |
| **Emacs**                  | `emacs/`                   | `gossamer-mode.el`    |
| **Sublime Text**           | `sublime/`                 | `.sublime-syntax`     |
| **Zed**                    | `zed/`                     | extension + grammar   |

All integrations track the Gossamer 0.55.6 surface and cover at
minimum:

- `.gos` file detection
- Comments (`//` and nesting `/* ... */`)
- Keywords, including `comptime`, goroutine controls, and the
  contextual `arena { }` and `cohort { }` blocks
- Primitive types and common stdlib types
- Numeric literals (decimal, hex, binary, octal) with type suffixes
- String, byte-string, raw-string, raw-byte-string, char, and byte
  literals, and the triple-quoted `""" ... """` form
- The forward-pipe operator `|>`
- Labels, open ranges, range patterns, and slice patterns
- Collection literals: `#[..]` (Vec), `#{..}` (Set), `{k: v}` (Map),
  and `[..]` (fixed array)
- Braced named-struct literals with keyed and `..base` fields
- Attributes (`#[...]`, `#![...]`)
- Function-call detection (identifier-before-paren)
- Newline-separated delimited lists, which Gossamer accepts wherever a
  comma would go

LSP wiring is configured for VSCode, Helix, Neovim, Zed, Emacs, and
Sublime Text. Each client launches `gos lsp` (the LSP subcommand of
the Gossamer CLI). If `gos` is not on `PATH` the LSP client fails to
start and syntax highlighting still works. Vim has no first-party
LSP, use a plugin (`yegappan/lsp`, ALE, coc.nvim) and point it at
`gos lsp`.

## Install

Per-editor install scripts live in `scripts/`:

```bash
./scripts/install-vscode.sh
./scripts/install-zed.sh
./scripts/install-helix.sh
./scripts/install-vim.sh
./scripts/install-neovim.sh
./scripts/install-sublime.sh
```

Each script overwrites any prior install, so re-running picks up
upstream changes (syntax, LSP wiring, queries). See the per-editor
`README.md` files for manual installation steps and the underlying
mechanism.

## Contributing

The grammar of record for highlighting is the lite-anvil reference
syntax, mirrored as the `tree-sitter-gossamer/` grammar. When adding
tokens, update both:

1. `tree-sitter-gossamer/grammar.js` (and re-run `tree-sitter generate`)
2. `tree-sitter-gossamer/queries/highlights.scm`

then propagate equivalent additions to the per-editor configs that do
not consume tree-sitter (VSCode TextMate grammar, Vim syntax, Emacs
font-lock, Sublime syntax).

## License

Same as upstream Gossamer (Apache-2.0). See `LICENSE`.
