local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>pf', builtin.find_files, {})
vim.keymap.set('n', '<leader>pg', builtin.git_files, {})
vim.keymap.set('n', '<leader>ps', function()
    builtin.grep_string({ search = vim.fn.input("Grep > ") });
end)
require('telescope').setup {
    defaults = {
        path_display = {"smart"}, 
        layout_strategy = 'vertical',
        layout_config = {
            vertical = {
                mirror = false,
                preview_height = 0.5,
                width = 0.9
            },
        },
        winblend = 10,
    },
}
