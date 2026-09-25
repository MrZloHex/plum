" PLUM filetype detection -- install as ~/.vim/ftdetect/plum.vim
"
" *.pl belongs to Perl as far as vim is concerned, so rather than take the
" extension outright we look for PLUM's own shapes. A declaration-only file
" (everything under plum/extern/) has no blocks and no directives, so the
" declaration header itself has to be one of the markers.
"
" Put `let g:plum_claim_pl = 1` in your .vimrc to skip the sniffing and
" treat every *.pl as PLUM.

function! s:PlumSniff() abort
  if get(g:, 'plum_claim_pl', 0)
    set filetype=plum
    return
  endif

  let l:types = 'ABYSS\|B1\|C[124]\|[IU]\%(8\|16\|32\|64\|SIZE\)\|F\%(32\|64\)'

  let l:last = min([80, line('$')])
  for l:i in range(1, l:last)
    let l:line = getline(l:i)

    " a block terminator, or a statement line
    if l:line =~# '^\s*\\_\s*$' || l:line =~# '^\s*|\s' || l:line =~# '^\s*|$'
      set filetype=plum | return
    endif

    " the include directive
    if l:line =~# '^\s*!USES\s*<'
      set filetype=plum | return
    endif

    " a type definition:  TYPE Name: STRUCT|UNION|ENUM
    if l:line =~# '^\s*TYPE\s\+\w\+\s*:'
      set filetype=plum | return
    endif

    " a function declaration or definition header, which is what a
    " declaration-only file consists of entirely:
    "     @ABYSS memcpy: [ ... ]        I32 main: [ ]
    if l:line =~# '^\s*@*\w\+\s\+\w\+\s*:\s*\['
      set filetype=plum | return
    endif

    " a top-level variable of a PLUM base type:  I32 counter = 0
    if l:line =~# '^\s*@*\%(' . l:types . '\)\s\+\w\+\s*\%(=\|$\)'
      set filetype=plum | return
    endif
  endfor
endfunction

autocmd BufRead,BufNewFile *.plum setfiletype plum
autocmd BufRead,BufNewFile *.pl   call s:PlumSniff()
