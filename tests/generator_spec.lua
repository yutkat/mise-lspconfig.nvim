local generator = require("mise-lspconfig.generator")

local function eq(expected, actual, msg)
	assert(
		vim.deep_equal(expected, actual),
		(msg or "not equal") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual)
	)
end

-- parse_purl
eq({ "npm", "pyright" }, { generator.parse_purl("pkg:npm/pyright@1.1.0") })
eq({ "npm", "@angular/language-server" }, { generator.parse_purl("pkg:npm/%40angular/language-server@22.0.7") })
eq({ "golang", "golang.org/x/tools/gopls" }, { generator.parse_purl("pkg:golang/golang.org/x/tools/gopls@v0.16.2") })
eq({ "github", "LuaLS/lua-language-server" }, { generator.parse_purl("pkg:github/LuaLS/lua-language-server@3.9.0") })
eq({ "npm", "foo" }, { generator.parse_purl("pkg:npm/foo@1.0.0?os=linux") }, "strips purl qualifiers")
eq({}, { generator.parse_purl("not-a-purl") })

-- parse_mise_registry: backend spec (lowercased) -> shortname
local idx = generator.parse_mise_registry(table.concat({
	"prettier                      npm:prettier",
	"stylua                        aqua:JohnnyMorganz/StyLua asdf:jc00ke/asdf-stylua cargo:stylua",
}, "\n"))
eq("prettier", idx["npm:prettier"])
eq("stylua", idx["aqua:johnnymorganz/stylua"], "index keys are lowercased")
eq("stylua", idx["cargo:stylua"])

local function pkg(overrides)
	return vim.tbl_deep_extend("force", {
		name = "pyright",
		source = { id = "pkg:npm/pyright@1.1.0" },
		bin = { ["pyright-langserver"] = "npm:pyright-langserver" },
		neovim = { lspconfig = "pyright" },
	}, overrides or {})
end

-- convert: backend mapping per source type
local function tool_of(p, index)
	local _, entry = generator.convert(p, index or {})
	return entry and entry.tool
end
eq("npm:pyright", tool_of(pkg()))
eq("pipx:ruff", tool_of(pkg({ source = { id = "pkg:pypi/ruff@0.6.0" } })))
eq("cargo:selene", tool_of(pkg({ source = { id = "pkg:cargo/selene@0.29.0" } })))
eq("go:golang.org/x/tools/gopls", tool_of(pkg({ source = { id = "pkg:golang/golang.org/x/tools/gopls@v1" } })))
eq("gem:solargraph", tool_of(pkg({ source = { id = "pkg:gem/solargraph@0.50.0" } })))

-- convert: unsupported source types are skipped
eq(nil, tool_of(pkg({ source = { id = "pkg:opam/ocaml-lsp-server@1.0.0" } })))
eq(nil, tool_of(pkg({ source = { id = "pkg:nuget/csharp-ls@1.0.0" } })))

-- convert: github prefers mise shortnames (case-insensitively), falls back to ubi
-- only when the release provides prebuilt assets
local gh = pkg({ source = { id = "pkg:github/johnnymorganz/stylua@2.0.0" } })
eq("stylua", tool_of(gh, { ["aqua:johnnymorganz/stylua"] = "stylua" }))
gh = pkg({ source = { id = "pkg:github/ewhauser/shuck@0.0.45", asset = { { target = "linux_x64" } } } })
eq("ubi:ewhauser/shuck", tool_of(gh))
gh = pkg({ source = { id = "pkg:github/example/build-only@1.0.0", build = { run = "make" } } })
eq(nil, tool_of(gh), "github source without assets is skipped")

-- convert: non-github backends are promoted to shortnames too
eq("prettier", tool_of(pkg({ source = { id = "pkg:npm/prettier@3.0.0" } }), { ["npm:prettier"] = "prettier" }))

-- convert: packages without lspconfig name or bin are skipped
eq(nil, (generator.convert(pkg({ neovim = vim.NIL }), {})))
local no_lsp = pkg()
no_lsp.neovim = nil
eq(nil, (generator.convert(no_lsp, {})))
local no_bin = pkg()
no_bin.bin = nil
eq(nil, (generator.convert(no_bin, {})))

-- convert: returns sorted bin names
local sorted_pkg = pkg()
sorted_pkg.bin = { b = "x", a = "y" }
local _, entry = generator.convert(sorted_pkg, {})
eq({ "a", "b" }, assert(entry).bin)

-- build: first package wins on duplicate lspconfig names
local built = generator.build({
	pkg(),
	pkg({ name = "pyright-fork", source = { id = "pkg:npm/pyright-fork@1.0.0" } }),
}, "")
eq({ pyright = { tool = "npm:pyright", bin = { "pyright-langserver" } } }, built)

-- serialize: stable output, loadable as Lua, round-trips
local registry = {
	zeta = { tool = "npm:zeta", bin = { "zeta" } },
	alpha = { tool = "ubi:a/b", bin = { "a", "b" } },
}
local src = generator.serialize(registry)
assert(src:find("alpha") < src:find("zeta"), "keys are sorted")
eq(registry, assert(load(src))())
eq(src, generator.serialize(registry), "serialization is deterministic")

-- augment: adds lspconfig-only servers as bin-only entries
local base = { pyright = { tool = "npm:pyright", bin = { "pyright-langserver" } } }
local augmented = generator.augment(vim.deepcopy(base), {
	pyright = "pyright-langserver", -- already known: mason entry wins
	nixd = "nixd", -- new: added without a tool spec
	esbonio = "python3", -- interpreter cmd: skipped (would false-positive)
	turtle_ls = "node",
})
eq({
	pyright = { tool = "npm:pyright", bin = { "pyright-langserver" } },
	nixd = { bin = { "nixd" } },
}, augmented)

-- serialize: entries without a tool spec stay loadable and stable
local src2 = generator.serialize({ nixd = { bin = { "nixd" } } })
eq({ nixd = { bin = { "nixd" } } }, assert(load(src2))())
