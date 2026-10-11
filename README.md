# Neovim Theme Loader

> Set last-used colorscheme and load custom user's custom highlights per colorscheme.

## Overview

Features:

- Set last-used colorscheme
- Load user's custom highlights per colorscheme

It works once installed, with no `setup()` call. Nothing is loaded until
`VimEnter`.

## Install

Requirements:

- [Neovim] ≥0.11

Use your favorite package-manager:

<details>
<summary>With <code>vim.pack</code> (Neovim 0.12+)</summary>

```lua
vim.pack.add({ 'https://github.com/rafi/theme-loader.nvim' })
```

</details>

<details>
<summary>With <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></summary>

```lua
{
  'rafi/theme-loader.nvim',
  version = false,
  lazy = false,
  priority = 999,
},
```

</details>

<details>
<summary>With <a href="https://github.com/wbthomason/packer.nvim">packer.nvim</a></summary>

```lua
use { 'rafi/theme-loader.nvim' }
```

</details>

## Config

Set `vim.g.theme_loader` before `VimEnter`. All fields are optional. Defaults:

```lua
vim.g.theme_loader = {
  autostart = true,
  initial_colorscheme = 'habamax',
  fallback_colorscheme = 'habamax',
  cache_file_path = vim.fn.stdpath('state') .. '/theme.txt',
  theme_directory = vim.fn.stdpath('config') .. '/themes',
  json_file_path = nil,
}
```

- `autostart`: restore the colorscheme in a one-shot `VimEnter` autocmd, so
  all `colors/` directories are on `runtimepath` and `ColorScheme` autocmds
  fire. If the plugin loads after startup, it restores immediately. Set it to
  `false` and call `require('theme-loader').start()` to control the timing.
- `json_file_path`: store the colorscheme in the `colorscheme` key of an
  existing JSON file, such as `rafi.json` in
  [Rafi's config](https://github.com/rafi/vim-config).

`require('theme-loader').setup(opts)` merges `opts` into `vim.g.theme_loader`,
so lazy.nvim `opts` work.

An invalid field is reported once and its default is used.
`:checkhealth theme-loader` shows config errors, unknown keys and the file
the colorscheme is saved to.

## Selecting the colorscheme

At startup, the first available source is used:

1. `vim.g.theme_colorscheme`, a non-empty string set before `start()` runs.
2. The `colorscheme` key of the JSON file at `json_file_path`, if the file
   exists and contains a JSON object.
3. The text file at `cache_file_path`, if the JSON file doesn't exist.

If the source is empty, `initial_colorscheme` is used. If loading fails,
`fallback_colorscheme` is applied and an error is shown.

## Saving the colorscheme

A colorscheme change is saved to the JSON file if it exists, keeping its
other keys, otherwise to the text file. The save runs after 250 ms without
another change, so browsing a picker writes once and a cancelled preview
writes nothing. A pending change is saved on exit. Files are written to a
temporary file and renamed, so readers never see a partial file.

Startup choices are not saved: a `vim.g.theme_colorscheme` override is
one-off and a fallback doesn't replace the saved name. A colorscheme you
select yourself is always saved.

## Themes (Override Colorschemes)

To override highlights for a colorscheme, create `<name>.vim` or `<name>.lua`
in `theme_directory` (default `~/.config/nvim/themes`), where `<name>` is the
colorscheme name. The file is sourced after the colorscheme loads, so no
`ColorScheme` autocmd is needed.

Example, `~/.config/nvim/themes/nordic.vim`:

```vim
" My custom colors
highlight User1 guifg=#D7D7BC guibg=#30302c ctermfg=251 ctermbg=236
highlight User2 guifg=#a8a897 guibg=#4e4e43 ctermfg=248 ctermbg=239
highlight User3 guifg=#4e4e43 guibg=#30302c ctermfg=239 ctermbg=236
highlight User4 guifg=#666656 guibg=#30302c ctermfg=242 ctermbg=236
highlight User5 guifg=#cf6a4c guibg=#30302c ctermfg=167 ctermbg=236
highlight User6 guifg=#99ad6a guibg=#30302c ctermfg=107 ctermbg=236
highlight User7 guifg=#ffb964 guibg=#30302c ctermfg=215 ctermbg=236
```

## See Also

Alternatives:

- [propet/colorscheme-persist.nvim](https://github.com/propet/colorscheme-persist.nvim)

[Neovim]: https://github.com/neovim/neovim
[lazy.nvim]: https://github.com/folke/lazy.nvim
