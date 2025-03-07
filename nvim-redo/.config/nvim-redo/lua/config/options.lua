-- [[ OPTIONS ]]
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.autoindent = true
opt.backup = false
opt.breakindent = true
opt.clipboard = "unnamedplus"
opt.cmdheight = 1
opt.completeopt = { "menu", "menuone", "noselect" }
opt.copyindent = true
opt.colorcolumn = "80"
opt.cursorcolumn = false
opt.cursorline = true
opt.errorbells = false
opt.expandtab = true
opt.exrc = true
opt.secure = true
opt.fileencoding = "utf-8"
opt.fillchars = { eob = " " }
opt.foldmethod = "syntax"
opt.foldenable = true
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.formatoptions:remove("o")
opt.foldcolumn = "0"
opt.guicursor = ""
opt.history = 100
opt.hlsearch = true
opt.ignorecase = true
opt.inccommand = "split"
opt.infercase = true
opt.laststatus = 3
opt.linebreak = true
opt.list = true
opt.listchars = {
  tab = "» ",
  space = "·",
  extends = "›",
  precedes = "‹",
  nbsp = "␣",
  -- eol = "¬",
  -- trail = ".",
}
opt.mouse = "a"
opt.number = true
opt.numberwidth = 3
opt.preserveindent = true
opt.pumheight = 10
opt.relativenumber = true
opt.scrolloff = 8
opt.shada = { "'10", "<0", "s10", "h" }
opt.shell = "bash"
opt.shiftwidth = 2
opt.showmatch = false
opt.showmode = false
opt.showtabline = 2
opt.shortmess:append("I")
opt.shortmess:append("c")
opt.sidescrolloff = 8
opt.signcolumn = "yes:2"
opt.smartcase = true
opt.smartindent = true
opt.smarttab = true
opt.softtabstop = 2
opt.spell = false
opt.splitbelow = true
opt.splitright = true
opt.swapfile = false
opt.tabstop = 2
opt.termguicolors = true
opt.timeoutlen = 300
opt.undodir = vim.fn.stdpath("data") .. "/undodir"
opt.viewdir = vim.fn.stdpath("data") .. "/viewdir"
opt.viewoptions = "folds,cursor,curdir"
opt.undofile = true
opt.updatetime = 250
opt.virtualedit = "block"
opt.wildignorecase = true
opt.wrap = true -- false
opt.writebackup = false
vim.g.have_nerd_font = true

-- [[ UTILITIES ]]
vim.g.clipboard = {
  name = "wl-clipboard",
  copy = {
    ["+"] = "wl-copy",
    ["*"] = "wl-copy",
  },
  paste = {
    ["+"] = "wl-paste --no-newline",
    ["*"] = "wl-paste --no-newline",
  },
  cache_enabled = 0,
}

-- [[ NETRW ]]
vim.g.netrw_keepdir = 0
vim.g.netrw_winsize = 20
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3
vim.g.netrw_browse_split = 4

-- [[ DISABLE BUILTIN LANGUAGE PROVIDERS ]]
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.ruby_host_prog = nil
vim.g.perl_host_prog = nil
vim.g.node_host_prog = nil
vim.g.python3_host_prog = nil
vim.g.loaded_netrw = 1
vim.g.loaded_netrwplugin = 1
vim.g.loaded_netrwsettings = 1
