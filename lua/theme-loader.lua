-- Rafi's colorscheme and theme loader
-- https://github.com/rafi/theme-loader.nvim

local M = {}

---The file system path separator for the current platform.
M.path_separator = package.config:sub(1, 1)

---@type RafiThemeConfig
local opts = {}

---@class RafiThemeConfig
local default_opts = {
	autostart = true,
	initial_colorscheme = 'habamax',
	fallback_colorscheme = 'habamax',
	cache_file_path = vim.fn.stdpath('data') .. M.path_separator .. 'theme.txt',
	theme_directory = vim.fn.stdpath('config') .. M.path_separator .. 'themes',
}

---@param user_opts table|nil
function M.setup(user_opts)
	opts = vim.tbl_deep_extend('keep', user_opts or {}, default_opts)

	-- Load custom theme layer, once colorscheme changes
	vim.api.nvim_create_autocmd('ColorScheme', {
		group = vim.api.nvim_create_augroup('theme_loader', {}),
		callback = function()
			local theme = require('theme-loader')
			theme.load_user_theme()
			theme.save_colorscheme()
		end,
	})

	if opts.autostart then
		-- Restore last used colorscheme, or set initial.
		require('theme-loader').start()
	end
end

function M.start()
	local want = M._get_last_colorscheme()
	local ok = pcall(vim.cmd.colorscheme, want)
	if not ok then
		vim.cmd.colorscheme(opts.fallback_colorscheme)
		vim.notify(
			string.format('Using "%s" instead', opts.fallback_colorscheme),
			vim.log.levels.ERROR,
			{ title = string.format('Unable to load "%s" colorscheme', want) }
		)
	end
end

-- Called when colorscheme changes, it loads a user custom theme with the same
-- name, located in ~/.config/nvim/themes/<name>.vim -- if exists.
function M.load_user_theme()
	local colorscheme = vim.g['colors_name']
	if colorscheme == nil then
		return
	end

	local theme_path = M.path_join(opts.theme_directory, colorscheme .. '.vim')
	if theme_path and vim.loop.fs_stat(theme_path) then
		vim.cmd.source(theme_path)
	end
end

-- Persist the current colorscheme name in a plain-text file.
function M.save_colorscheme()
	local colorscheme = vim.g['colors_name']
	if colorscheme == nil or colorscheme == opts.fallback_colorscheme then
		return
	end
	local fd = vim.loop.fs_open(opts.cache_file_path, 'w', 432)
	if fd == nil then
		vim.notify('Error: Unable to open file ' .. opts.cache_file_path)
		return
	end
	vim.loop.fs_write(fd, colorscheme, -1)
	vim.loop.fs_close(fd)
end

-- Get last-used colorscheme which is stored in a plain-text file.
---@return string
function M._get_last_colorscheme()
	local want = ''
	if vim.loop.fs_stat(opts.cache_file_path) then
		local fd = vim.loop.fs_open(opts.cache_file_path, 'r', 438)
		if fd == nil then
			vim.notify('Error: Unable to open file '.. opts.cache_file_path)
			return opts.initial_colorscheme
		end
		local raw = vim.loop.fs_read(fd, 256, 0) or ''
		vim.loop.fs_close(fd)

		raw = tostring(raw):gsub('\r', '')
		want = vim.split(raw, '\n')[1]
	end
	if #want == 0 then
		want = opts.initial_colorscheme
	end
	return want
end

-- Join paths.
M.path_join = function(...)
	return table.concat({ ... }, M.path_separator)
end

return M
