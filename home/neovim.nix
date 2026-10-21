# rubicon only. apollo installs neovim from lib/packages.nix and configures
# it elsewhere; the phone needs the editor to be usable on first open, since
# there is no second machine to fix it from
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;

    # debian's own vim stays on /usr/bin/vim; the terminal app's recovery paths
    # assume it is there

    withRuby = false;
    withPython3 = false;

    initLua = ''
      vim.opt.number = true
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 2
      vim.opt.tabstop = 2
      vim.opt.smartindent = true
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.termguicolors = true
      vim.opt.mouse = "a"
      vim.opt.clipboard = "unnamedplus"
      vim.opt.undofile = true
      vim.opt.signcolumn = "yes"
      vim.opt.scrolloff = 4

      vim.g.mapleader = " "
      vim.keymap.set("n", "<leader>w", ":w<CR>")
      vim.keymap.set("n", "<leader>q", ":q<CR>")
      vim.keymap.set("n", "<Esc>", ":nohlsearch<CR>", { silent = true })
    '';
  };
}
