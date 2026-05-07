if vim.g.loaded_neovim_docker == 1 then
  return
end
vim.g.loaded_neovim_docker = 1

require("neovim-docker").setup(vim.g.neovim_docker or {})

