-- theme-loader.nvim entry point: restores the last-used colorscheme on
-- VimEnter and saves it on ColorScheme. Requires nothing until then.
if vim.g.loaded_theme_loader then
	return
end
vim.g.loaded_theme_loader = true

-- One group for every autocmd. clear = false so sourcing again keeps the
-- ColorScheme autocmd.
local group = vim.api.nvim_create_augroup('theme_loader', { clear = false })

vim.api.nvim_create_autocmd('ColorScheme', {
	group = group,
	desc = 'theme-loader: load user theme, save colorscheme',
	callback = function()
		require('theme-loader').on_colorscheme()
	end,
})

-- Saves a colorscheme change still waiting on its save delay.
vim.api.nvim_create_autocmd('VimLeavePre', {
	group = group,
	desc = 'theme-loader: save pending colorscheme',
	callback = function()
		local theme_loader = package.loaded['theme-loader']
		if theme_loader then
			theme_loader.flush()
		end
	end,
})

local function autostart()
	if require('theme-loader.config').get().autostart then
		require('theme-loader').start()
	end
end

if vim.v.vim_did_enter == 1 then
	-- Loaded after startup: wait a tick, so a setup() call right after
	-- loading still applies.
	vim.schedule(autostart)
else
	-- Waits for VimEnter so every plugin's colors/ directory is on
	-- 'runtimepath' first. nested lets the `:colorscheme` it runs fire
	-- ColorScheme for this and other plugins.
	vim.api.nvim_create_autocmd('VimEnter', {
		group = group,
		once = true,
		nested = true,
		desc = 'theme-loader: restore last colorscheme',
		callback = autostart,
	})
end
