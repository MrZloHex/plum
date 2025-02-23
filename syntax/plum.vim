" Vim syntax file
" Language: Plum

" Usage Instructions
" Put this file in .vim/syntax/plum.vim
" and add in your .vimrc file the next line:
" autocmd BufRead,BufNewFile *.pl set filetype=plum


if exists("b:current_syntax")
  finish
endif

" Language keywords
syntax keyword plumKeywords RET TYPE IFACE IMPL CLASS EXTENDS REQUIRE
syntax keyword plumConditionKeywords IF
syntax keyword plumLoopKeywords WHILE DO FOR LOOP
syntax keyword plumDirectiveKeywords USES DEF
syntax keyword plumTypeKeywords BOOL ABYSS C1 U8 U16 U32 U64 USIZE I8 I16 I32 I64 ISIZE F32 F64

" Values
syntax region plumImmediateValue start="#" end="\d\+"

" Comments
syntax keyword plumTodo contained TODO FIXME XXX NOTE
syntax region plumCommentLine start=";" end="$" contains=plumTodo

" Set highlights
highlight default link plumTypeKeywords Type
highlight default link plumKeywords Statement
highlight default link plumConditionKeywords Conditional
highlight default link plumLoopKeywords Repeat
highlight default link plumDirectiveKeywords Include
highlight default link plumImmediateValue Number
highlight default link plumCommentLine Comment
highlight default link plumTodo Todo


let b:current_syntax = "plum"
