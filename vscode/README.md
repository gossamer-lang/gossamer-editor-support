# gossamer-vscode

VSCode language support for [Gossamer](https://github.com/gossamer-lang/gossamer):
syntax highlighting, comment toggling, bracket matching, indentation.

## Install (development)

From this directory:

```bash
# Package as a .vsix
npm install -g @vscode/vsce
vsce package

# Then install the produced .vsix
code --install-extension gossamer-0.2.0.vsix
```

Or symlink the directory into your extensions folder for live editing:

```bash
ln -s "$PWD" ~/.vscode/extensions/gossamer-lang.gossamer-0.2.0
```

Open any `.gos` file to confirm highlighting.

## What it covers

- File extension: `.gos`
- Line and block comments
- Keywords, primitive types, common stdlib types, literals (`true`, `false`,
  `None`, `Some`, `Ok`, `Err`)
- Numeric literals (decimal, hex, binary, octal) with optional type suffix
- String and byte-string literals, raw strings, char literals, and the
  triple-quoted `""" ... """` form
- Collection literals: `#[..]` (Vec), `#{..}` (Set), `{k: v}` (Map)
- The forward-pipe operator `|>`
- Attributes (`#[...]`, `#![...]`), which are distinguished from a
  `#[..]` Vec literal by sitting at the start of a line
- Function-call detection (identifier-before-paren)

## LSP

The extension launches `gos lsp` for `.gos` buffers via
`vscode-languageclient`. Override the binary or arguments with:

```jsonc
// .vscode/settings.json or user settings
{
  "gossamer.lsp.command": "gos",
  "gossamer.lsp.args": ["lsp"]
}
```

If `gos` is not on `PATH`, the LSP client fails to start and the
TextMate grammar still provides highlighting.

The install script runs `npm install --omit=dev` for you. For manual
installs, run that yourself in this directory so
`vscode-languageclient` is on disk.
