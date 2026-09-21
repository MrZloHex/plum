" PLUM filetype detection -- install as ~/.vim/ftdetect/plum.vim
"
" *.pl belongs to Perl as far as vim is concerned, so rather than take the
" extension outright we look for PLUM's own markers: a `\_` block close, a
" !USES directive, or a `|`-prefixed statement line.
"
" Put `let g:plum_claim_pl = 1` in your .vimrc to skip the sniffing and
" treat every *.pl as PLUM.

function! s:PlumSniff() abort
  if get(g:, 'plum_claim_pl', 0)
    set filetype=plum
    return
  endif

  let l:last = min([60, line('$')])
  for l:i in range(1, l:last)
    let l:line = getline(l:i)
    if l:line =~# '^\s*\\_\s*$'             " block terminator
      \ || l:line =~# '^\s*!USES\s*<'        " include directive
      \ || l:line =~# '^\s*|\s\|^\s*|$'      " statement line
      set filetype=plum
      return
    endif
  endfor
endfunction

autocmd BufRead,BufNewFile *.plum setfiletype plum
autocmd BufRead,BufNewFile *.pl   call s:PlumSniff()
