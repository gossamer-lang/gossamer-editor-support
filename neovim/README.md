# gossamer.nvim

Neovim integration for Gossamer using `nvim-treesitter`. Falls back to
the classic vim syntax in `../vim/` if you don't run treesitter.

## Install with `nvim-treesitter`

Add the parser via the configured parser table. Example with
`lazy.nvim`:

```lua
{
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
    parser_config.gossamer = {
      install_info = {
        url = "https://github.com/gossamer-lang/gossamer-editor-support",
        location = "tree-sitter-gossamer",
        files = { "src/parser.c", "src/scanner.c" },
        branch = "main",
      },
      filetype = "gossamer",
    }

    vim.filetype.add({ extension = { gos = "gossamer" } })

    require("nvim-treesitter.configs").setup({
      ensure_installed = { "gossamer" },
      highlight = { enable = true },
    })
  end,
}
```

After loading, run `:TSInstall gossamer`.

The query files in `../tree-sitter-gossamer/queries/` are picked up
automatically.

## Install via Mason / lazy without nvim-treesitter

If you only want syntax highlighting (no treesitter), the vim files
in `../vim/` work in neovim too. Drop them under `~/.config/nvim/` or
add the repo as a runtimepath via your plugin manager pointing to
`vim`.

## LSP

`lsp/gossamer.lua` is a Neovim 0.11+ native LSP client config that
launches `gos lsp` for `.gos` buffers. The install script copies it
to `~/.config/nvim/lsp/gossamer.lua`. Activate from your `init.lua`:

```lua
vim.lsp.enable("gossamer")
```

If `gos` is not on `PATH`, the client fails to start and tree-sitter
highlighting still works.
