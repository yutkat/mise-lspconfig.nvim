-- Inject a fake generated registry before the module under test loads it.
-- "sh" exists on every CI runner; the "missing" bin must not.
package.loaded["mise-lspconfig.registry"] = {
	present = { tool = "npm:present", bin = { "sh" } },
	fallback_bin = { tool = "npm:fallback", bin = { "mise-lspconfig-no-such-bin", "sh" } },
	absent = { tool = "npm:absent", bin = { "mise-lspconfig-no-such-bin" } },
	unwanted = { tool = "npm:unwanted", bin = { "sh" } },
}
package.loaded["mise-lspconfig"] = nil
local m = require("mise-lspconfig")

local function eq(expected, actual, msg)
	assert(
		vim.deep_equal(expected, actual),
		(msg or "not equal") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual)
	)
end

-- available(): only servers with an executable bin, minus excludes, sorted
m.setup({ auto_enable = false, exclude = { "unwanted" } })
eq({ "fallback_bin", "present" }, m.available())

-- overrides can add servers unknown to the generated registry
m.setup({ auto_enable = false, exclude = { "unwanted" }, overrides = { nixd = { bin = { "sh" } } } })
eq({ "fallback_bin", "nixd", "present" }, m.available())

-- tool(): install-spec lookup for health hints
eq("npm:present", m.tool("present"))
eq(nil, m.tool("nonexistent"))

-- enable() reports what it enabled and registers the servers
local enabled = m.enable()
eq({ "fallback_bin", "nixd", "present" }, enabled)
eq(true, vim.lsp.is_enabled("present"))
eq(false, vim.lsp.is_enabled("absent"))
eq(false, vim.lsp.is_enabled("unwanted"))

-- setup with auto_enable (default) enables immediately
package.loaded["mise-lspconfig"] = nil
m = require("mise-lspconfig")
m.setup({ exclude = { "unwanted", "fallback_bin", "nixd" } })
eq(true, vim.lsp.is_enabled("present"))
