-- theme-loader.nvim configuration: defaults merged with `vim.g.theme_loader`.
-- https://github.com/rafi/theme-loader.nvim

---@class theme_loader.Config
---@field autostart boolean Restore the last colorscheme on VimEnter.
---@field initial_colorscheme string Used when nothing was saved yet.
---@field fallback_colorscheme string Used when the wanted colorscheme fails to load.
---@field cache_file_path string Plain-text file holding the last colorscheme, used when there is no JSON file.
---@field theme_directory string Directory of per-colorscheme `<name>.vim` or `<name>.lua` files.
---@field json_file_path? string JSON file whose `colorscheme` key is read and saved instead of cache_file_path, when the file exists.

---User options; every field is optional.
---@class (partial) theme_loader.PartialConfig: theme_loader.Config

---@type theme_loader.PartialConfig?
vim.g.theme_loader = vim.g.theme_loader

local M = {}

---@type theme_loader.Config
M.defaults = {
	autostart = true,
	initial_colorscheme = 'habamax',
	fallback_colorscheme = 'habamax',
	cache_file_path = vim.fs.joinpath(vim.fn.stdpath('state'), 'theme.txt'),
	theme_directory = vim.fs.joinpath(vim.fn.stdpath('config'), 'themes'),
	json_file_path = nil,
}

-- Expected type of each option. Optional ones may be nil.
---@type table<string, { [1]: string, [2]: boolean? }>
local types = {
	autostart = { 'boolean' },
	initial_colorscheme = { 'string' },
	fallback_colorscheme = { 'string' },
	cache_file_path = { 'string' },
	theme_directory = { 'string' },
	json_file_path = { 'string', true },
}

-- Messages of the invalid options in `vim.g.theme_loader`, for :checkhealth.
---@type string[]
M.errors = {}

local resolved ---@type theme_loader.Config?

-- Checks the types of a merged config. Every invalid field is replaced by
-- its default. Returns one message per invalid field, naming it, e.g.
-- `vim.g.theme_loader.autostart: expected boolean, got string`.
---@param cfg table
---@return string[] errors
function M.validate(cfg)
	local errors = {} ---@type string[]
	local keys = vim.tbl_keys(types)
	table.sort(keys)
	for _, key in ipairs(keys) do
		local t = types[key]
		local ok, err =
			pcall(vim.validate, 'vim.g.theme_loader.' .. key, cfg[key], t[1], t[2])
		if not ok then
			-- Drop the "file:line: " prefix error() may add.
			errors[#errors + 1] = (tostring(err):gsub('^[^\n]-:%d+: ', ''))
			cfg[key] = M.defaults[key]
		end
	end
	return errors
end

-- Keys of `vim.g.theme_loader` that theme-loader doesn't know (typos).
---@return string[]
function M.unknown()
	local user = vim.g.theme_loader
	if type(user) ~= 'table' then
		return {}
	end
	local ret = {} ---@type string[]
	for key in pairs(user) do
		if types[key] == nil then
			ret[#ret + 1] = tostring(key)
		end
	end
	table.sort(ret)
	return ret
end

-- Merges `vim.g.theme_loader` over the defaults. Invalid fields are
-- reported once and replaced by their defaults.
---@return theme_loader.Config
local function resolve()
	local user = vim.g.theme_loader
	local cfg = vim.deepcopy(M.defaults)
	local errors = {} ---@type string[]
	if type(user) == 'table' then
		cfg = vim.tbl_deep_extend('force', cfg, user)
		errors = M.validate(cfg)
	elseif user ~= nil then
		errors = { 'vim.g.theme_loader: expected table, got ' .. type(user) }
	end
	M.errors = errors
	if #errors > 0 then
		vim.notify(
			('theme-loader: %s. Using defaults for these.'):format(
				table.concat(errors, ', ')
			),
			vim.log.levels.ERROR
		)
	end
	return cfg
end

-- The resolved config. Read on first use, so `vim.g.theme_loader` can be
-- set anywhere before VimEnter.
---@return theme_loader.Config
function M.get()
	resolved = resolved or resolve()
	return resolved
end

-- Merges `opts` into `vim.g.theme_loader`. The next get() re-reads it.
---@param opts? theme_loader.PartialConfig
function M.set(opts)
	local user = vim.g.theme_loader
	vim.g.theme_loader = vim.tbl_deep_extend(
		'force',
		type(user) == 'table' and user or {},
		opts or {}
	)
	resolved = nil
end

return M
