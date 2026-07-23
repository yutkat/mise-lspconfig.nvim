local M = {}

M.options = {
	-- Call vim.lsp.enable() for every known server found on $PATH during setup().
	auto_enable = true,
	-- lspconfig server names to never enable (e.g. { "copilot", "denols" }).
	exclude = {},
	-- Add servers missing from the generated registry or replace their entries:
	-- overrides = { nixd = { bin = { "nixd" } } }
	overrides = {},
}

local function has_bin(entry)
	for _, bin in ipairs(entry.bin or {}) do
		if vim.fn.executable(bin) == 1 then
			return true
		end
	end
	return false
end

---Generated registry merged with user overrides.
---@return table<string, { tool: string?, bin: string[] }>
function M.registry()
	local base = require("mise-lspconfig.registry")
	if next(M.options.overrides) == nil then
		return base
	end
	return vim.tbl_deep_extend("force", vim.deepcopy(base), M.options.overrides)
end

---Known servers whose binary is on $PATH, minus excludes, sorted.
---@return string[]
function M.available()
	local names = {}
	for name, entry in pairs(M.registry()) do
		if not vim.tbl_contains(M.options.exclude, name) and has_bin(entry) then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

---mise tool spec for a server, e.g. M.tool("pyright") -> "npm:pyright".
---Install with `mise use <spec>` in the mise config of your choice.
---@param name string lspconfig server name
---@return string?
function M.tool(name)
	local entry = M.registry()[name]
	return entry and entry.tool or nil
end

---Enable every available server. Returns the enabled names.
---@return string[]
function M.enable()
	local names = M.available()
	if #names > 0 then
		vim.lsp.enable(names)
	end
	return names
end

---@param opts table?
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
	if M.options.auto_enable then
		M.enable()
	end
end

return M
