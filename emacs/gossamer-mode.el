;;; gossamer-mode.el --- Major mode for the Gossamer language -*- lexical-binding: t; -*-

;; Author: Gossamer contributors
;; Version: 0.2.0
;; Keywords: languages
;; URL: https://github.com/gossamer-lang/gossamer-site

;;; Commentary:

;; A simple major mode for editing Gossamer source files. Provides
;; syntax highlighting, comment handling, basic indentation, and an
;; eglot LSP client registration (Emacs 29+ ships eglot built-in).
;; The LSP client invokes `gos lsp` (the `lsp` subcommand of the
;; Gossamer CLI). If `gos` is not on PATH eglot reports a startup
;; failure but the mode still works for editing and highlighting.

;;; Code:

(defvar gossamer-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?_ "w" table)
    (modify-syntax-entry ?/ ". 124b" table)
    ;; The `n` flag: Gossamer block comments nest.
    (modify-syntax-entry ?* ". 23n" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\\ "\\" table)
    table)
  "Syntax table for `gossamer-mode'.")

(defconst gossamer-keywords
  '("as" "async" "await" "comptime" "const" "crate" "dyn" "enum" "extern" "fn"
    "impl" "let" "mod" "mut" "package" "pub" "self" "Self" "static"
    "struct" "super" "trait" "type" "unsafe" "use" "where" "yield"))

(defconst gossamer-control
  '("if" "else" "match" "loop" "while" "for" "in" "break" "continue"
    "return" "yield" "defer" "select" "go"))

(defconst gossamer-types
  '("bool" "char" "str"
    "i8" "i16" "i32" "i64" "i128" "isize"
    "u8" "u16" "u32" "u64" "u128" "usize"
    "f32" "f64"
    "Arc" "Array" "BTreeMap" "BTreeSet" "Box" "Fn" "FnMut" "FnOnce"
    "HashMap" "HashSet" "JoinHandle" "Mutex" "Option" "Rc" "Receiver"
    "Result" "RwLock" "Sender" "String" "Vec" "Weak"))

(defconst gossamer-constants
  '("true" "false" "None" "Some" "Ok" "Err"))

(defconst gossamer-font-lock-keywords
  `(;; `arena` is contextual: a keyword only when it opens a block.
    ("\\_<\\(arena\\)\\_>\\s-*{" 1 font-lock-keyword-face)
    (,(regexp-opt gossamer-keywords 'symbols) . font-lock-keyword-face)
    (,(regexp-opt gossamer-control 'symbols) . font-lock-keyword-face)
    (,(regexp-opt gossamer-types 'symbols) . font-lock-type-face)
    (,(regexp-opt gossamer-constants 'symbols) . font-lock-constant-face)
    ("\\<\\(0x[0-9a-fA-F_]+\\|0b[01_]+\\|0o[0-7_]+\\|[0-9][0-9_]*\\(?:\\.[0-9_]+\\)?\\(?:[eE][+-]?[0-9_]+\\)?\\)\\(?:[iuf]\\(?:8\\|16\\|32\\|64\\|128\\|size\\)\\)?\\>"
     . font-lock-constant-face)
    ("|>" . font-lock-builtin-face)
    ("\\<fn\\s-+\\([a-zA-Z_][a-zA-Z0-9_]*\\)" 1 font-lock-function-name-face)
    ("\\<\\([a-zA-Z_][a-zA-Z0-9_]*\\)\\s-*(" 1 font-lock-function-name-face)
    ("\\<\\([A-Z][a-zA-Z0-9_]*\\)\\>" 1 font-lock-type-face)
    ("^\\s-*#!?\\[[^]]*\\]" . font-lock-preprocessor-face)
    ("#" . font-lock-builtin-face)
    ("\\<[a-zA-Z_][a-zA-Z0-9_]*!" . font-lock-preprocessor-face)))

(defcustom gossamer-indent-offset 4
  "Indentation offset for `gossamer-mode'."
  :type 'integer
  :group 'gossamer)

(defun gossamer-indent-line ()
  "Indent current line as Gossamer code."
  (interactive)
  (let ((indent
         (save-excursion
           (beginning-of-line)
           (cond
            ((bobp) 0)
            ((looking-at "[ \t]*[})\\]]")
             (save-excursion
               (forward-line -1)
               (beginning-of-line)
               (skip-chars-forward " \t")
               (max 0 (- (current-column) gossamer-indent-offset))))
            (t
             (save-excursion
               (forward-line -1)
               (beginning-of-line)
               (skip-chars-forward " \t")
               (let ((prev (current-column))
                     (line (buffer-substring-no-properties
                            (line-beginning-position)
                            (line-end-position))))
                 (if (string-match-p "[{(\\[]\\s-*$" line)
                     (+ prev gossamer-indent-offset)
                   prev))))))))
    (if (<= (current-column) (current-indentation))
        (indent-line-to indent)
      (save-excursion (indent-line-to indent)))))

;;;###autoload
(define-derived-mode gossamer-mode prog-mode "Gossamer"
  "Major mode for editing Gossamer source files."
  :syntax-table gossamer-mode-syntax-table
  (setq-local font-lock-defaults '(gossamer-font-lock-keywords))
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "//+\\s-*")
  (setq-local indent-line-function #'gossamer-indent-line)
  (setq-local tab-width gossamer-indent-offset)
  (setq-local indent-tabs-mode nil))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.gos\\'" . gossamer-mode))

(defcustom gossamer-lsp-server-command '("gos" "lsp")
  "Command and arguments used by eglot to launch the Gossamer LSP server."
  :type '(repeat string)
  :group 'gossamer)

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `(gossamer-mode . ,gossamer-lsp-server-command)))

(provide 'gossamer-mode)
;;; gossamer-mode.el ends here
