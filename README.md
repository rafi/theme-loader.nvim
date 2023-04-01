# Neovim Theme Loader

> Set last-used colorscheme and load custom user's custom highlights per colorscheme.

## Overview

Features:

- Set last-used colorscheme
- Load user's custom highlights per colorscheme

## Install

Requirements:

- [Neovim] ≥0.8

Use your favorite package-manager:

<details>
<summary>With <a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></summary>

```lua
{
  'rafi/theme-loader.nvim',
  version = false,
  priority = 999,
  opts = true,
},
```

</details>

<details>
<summary>With <a href="https://github.com/wbthomason/packer.nvim">packer.nvim</a></summary>

```lua
use { 'rafi/theme-loader.nvim' }
```

</details>

## Setup

If you're using [lazy.nvim], set `config` or `opts` property (See
[Install](#install) instructions).

Otherwise, setup manually:

```lua
require('theme-loader').setup()
```

## Config

These are the default settings:

```lua
require('theme-loader').setup({
  autostart = true,
  initial_colorscheme = 'habamax',
  fallback_colorscheme = 'habamax',
  cache_file_path = vim.fn.stdpath('data') .. '/theme.txt',
  theme_directory = vim.fn.stdpath('config') .. '/themes',
})
```

## Themes (Override Colorschemes)

If you'd like to easily override highlights for a certain colorscheme, create
a file at `~/.config/nvim/themes/<name>.vim` (replace `<name>` with the
colorscheme you'd like to override).

For example, to add custom highlights for `nordic` colorscheme, create:

- `~/.config/nvim/themes/nordic.vim`

And start highlighting, there is **no** need to use `autocmd ColorScheme`:

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
