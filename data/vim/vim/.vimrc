" line numbers
set relativenumber
set number

"Insert new lines
nnoremap o o<ESC>
nnoremap O O<ESC>

"scrolling
nnoremap <C-u> <C-u>zz
nnoremap <C-d> <C-d>zz

"Move 1 more lines up or down in normal and visual modes
nnoremap <C-Up> :m .-2<CR>==zz
nnoremap <C-Down> :m .+1<CR>==zz
vnoremap <C-Up> :m '<-2<CR>gv=gvzz
vnoremap <C-Down> :m '>+1<CR>gv=gvzz

"fzf plugin
call plug#begin('~/.vim/plugged')
Plug 'junegunn/fzf', {'do': { -> fzf#install()}}
Plug 'junegunn/fzf.vim'
call plug#end()

