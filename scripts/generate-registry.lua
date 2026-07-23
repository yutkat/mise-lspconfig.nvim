-- Regenerate lua/mise-lspconfig/registry.lua. Run from the repository root:
--   nvim -l scripts/generate-registry.lua <mason-registry.json> [mise-registry-dump] [nvim-lspconfig-lsp-dir]
-- When the dump is omitted, `mise registry` is invoked directly. When the
-- nvim-lspconfig lsp/ directory is given, servers missing from mason-registry
-- are added as bin-only entries.
vim.opt.rtp:prepend(".")
local generator = require("mise-lspconfig.generator")

local function read(path)
	local f = assert(io.open(path, "r"), "cannot open " .. path)
	local content = f:read("*a")
	f:close()
	return content
end

local mason_json =
	assert(_G.arg[1], "usage: nvim -l scripts/generate-registry.lua <registry.json> [mise-registry-dump] [lsp-dir]")
local mason_packages = vim.json.decode(read(mason_json))

local mise_text
if _G.arg[2] and _G.arg[2] ~= "" then
	mise_text = read(_G.arg[2])
else
	mise_text = vim.fn.system({ "mise", "registry" })
	assert(vim.v.shell_error == 0, "`mise registry` failed")
end

local registry = generator.build(mason_packages, mise_text)

local lsp_dir = _G.arg[3]
if lsp_dir then
	local defs = {}
	for _, file in ipairs(vim.fn.glob(lsp_dir .. "/*.lua", false, true)) do
		local ok, cfg = pcall(dofile, file)
		local cmd = ok and type(cfg) == "table" and cfg.cmd
		if type(cmd) == "table" and type(cmd[1]) == "string" then
			defs[vim.fn.fnamemodify(file, ":t:r")] = cmd[1]
		end
	end
	registry = generator.augment(registry, defs)
end

local out = assert(io.open("lua/mise-lspconfig/registry.lua", "w"))
out:write(generator.serialize(registry))
out:close()
print(string.format("wrote %d servers to lua/mise-lspconfig/registry.lua", vim.tbl_count(registry)))
