# gossamer-mode.el

Emacs major mode for Gossamer. Font-lock keywords, comments, basic
indentation, and an eglot LSP client (built into Emacs 29+) that
launches `gos lsp`.

## LSP

`gossamer-mode` registers itself with eglot. Run `M-x eglot` in a
`.gos` buffer to start the language server. If `gos` is not on
`PATH`, eglot reports a startup failure and the mode still works for
editing and highlighting. Override the command with
`M-x customize-variable RET gossamer-lsp-server-command`.

## Install (manual)

```elisp
(add-to-list 'load-path "/path/to/gossamer-editor-support/emacs")
(require 'gossamer-mode)
```

## Install (use-package + straight.el)

```elisp
(use-package gossamer-mode
  :straight (:host github
             :repo "gossamer-lang/gossamer-editor-support"
             :files ("emacs/gossamer-mode.el"))
  :mode "\\.gos\\'")
```

`.gos` files autoload into `gossamer-mode`.
