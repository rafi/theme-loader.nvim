-- Rafi's colorscheme and theme loader
-- https://github.com/rafi/theme-loader.nvim

local Config = require('theme-loader.config')

local uv = vim.uv

local M = {}

---The file system path separator for the current platform.
M.path_separator = package.config:sub(1, 1)

-- Milliseconds to wait after the last ColorScheme before saving it, so a
-- picker previewing colorschemes writes once.
local save_delay = 250

-- True while start() applies a colorscheme. Its ColorScheme isn't saved,
-- since it is already saved, a default, an override or the fallback.
local starting = false

-- A colorscheme change is waiting on the save timer.
local pending = false

local timer ---@type uv.uv_timer_t?

---Set options, merged into `vim.g.theme_loader`. Kept for plugin managers
---and configs that call it. Setting `vim.g.theme_loader` works the same.
---@param opts? theme_loader.PartialConfig
function M.setup(opts)
	vim.validate('opts', opts, 'table', true)
	Config.set(opts)
end

---Apply the last-used colorscheme (see |theme-loader-select|), or the
---fallback colorscheme when it fails to load.
function M.start()
	local cfg = Config.get()
	local want = M.last_colorscheme()
	starting = true
	local ok = pcall(vim.cmd.colorscheme, want)
	if not ok then
		local ok_fallback = pcall(vim.cmd.colorscheme, cfg.fallback_colorscheme)
		vim.notify(
			ok_fallback and ('Using "%s" instead'):format(cfg.fallback_colorscheme)
				or ('Fallback "%s" failed too'):format(cfg.fallback_colorscheme),
			vim.log.levels.ERROR,
			{ title = ('Unable to load "%s" colorscheme'):format(want) }
		)
	end
	starting = false
end

---Source `<theme_directory>/<colors_name>.vim` or `.lua`, if it exists.
function M.load_user_theme()
	local colorscheme = vim.g.colors_name
	if colorscheme == nil then
		return
	end
	local dir = Config.get().theme_directory
	for _, ext in ipairs({ '.vim', '.lua' }) do
		local theme_path = M.path_join(dir, colorscheme .. ext)
		if uv.fs_stat(theme_path) then
			vim.cmd.source(vim.fn.fnameescape(theme_path))
			break
		end
	end
end

---Handle ColorScheme: load the user theme and save the colorscheme after
---a short delay. A new change restarts the delay.
---@private
function M.on_colorscheme()
	M.load_user_theme()
	if starting then
		return
	end
	pending = true
	timer = timer or assert(uv.new_timer())
	timer:stop()
	timer:start(save_delay, 0, vim.schedule_wrap(M.flush))
end

---Save a colorscheme change still waiting on its delay, now.
function M.flush()
	if timer then
		timer:stop()
	end
	if not pending then
		return
	end
	pending = false
	M.save_colorscheme()
end

---@param path string
---@return string? content
local function read_file(path)
	local fd = uv.fs_open(path, 'r', 438)
	if not fd then
		return nil
	end
	local stat = uv.fs_fstat(fd)
	local data = stat and uv.fs_read(fd, stat.size, 0)
	uv.fs_close(fd)
	return data
end

-- Writes a temp file next to `path`, then renames it over `path`, so
-- another Neovim never reads a half-written file. A symlink is replaced
-- at its target. Keeps the file's permissions.
---@param path string
---@param content string
---@return boolean ok
---@return string? err
local function write_atomic(path, content)
	path = uv.fs_realpath(path) or path
	local stat = uv.fs_stat(path)
	local mode = stat and stat.mode % 512 or 420
	local tmp = ('%s.%d.tmp'):format(path, uv.os_getpid())
	local fd, err = uv.fs_open(tmp, 'w', mode)
	if not fd then
		return false, err
	end
	local written, werr = uv.fs_write(fd, content, 0)
	uv.fs_close(fd)
	if written then
		local renamed, rerr = uv.fs_rename(tmp, path)
		if renamed then
			return true
		end
		werr = rerr
	end
	uv.fs_unlink(tmp)
	return false, werr
end

-- Read and decode `json_file_path`. Returns nil when the option is unset,
-- the file is missing or isn't a valid JSON object, so callers fall back
-- to the plain-text cache file and never overwrite a file they couldn't
-- parse.
---@return table?
local function read_json()
	local path = Config.get().json_file_path
	local raw = path and read_file(path)
	if not raw then
		return nil
	end
	local ok, data = pcall(vim.json.decode, raw)
	if not ok or type(data) ~= 'table' then
		return nil
	end
	return data
end

-- Read the first line of the plain-text cache file, or '' if there is none.
---@return string
local function read_cache_file()
	local raw = read_file(Config.get().cache_file_path) or ''
	return vim.split(raw:gsub('\r', ''), '\n')[1]
end

---Persist the current colorscheme name now: in the `colorscheme` key of
---the JSON file if it exists (other keys are kept), otherwise in the
---plain-text cache file.
function M.save_colorscheme()
	local colorscheme = vim.g.colors_name
	if colorscheme == nil then
		return
	end
	local cfg = Config.get()
	local path, content ---@type string, string
	local data = read_json()
	if data then
		if data.colorscheme == colorscheme then
			return
		end
		data.colorscheme = colorscheme
		local ok, json = pcall(vim.json.encode, data, { indent = '  ' })
		-- The JSON file exists, so the option is set.
		path = cfg.json_file_path --[[@as string]]
		content = (ok and json or vim.json.encode(data)) .. '\n'
	else
		if read_cache_file() == colorscheme then
			return
		end
		path, content = cfg.cache_file_path, colorscheme
		vim.fn.mkdir(vim.fs.dirname(path), 'p')
	end
	local ok, err = write_atomic(path, content)
	if not ok then
		vim.notify(
			('theme-loader: unable to write %s: %s'):format(path, err),
			vim.log.levels.ERROR
		)
	end
end

---The colorscheme start() applies. First match wins:
---1. `vim.g.theme_colorscheme`, if set.
---2. The `colorscheme` key of the JSON file, if the file exists.
---3. The plain-text cache file, if the JSON file doesn't exist.
---Falls back to `initial_colorscheme` when the chosen source is empty.
---@return string
function M.last_colorscheme()
	local want = vim.g.theme_colorscheme
	if type(want) ~= 'string' or #want == 0 then
		local data = read_json()
		if data then
			want = data.colorscheme
		else
			want = read_cache_file()
		end
	end
	if type(want) ~= 'string' or #want == 0 then
		want = Config.get().initial_colorscheme
	end
	return want
end

---Join paths with the platform's separator.
---@param ... string
---@return string
function M.path_join(...)
	return table.concat({ ... }, M.path_separator)
end

return M
