-- Define JDTLS command
local home = os.getenv("HOME")
local workspace_path = home .. "~/adad_projects/upstream/"
local jdtls_path = home .. ":~/.local/share/nvim/lsp_servers/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository/plugins/org.eclipse.jdt.ls.core_1.40.0.202409141629.jar"
local launcher_path = jdtls_path .. "~/.local/share/nvim/lsp_servers/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository/plugins/org.eclipse.equinox.launcher_1.6.900.v20240613-2009.jar" 
local config_path = jdtls_path .. "~/.local/share/nvim/lsp_servers/eclipse.jdt.ls/org.eclipse.jdt.ls.product/target/repository/config_linux" 

vim.lsp.config('jdtls', {
  cmd = {
    'java', 
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=ALL',
    '-Xms1g',
    '-Xmx2G',
    '-jar', launcher_path,
    '-configuration', config_path,
    '-data', workspace_path .. vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')
  },
  root_markers = { '.git', 'pom.xml', 'build.gradle' },
  on_attach = function(client, bufnr)
    buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
  end,
})

vim.lsp.enable('jdtls')
