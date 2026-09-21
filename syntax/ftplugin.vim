" PLUM filetype settings -- install as ~/.vim/ftplugin/plum.vim

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=;\ %s
setlocal comments=:;

" PLUM blocks are runs of `| `, three columns per level.
setlocal expandtab
setlocal shiftwidth=1
setlocal tabstop=4
setlocal softtabstop=1

" `\_` closes a block; don't let it be treated as a word boundary oddity
setlocal iskeyword+=_

let b:undo_ftplugin = "setlocal commentstring< comments< expandtab< "
      \ . "shiftwidth< tabstop< softtabstop< iskeyword<"
