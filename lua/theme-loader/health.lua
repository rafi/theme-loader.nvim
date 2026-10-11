-- :checkhealth theme-loader
-- https://github.com/rafi/theme-loader.nvim

local M = {}

-- Reports whether `path` can be read, and whether its directory takes the
-- temp file a save renames over it.
---@param path string
local function check_file(path)
	local health = vim.health
	if vim.fn.filereadable(path) == 1 then
		health.ok('Readable: ' .. path)
	else
		health.info('Not created yet: ' .. path)
	end
	local dir = vim.fs.dirname(vim.uv.fs_realpath(path) or path)
	if vim.fn.isdirectory(dir) == 0 then
		health.info('Directory is created on first save: ' .. dir)
	elseif vim.fn.filewritable(dir) == 2 then
		health.ok('Writable directory: ' .. dir)
	else
		health.error('Directory is not writable, saves fail: ' .. dir)
	end
end

function M.check()
	local health = vim.health
	local Config = require('theme-loader.config')

	health.start('Requirements')
	if vim.fn.has('nvim-0.11') == 1 then
		health.ok('Neovim 0.11+')
	else
		health.error('Neovim 0.11+ required')
	end

	health.start('Configuration')
	local cfg = Config.get()
	if #Config.errors == 0 then
		health.ok('vim.g.theme_loader is valid')
	end
	for _, err in ipairs(Config.errors) do
		health.error(err, 'Fix vim.g.theme_loader; the default is in use')
	end
	for _, key in ipairs(Config.unknown()) do
		health.warn(('Unknown option vim.g.theme_loader.%s'):format(key))
	end

	health.start('Persistence')
	local json = cfg.json_file_path
	if json and vim.fn.filereadable(json) == 1 then
		health.info('Saving to the `colorscheme` key of the JSON file')
		check_file(json)
	else
		if json then
			health.info('JSON file not found, using the cache file: ' .. json)
		end
		health.info('Saving to the plain-text cache file')
		check_file(cfg.cache_file_path)
	end
	local override = vim.g.theme_colorscheme
	if type(override) == 'string' and #override > 0 then
		health.info(
			('vim.g.theme_colorscheme = %q overrides it at startup'):format(override)
		)
	end

	health.start('Themes')
	if vim.fn.isdirectory(cfg.theme_directory) == 1 then
		health.ok('Theme directory: ' .. cfg.theme_directory)
	else
		health.info('No theme directory: ' .. cfg.theme_directory)
	end
end

return M
