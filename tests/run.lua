-- Test runner: nvim -l tests/run.lua
vim.opt.rtp:prepend(".")

local failed = 0
for _, spec in ipairs(vim.fn.glob("tests/*_spec.lua", false, true)) do
	local ok, err = pcall(dofile, spec)
	if ok then
		print("PASS " .. spec)
	else
		failed = failed + 1
		print("FAIL " .. spec .. "\n" .. tostring(err))
	end
end
os.exit(failed == 0 and 0 or 1)
