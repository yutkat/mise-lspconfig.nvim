local M = {}

function M.check()
	local health = vim.health
	local m = require("mise-lspconfig")

	health.start("mise-lspconfig")
	if vim.fn.executable("mise") == 1 then
		health.ok("mise found on $PATH")
	else
		health.warn("mise not found on $PATH", "https://mise.jdx.dev/getting-started.html")
	end

	local available = m.available()
	local registry = m.registry()
	for _, name in ipairs(available) do
		local entry = registry[name]
		health.ok(string.format("%s (%s)", name, entry.tool or entry.bin[1]))
	end
	if #available == 0 then
		health.warn("no known language server binaries found on $PATH")
	end
	if #m.options.exclude > 0 then
		health.info("excluded: " .. table.concat(M.sorted(m.options.exclude), ", "))
	end
	health.info(
		string.format(
			"%d of %d known servers installed. Look up an install spec with"
				.. " :lua =require('mise-lspconfig').tool('<server>')",
			#available,
			vim.tbl_count(registry)
		)
	)
end

---@param list string[]
---@return string[]
function M.sorted(list)
	local copy = vim.deepcopy(list)
	table.sort(copy)
	return copy
end

return M
