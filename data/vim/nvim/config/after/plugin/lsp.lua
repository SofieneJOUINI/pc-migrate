local lsp = require('lsp-zero')
lsp.preset('recommended')
lsp.ensure_installed({
	'jdtls',
	'eslint'})

local cmp = require('cmp')
local cmp_select = {behavior = cmp.SelectBehavior.Select}

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(event)
    local opts = {buffer = event.buf, remap = false}
    vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
    vim.keymap.set("n", "gi", function() require('telescope.builtin').lsp_implementations({
        fname_width = 100,
        path_display = { "smart" }
    }) end, opts)
    vim.keymap.set("n", "<leader>h", function() vim.lsp.buf.hover() end, opts)
    vim.keymap.set("n", "<leader>ws", function() vim.lsp.buf.workspace_symbol() end, opts)
    vim.keymap.set("n", "<leader>ca", function() vim.lsp.buf.code_action() end, opts)
    vim.keymap.set("n", "<leader>rr",  function() require('telescope.builtin').lsp_references({
        fname_width = 100,
        path_display = { "smart" }
    }) end, opts)
    vim.keymap.set("n", "<leader>rn", function() vim.lsp.buf.rename() end, opts)
    vim.keymap.set("n", "<leader>k", function() vim.lsp.buf.signature_help() end, opts)
  end,
})

-- replace lsp.setup() with:
vim.lsp.enable({ 'jdtls', 'eslint' })

vim.diagnostic.config({
    virtual_text = true
})
