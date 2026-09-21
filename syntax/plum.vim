" Vim syntax file
" Language:    PLUM
" Maintainer:  MrZloHex
" Reference:   syntax/plum.ebnf, src/lexer.c (kw_table), src/parser.c
"
" Install with syntax/install.sh, or copy to ~/.vim/syntax/plum.vim
"
" Ordering matters: in vim the LAST matching item wins, so comments and the
" !USES directive are defined at the bottom -- otherwise plumUserType and
" plumOperator claim words and angle brackets inside them.

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" --- Keywords ------------------------------------------------------------
syntax keyword plumStatement   RET BREAK CONTINUE
syntax keyword plumConditional IF ELIF ELSE
syntax keyword plumRepeat      LOOP WHILE
syntax keyword plumStructure   STRUCT UNION ENUM
" The name after TYPE is a type, not a function, so claim it via nextgroup.
syntax keyword plumStructure   TYPE nextgroup=plumTypeName skipwhite
syntax match   plumTypeName    contained "\w\+"
syntax keyword plumOperatorKw  SIZE AS
syntax keyword plumBoolean     TRUE FALSE

" --- Types ---------------------------------------------------------------
syntax keyword plumType ABYSS B1 C1 C2 C4
syntax keyword plumType U8 U16 U32 U64 USIZE
syntax keyword plumType I8 I16 I32 I64 ISIZE
syntax keyword plumType F32 F64

" Any other Capitalised identifier is a user type: TYPE Node, @Node, Tok.
syntax match plumUserType "\<\u\w*\>"

" --- Literals ------------------------------------------------------------
syntax match  plumNumber  "\<\d\+\>"
syntax match  plumFloat   "\<\d\+\.\d\+\>"
syntax match  plumEscape  contained "\\[nrt0\\'\"]"
syntax region plumString  start=+"+ skip=+\\.+ end=+"+ contains=plumEscape,@Spell
syntax region plumChar    start=+'+ skip=+\\.+ end=+'+ contains=plumEscape

" --- Operators -----------------------------------------------------------
" The leading `|` run is block structure, not an operator, so it is matched
" separately below and this deliberately skips it.
syntax match plumOperator "&&\|<<\|>>\|[-+*/%^~&]"
syntax match plumOperator "[-+*/%]="
syntax match plumOperator "[=!<>]=\|[<>]\|="
syntax match plumOperator "?\|\.\.\.\|\."
" Bitwise-or. plumBar is defined later and so wins for a leading bar run.
syntax match plumOperator "|"
syntax match plumPointer  "@"
syntax match plumDelimiter "[][()]"

" --- Declarations and calls ----------------------------------------------
" `I32 main: [ ... ]` -- the name before the colon.
syntax match plumFunction "\<\w\+\ze\s*:"
" `(printf)[ ... ]` -- PLUM's call form.
syntax match plumCall "(\@<=\w\+\ze)\s*\["

" --- Block structure -----------------------------------------------------
" Nesting is a run of `| `, closed by `\_`. Matched after the operators so
" the structural bars win over bitwise-or, and requires a real `|` so it
" cannot match empty at the start of an ordinary line.
syntax match plumBar      "^\s*|\%(\s\+|\)*"
syntax match plumBlockEnd "\\_"

" --- Comments and directives (last: they must beat everything above) -----
syntax match  plumInclude  "^\s*!USES\s*<[^>]*>" contains=plumIncPath
syntax match  plumIncPath  contained "<[^>]*>"
syntax keyword plumTodo    contained TODO FIXME XXX NOTE HACK
syntax match  plumComment  ";.*$" contains=plumTodo,@Spell

" --- Highlight links -----------------------------------------------------
highlight default link plumComment     Comment
highlight default link plumTodo        Todo
highlight default link plumInclude     PreProc
highlight default link plumIncPath     String
highlight default link plumStatement   Statement
highlight default link plumConditional Conditional
highlight default link plumRepeat      Repeat
highlight default link plumStructure   Structure
highlight default link plumOperatorKw  Operator
highlight default link plumBoolean     Boolean
highlight default link plumType        Type
highlight default link plumUserType    Type
highlight default link plumTypeName    Type
highlight default link plumString      String
highlight default link plumChar        Character
highlight default link plumEscape      SpecialChar
highlight default link plumNumber      Number
highlight default link plumFloat       Float
highlight default link plumBlockEnd    Special
highlight default link plumBar         Delimiter
highlight default link plumFunction    Function
highlight default link plumCall        Function
highlight default link plumOperator    Operator
highlight default link plumPointer     StorageClass
highlight default link plumDelimiter   Delimiter

let b:current_syntax = "plum"

let &cpo = s:cpo_save
unlet s:cpo_save
