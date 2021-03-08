call plug#begin()

" Utilities
Plug 'scrooloose/nerdtree'                " File explorer
Plug 'Xuyuanp/nerdtree-git-plugin'        " NERDTree git file status
Plug 'scrooloose/nerdcommenter'           " Commenting utilities
Plug 'airblade/vim-gitgutter'             " Git gutter
Plug 'haya14busa/incsearch.vim'           " Improved search
Plug 'haya14busa/incsearch-fuzzy.vim'     " Fuzzy searching
Plug 'tpope/vim-obsession'                " Session saving

" Display
Plug 'ryanoasis/vim-devicons'             " Icon set for utilities
Plug 'vim-airline/vim-airline'            " Status bar
Plug 'kshenoy/vim-signature'              " Gutter marks
Plug 'jeffkreeftmeijer/vim-numbertoggle'  " Line number toggling utility

" Syntax
Plug 'jiangmiao/auto-pairs'               " Auto punctuation pairs
Plug 'tpope/vim-surround'                 " Keymaps surrounding pairs
Plug 'pangloss/vim-javascript'            " Javascript syntax highlighting
Plug 'vim-syntastic/syntastic'            " Syntax checking

" Colors
Plug 'arcticicestudio/nord-vim'
Plug 'morhetz/gruvbox'
Plug 'vim-airline/vim-airline-themes'
Plug 'trusktr/seti.vim'

call plug#end()

" Display settings
set rnu                                   " Relative line numbers on startup
set hls                                   " Search highlight
set cursorline                            " Highlight current line
set ruler                                 " Row and column counters
set expandtab                             " Spaces instead of tabs
set showcmd                               " Show commands being used
set winminheight=0                        " Show no lines of collapsed win
set so=999

" Behaviour settings
set updatetime=250                        " Time delay for gui updates
set splitbelow                            " Cursor moves down on hsp
set splitright                            " Cursor moves right on vsp
set mouse=a                               " Mouse scrolls viewport instead of lines

" Color settings
let $NVIM_TUI_ENABLE_TRUE_COLOR=1
set background=dark
colorscheme nord
hi Normal guibg=NONE ctermbg=NONE         " Set transparent background
hi CursorLine cterm=NONE guibg=#391414    " Highlight line colors
hi OverLength cterm=NONE guibg=#802b2b guifg=#eeeeee " Overlength colors
match OverLength /\%81v.\+/               " Highlight chars past column 80

" Formatting settings
set shiftwidth=2                          " Indent shift (<</>>)
set softtabstop=2                         " Indent shift (tab/<bs>)

" NERDTree settings
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | on | endif
autocmd BufEnter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
nnoremap <silent> † :NERDTreeToggle<cr>
let NERDTreeShowHidden = 1                " Show hidden files

" NERDCommenter settings
let g:NERDSpaceDelims = 1
let g:NERDCommentEmptyLines = 1
let g:NERDTrimTrailingWhitespace = 1

" Airline settings
let g:airline_left_sep = ''
let g:airline_right_sep = ''
let g:airline_mode_map = {
    \ '__' : '-',
    \ 'n'  : 'N',
    \ 'i'  : 'I',
    \ 'R'  : 'R',
    \ 'c'  : 'C',
    \ 'v'  : 'V',
    \ 'V'  : 'V',
    \ '' : 'V',
    \ 's'  : 'S',
    \ 'S'  : 'S',
    \ '' : 'S',
    \ }
let g:airline_theme = 'nord'

" Signature settings
let g:SignatureMarkTextHLDynamic = 1

" Gitgutter settings
set signcolumn=yes

" Incsearch.vim settings
map / <Plug>(incsearch-forward)
map ? <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)
set hlsearch
let g:incsearch#auto_nohlsearch = 1
map n <Plug>(incsearch-nohl-n)
map N <Plug>(incsearch-nohl-N)
map * <Plug>(incsearch-nohl-*)
map # <Plug>(incsearch-nohl-#)
map z/ <Plug>(incsearch-fuzzy-/)
map z? <Plug>(incsearch-fuzzy-?)
map zg/ <Plug>(incsearch-fuzzy-g/)

" Syntastic settings
set statusline+=%#warningmsg#
set statusline+=%{exists('g:loaded_syntastic_plugin')?SyntasticStatuslineFlag():''}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

let g:syntastic_error_symbol = "✗"
let g:syntastic_warning_symbol = "⚠"

let g:syntastic_javascript_checkers = ['eslint']

" Use <C-n> toggle for numbering
let g:UseNumberToggleTrigger = 1

" Set leader key
let mapleader = ","

" Window control
autocmd BufWinEnter,WinEnter * res
"" Switch window
nnoremap <C-h> <C-w>h 
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

"" ??
nnoremap <Leader><C-j> <C-w>J<C-w>_
nnoremap <Leader><C-k> <C-w>K<C-w>_
nnoremap <C-_> <C-w>_
"" Split window
nnoremap <C-s><C-s> <C-w>s
nmap <C-s><C-k> <C-w>s<C-k>
nmap <C-s><C-d> <C-s><C-s><Leader><Leader>
nnoremap <C-v><C-v> <C-w>v
nmap <C-v><C-h> <C-w>v<C-h>
nmap <C-v><C-d> <C-v><C-v><Leader><Leader>

" Move view pane
nnoremap ∆ <C-e>
nnoremap ˚ <C-y>
nnoremap ≥ z.

" Disable arrow keys in insert mode
inoremap <up> <nop>
inoremap <down> <nop>
inoremap <left> <nop>
inoremap <right> <nop>

" Writing and quitting keymaps
nnoremap <Leader>qq :q<cr>
nnoremap <Leader>QQ :q!<cr>
nnoremap <Leader>qa :qa<cr>
nnoremap <Leader>QA :qa!<cr>
nnoremap <Leader>ww :w<cr>
nnoremap <Leader>wq :wq<cr>

" Avoid escape
inoremap <esc> <nop>

" Niceties
inoremap <C-o> <C-c>o
nnoremap <Leader>o o<Esc>
nnoremap <Leader>O O<Esc>
nnoremap <Leader>e :e 
nnoremap <Leader>E :e %:p:h/
nnoremap <Leader>. :so $MYVIMRC<cr>

" Terminal
autocmd BufWinEnter,WinEnter term://* startinsert | setlocal nornu nocursorline noruler signcolumn=no
nmap <Leader><Leader> :e term://zsh<cr>
tmap <Leader>s <C-\><C-n>
tmap <Leader><Leader> <Leader>s:enew<cr><C-c>
tmap <Leader>qa <C-\><C-n><Leader>qa
tmap <Leader>qq <C-\><C-n><Leader>qq
tmap <Leader>. <C-\><C-n><Leader>.
tmap <Leader>e <C-\><C-n><Leader>e
tmap <Leader>E <C-\><C-n><Leader>E
tmap <C-h> <C-\><C-n><C-h>
tmap <C-j> <C-\><C-n><C-j>
tmap <C-k> <C-\><C-n><C-k>
tmap <C-l> <C-\><C-n><C-l>
tmap <C-s><C-s> <Leader>s<C-s><C-s><Leader><Leader>
tmap <C-s><C-k> <Leader>s<C-s><C-k><Leader><Leader>
tmap <C-s><C-d> <Leader>s<C-s><C-s><Leader><Leader><Leader><Leader>
tmap <C-v><C-v> <Leader>s<C-v><C-v><Leader><Leader>
tmap <C-v><C-h> <Leader>s<C-v><C-h><Leader><Leader>
tmap <C-v><C-d> <Leader>s<C-v><C-v><Leader><Leader><Leader><Leader>

" Swap 0^
noremap 0 ^
noremap ^ 0
