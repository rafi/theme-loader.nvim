-- theme-loader: startup restore from the JSON and plain-text files, saves
-- (debounced, atomic, other JSON keys kept), transient overrides, the
-- fallback, config validation, health and the plugin/ entry point.

local H = { eq = MiniTest.expect.equality, expect = MiniTest.expect }

-- Plugin root, from this file's path.
local root = vim.fn.fnameescape(
	vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
)

-- Per-case temp dir.
local tmp ---@type string

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			tmp = vim.fn.tempname()
			vim.fn.mkdir(tmp, 'p')
		end,
		post_case = function()
			child.stop()
			vim.fn.delete(tmp, 'rf')
		end,
	},
})

---@param path string
---@param data table
local function write_json(path, data)
	vim.fn.writefile({ vim.json.encode(data) }, path)
end

---@param path string
---@return table
local function read_json(path)
	return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
end

-- Runs in the child before plugin/ files load: records notifications and
-- counts file renames, i.e. saves.
local child_stub = [[lua
	_G.msgs = {}
	vim.notify = function(msg) table.insert(_G.msgs, msg) end
	_G.renames = 0
	local rename = vim.uv.fs_rename
	vim.uv.fs_rename = function(...)
		_G.renames = _G.renames + 1
		return rename(...)
	end
]]

-- Starts a child Neovim with this plugin on 'runtimepath'. `opts` becomes
-- vim.g.theme_loader (cache file under `tmp` by default), `extra` adds
-- --cmd lines, run before plugin/ files load.
---@param opts? table|false false leaves vim.g.theme_loader unset
---@param extra? string[]
local function start_child(opts, extra)
	local args = {
		'--cmd',
		'set rtp^=' .. root,
		'--cmd',
		(child_stub:gsub('\n', ' ')),
	}
	if opts ~= false then
		opts = vim.tbl_extend('force', {
			cache_file_path = tmp .. '/theme.txt',
			theme_directory = tmp .. '/themes',
		}, opts or {})
		vim.list_extend(args, {
			'--cmd',
			'lua vim.g.theme_loader = ' .. vim.inspect(opts, { newline = ' ' }),
		})
	end
	for _, cmd in ipairs(extra or {}) do
		vim.list_extend(args, { '--cmd', cmd })
	end
	child.start(args)
end

-- Lets the child's save delay run out.
local function wait_save()
	child.lua('vim.wait(600, function() return false end)')
end

-- Startup ----------------------------------------------------------------

T['startup'] = MiniTest.new_set()

T['startup']['restores the colorscheme from the JSON file'] = function()
	local json = tmp .. '/rafi.json'
	write_json(json, { extras = { 'a' }, colorscheme = 'desert' })
	start_child({ json_file_path = json })
	H.eq(child.g.colors_name, 'desert')
	wait_save()
	H.eq(child.lua_get('_G.renames'), 0)
end

T['startup']['restores the colorscheme from the cache file'] = function()
	vim.fn.writefile({ 'evening' }, tmp .. '/theme.txt')
	start_child()
	H.eq(child.g.colors_name, 'evening')
end

T['startup']['uses the cache file when the JSON file is missing'] = function()
	vim.fn.writefile({ 'evening' }, tmp .. '/theme.txt')
	start_child({ json_file_path = tmp .. '/missing.json' })
	H.eq(child.g.colors_name, 'evening')
end

T['startup']['uses initial_colorscheme when nothing is saved'] = function()
	start_child({ initial_colorscheme = 'morning' })
	H.eq(child.g.colors_name, 'morning')
	wait_save()
	H.eq(vim.fn.filereadable(tmp .. '/theme.txt'), 0)
end

T['startup']['applies vim.g.theme_colorscheme without saving it'] = function()
	local json = tmp .. '/rafi.json'
	write_json(json, { colorscheme = 'desert' })
	start_child({ json_file_path = json }, { 'let g:theme_colorscheme = "blue"' })
	H.eq(child.g.colors_name, 'blue')
	wait_save()
	H.eq(read_json(json).colorscheme, 'desert')
end

T['startup']['falls back and keeps the saved name'] = function()
	local json = tmp .. '/rafi.json'
	write_json(json, { colorscheme = 'no-such-scheme' })
	start_child({ json_file_path = json, fallback_colorscheme = 'shine' })
	H.eq(child.g.colors_name, 'shine')
	H.eq(child.lua_get('#_G.msgs'), 1)
	wait_save()
	H.eq(read_json(json).colorscheme, 'no-such-scheme')
end

T['startup']['reports a fallback that fails too'] = function()
	start_child({
		initial_colorscheme = 'no-such-scheme',
		fallback_colorscheme = 'no-such-fallback',
	})
	H.eq(child.g.colors_name, vim.NIL)
	H.eq(child.lua_get('_G.msgs'), { 'Fallback "no-such-fallback" failed too' })
	H.eq(child.v.errmsg, '')
end

T['startup']['does nothing with autostart = false'] = function()
	vim.fn.writefile({ 'evening' }, tmp .. '/theme.txt')
	start_child({ autostart = false })
	H.eq(child.g.colors_name, vim.NIL)
	H.eq(child.lua_get([[package.loaded['theme-loader'] == nil]]), true)
end

T['startup']['setup() sets options before VimEnter'] = function()
	local json = tmp .. '/rafi.json'
	write_json(json, { colorscheme = 'desert' })
	start_child(false, {
		([[lua require('theme-loader').setup({ json_file_path = %q })]]):format(
			json
		),
	})
	H.eq(child.g.colors_name, 'desert')
end

T['startup']['restores when loaded after startup'] = function()
	vim.fn.writefile({ 'evening' }, tmp .. '/theme.txt')
	child.start({})
	child.lua(
		('vim.g.theme_loader = { cache_file_path = %q }'):format(
			tmp .. '/theme.txt'
		)
	)
	child.cmd('set rtp^=' .. root .. ' | runtime plugin/theme-loader.lua')
	child.lua('vim.wait(100, function() return false end)')
	H.eq(child.g.colors_name, 'evening')
end

-- Saving -------------------------------------------------------------------

T['save'] = MiniTest.new_set()

T['save']['writes the JSON key and keeps the other keys'] = function()
	local json = tmp .. '/rafi.json'
	write_json(json, { extras = { 'a' }, disabled = {}, colorscheme = 'desert' })
	start_child({ json_file_path = json })
	child.cmd('colorscheme blue')
	wait_save()
	H.eq(
		read_json(json),
		{ extras = { 'a' }, disabled = {}, colorscheme = 'blue' }
	)
end

T['save']['writes the cache file without a JSON file'] = function()
	start_child({ cache_file_path = tmp .. '/new/theme.txt' })
	child.cmd('colorscheme blue')
	wait_save()
	H.eq(vim.fn.readfile(tmp .. '/new/theme.txt'), { 'blue' })
end

T['save']['writes once for rapid changes'] = function()
	local json = tmp .. '/rafi.json'
	write_json(json, { colorscheme = 'desert' })
	start_child({ json_file_path = json })
	-- Separate calls with a short gap, like a picker previewing each item.
	for _, name in ipairs({ 'blue', 'evening', 'morning', 'shine', 'pablo' }) do
		child.cmd('colorscheme ' .. name)
		child.lua('vim.wait(50, function() return false end)')
	end
	H.eq(read_json(json).colorscheme, 'desert')
	wait_save()
	H.eq(child.lua_get('_G.renames'), 1)
	H.eq(read_json(json).colorscheme, 'pablo')
end

T['save']['skips a change that was reverted'] = function()
	local json = tmp .. '/rafi.json'
	write_json(json, { colorscheme = 'desert' })
	start_child({ json_file_path = json })
	child.cmd('colorscheme blue | colorscheme desert')
	wait_save()
	H.eq(child.lua_get('_G.renames'), 0)
end

T['save']['saves the fallback colorscheme when picked'] = function()
	local json = tmp .. '/rafi.json'
	write_json(json, { colorscheme = 'desert' })
	start_child({ json_file_path = json })
	child.cmd('colorscheme habamax')
	wait_save()
	H.eq(read_json(json).colorscheme, 'habamax')
end

T['save']['saves a pending change on exit'] = function()
	local json = tmp .. '/rafi.json'
	write_json(json, { colorscheme = 'desert' })
	local opts = vim.inspect({ json_file_path = json }, { newline = ' ' })
	local res = vim
		.system({
			vim.v.progpath,
			'--clean',
			'--headless',
			'--cmd',
			'set rtp^=' .. root,
			'--cmd',
			'lua vim.g.theme_loader = ' .. opts,
			'--cmd',
			'autocmd VimEnter * ++once lua vim.schedule(function()'
				.. ' vim.cmd.colorscheme("blue") vim.cmd.qall() end)',
		}, { text = true })
		:wait(10000)
	H.eq(res.code, 0)
	H.eq(read_json(json).colorscheme, 'blue')
end

T['save']['replaces a symlinked JSON file at its target'] = function()
	local target = tmp .. '/real.json'
	local link = tmp .. '/rafi.json'
	write_json(target, { colorscheme = 'desert' })
	assert(vim.uv.fs_symlink(target, link))
	start_child({ json_file_path = link })
	child.cmd('colorscheme blue')
	wait_save()
	H.eq(vim.uv.fs_lstat(link).type, 'link')
	H.eq(read_json(target).colorscheme, 'blue')
	H.eq(vim.fn.glob(tmp .. '/*.tmp', true, true), {})
end

T['save']['leaves a malformed JSON file alone'] = function()
	local json = tmp .. '/rafi.json'
	vim.fn.writefile({ '{ "colorscheme": ' }, json)
	start_child({ json_file_path = json })
	child.cmd('colorscheme blue')
	wait_save()
	H.eq(vim.fn.readfile(json), { '{ "colorscheme": ' })
	H.eq(vim.fn.readfile(tmp .. '/theme.txt'), { 'blue' })
end

-- User themes -------------------------------------------------------------

T['loads the user theme of the colorscheme'] = function()
	vim.fn.mkdir(tmp .. '/themes', 'p')
	vim.fn.writefile(
		{ 'vim.g.user_theme = vim.g.colors_name' },
		tmp .. '/themes/blue.lua'
	)
	start_child()
	H.eq(child.g.user_theme, vim.NIL)
	child.cmd('colorscheme blue')
	H.eq(child.g.user_theme, 'blue')
end

-- Configuration -----------------------------------------------------------

T['config'] = MiniTest.new_set()

T['config']['reports an invalid field and uses its default'] = function()
	vim.fn.writefile({ 'evening' }, tmp .. '/theme.txt')
	start_child({ autostart = 'no', initial_colorscheme = 1 })
	H.eq(child.g.colors_name, 'evening')
	H.eq(child.lua_get('_G.msgs'), {
		'theme-loader: vim.g.theme_loader.autostart: expected boolean, got string,'
			.. ' vim.g.theme_loader.initial_colorscheme: expected string, got number.'
			.. ' Using defaults for these.',
	})
end

T['config']['reports a non-table value'] = function()
	start_child(false, { 'let g:theme_loader = 1' })
	H.eq(child.lua_get('_G.msgs'), {
		'theme-loader: vim.g.theme_loader: expected table, got number.'
			.. ' Using defaults for these.',
	})
end

T['health'] = function()
	start_child({ autostart = 'no', bogus = 1 })
	child.cmd('checkhealth theme-loader')
	local text = table.concat(child.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
	H.expect.no_equality(
		text:find('vim.g.theme_loader.autostart: expected boolean', 1, true),
		nil
	)
	H.expect.no_equality(
		text:find('Unknown option vim.g.theme_loader.bogus', 1, true),
		nil
	)
	H.expect.no_equality(
		text:find('Saving to the plain-text cache file', 1, true),
		nil
	)
end

return T
