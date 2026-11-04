# nvim

Personal Neovim configuration, managed with [packer.nvim](https://github.com/wbthomason/packer.nvim).

## Requirements

- Neovim 0.9+
- A [Nerd Font](https://www.nerdfonts.com/font-downloads), set as your terminal font
- `ripgrep` and `fd` (used by Telescope)
- A C compiler (for Treesitter)
- Node.js (for LSP servers)

## Setup

```bash
# Clone into the Neovim config directory
git clone git@github.com:SofieneJOUINI/nvim.git ~/.config/nvim

# Install packer.nvim
git clone --depth 1 https://github.com/wbthomason/packer.nvim \
  ~/.local/share/nvim/site/pack/packer/start/packer.nvim

# Install ripgrep + fd
sudo apt install ripgrep fd-find      # or: brew install ripgrep fd

# Install a C compiler (needed by Treesitter to build parsers)
sudo apt install gcc                  # or on macOS: xcode-select --install
```

Launch Neovim and install the plugins:

```bash
nvim
```
```
:e ~/.config/nvim/lua/sofiene/packer.lua
:so
:PackerSync
```

Restart Neovim once the sync finishes.

## Structure

```
nvim/
├── init.lua
├── lua/sofiene/
│   ├── init.lua
│   ├── set.lua
│   ├── remap.lua
│   └── packer.lua
├── after/plugin/
└── plugin/packer_compiled.lua
```
