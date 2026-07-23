# mise-lspconfig.nvim

Automatically `vim.lsp.enable()` language servers installed with
[mise](https://mise.jdx.dev/) — a [mason-lspconfig.nvim](https://github.com/mason-org/mason-lspconfig.nvim)
alternative for people who manage their tools with mise instead of Mason.

Manage server binaries declaratively in your mise config (shared with your
shell and CI, with per-project version pinning); this plugin detects which
known servers are on `$PATH` and enables them. It ships a registry mapping
lspconfig server names to binaries and mise install specs, generated weekly
from [mason-registry](https://github.com/mason-org/mason-registry) and
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) data
(currently ~380 servers).

There is intentionally no `:Install` command: installation belongs in your
mise configuration files, not in editor state.

## Requirements

- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) (or your own
  `lsp/*.lua` server definitions on the runtimepath)
- [mise](https://mise.jdx.dev/) — strictly speaking optional: any server
  binary on `$PATH` is detected, wherever it came from

## Installation

### lazy.nvim

```lua
{
 "yutkat/mise-lspconfig.nvim",
 event = "VimEnter",
 dependencies = { "neovim/nvim-lspconfig" },
 opts = {},
}
```

## Usage

1. Install servers with mise, e.g. in `~/.config/mise/conf.d/neovim.toml`:

   ```toml
   [tools]
   lua-language-server = "latest"
   "npm:pyright" = "latest"
   "npm:vscode-langservers-extracted" = "latest"
   ```

2. Start Neovim. Every known server whose binary is on `$PATH` is enabled.

To find the mise install spec for an lspconfig server name:

```lua
:lua =require("mise-lspconfig").tool("gopls")  -- "go:golang.org/x/tools/gopls"
```

Run `:checkhealth mise-lspconfig` to see what was detected.

## Configuration

Defaults shown:

```lua
require("mise-lspconfig").setup({
 -- Call vim.lsp.enable() for every known server found on $PATH.
 auto_enable = true,
 -- Server names to never enable, e.g. { "copilot", "denols" } to avoid
 -- conflicts with copilot.lua or ts_ls.
 exclude = {},
 -- Add servers missing from the generated registry, or replace entries:
 -- overrides = { nixd = { bin = { "nixd" } } }
 overrides = {},
})
```

Server settings are configured through the standard Neovim mechanism,
independently of this plugin:

```lua
vim.lsp.config("lua_ls", { settings = { Lua = { hint = { enable = true } } } })
```

## Registry

`lua/mise-lspconfig/registry.lua` maps lspconfig server names to binary names
and mise tool specs. It is generated from mason-registry package metadata
(npm/PyPI/crates.io/Go/gem sources map to the corresponding mise backends;
GitHub-released servers map to curated mise shortnames when available, ubi
otherwise) and refreshed weekly by CI.

Servers that nvim-lspconfig defines but mason-registry does not cover (nixd,
ccls, ...) are included as bin-only entries: they are auto-enabled when their
binary is on `$PATH` (installed via Nix, your system package manager, ...)
but have no mise install spec. Servers whose `cmd` is a generic interpreter
(`node`, `python3`, ...) are excluded to avoid false positives; add them via
`overrides` if you use them.

Regenerate manually with:

```sh
gh release download --repo mason-org/mason-registry --pattern registry.json.zip --output /tmp/registry.json.zip
unzip -o /tmp/registry.json.zip -d /tmp
git clone --depth=1 https://github.com/neovim/nvim-lspconfig /tmp/nvim-lspconfig
nvim -l scripts/generate-registry.lua /tmp/registry.json "" /tmp/nvim-lspconfig/lsp
```
