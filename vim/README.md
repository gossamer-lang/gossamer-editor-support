# gossamer.vim

Vim filetype detection, syntax highlighting, and basic indent/format
settings for `.gos` files.

## Install (vim-plug)

```vim
Plug 'gossamer-lang/gossamer-editor-support', { 'rtp': 'vim' }
```

## Install (manual)

Copy `ftdetect/`, `ftplugin/`, `indent/`, and `syntax/` into your
`~/.vim/` (vim) or `~/.config/nvim/` (neovim, classic syntax route)
directory.

For neovim with treesitter, prefer the `../neovim/` setup instead.
