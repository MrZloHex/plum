; lexer.pl -- the PLUM counterpart of src/lexer.c
;
; On-demand: lexer_next hands back one Token at a time, by value. PLUM is
; indentation-and-bar structured, so this is where that is decided --
; lex_count_indent counts runs of " | " onto Token.indent, and a trailing
; "\_" becomes TOK_END_BLOCK.

!USES <token.pl>
!USES <../lib/string.pl>
!USES <../extern/ctype.pl>
!USES <../extern/string.pl>
!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>

TYPE Lexer: STRUCT
 | @String src
 | U64     pos
 | I32     line
 | I32     col
 \_

ABYSS lexer_init: [ @Lexer lx | @String source ]
 | lx.src  = source
 | lx.pos  = 0
 | lx.line = 1
 | lx.col  = 1
 |
 | ; Pad with NULs so lookahead past the end is safe. The C version appends
 ; a run of them; str_append_str would stop at the first NUL, so write them.
 | (str_reserve)[ source | source.size + 16 ]
 | U64 i = 0
 | WHILE [ i < 16 ]
 |  | ?(source.data + source.size + i) = '\0'
 |  | i = i + 1
 |  \_
 | RET
 \_

C1 lex_peek: [ @Lexer lx ]
 | RET [ ?(lx.src.data + lx.pos) ]
 \_

C1 lex_look: [ @Lexer lx | U64 n ]
 | RET [ ?(lx.src.data + lx.pos + n) ]
 \_

C1 lex_nextc: [ @Lexer lx ]
 | C1 c = (lex_peek)[ lx ]
 | IF [ c != 0 ]
 |  | lx.pos = lx.pos + 1
 |  | lx.col = lx.col + 1
 |  \_
 | RET [ c ]
 \_

Token make_tok: [ I32 kind | @C1 lexeme | I32 line | I32 col | I32 indent ]
 | Token t
 | t.kind     = kind
 | t.lexeme   = lexeme
 | t.indent   = indent
 | t.loc.line = line
 | t.loc.col  = col
 | RET [ t ]
 \_

I32 lex_count_indent: [ @Lexer lx ]
 | I32 indent = 0
 |
 | WHILE [ (lex_peek)[ lx ] == ' ' && (lex_look)[ lx | 1 ] == '|' ]
 |  | C1 after = (lex_look)[ lx | 2 ]
 |  |
 |  | ; A bare `|` ending the line is a blank statement and still one level;
 |  | ; eat only two chars so the newline is left for lexer_next.
 |  | IF [ after == '\n' || after == '\r' || after == 0 ]
 |  |  | indent = indent + 1
 |  |  | lx.col = lx.col + 2
 |  |  | lx.pos = lx.pos + 2
 |  |  | BREAK
 |  |  \_
 |  |
 |  | IF [ after != ' ' && after != '\t' ]
 |  |  | BREAK
 |  |  \_
 |  |
 |  | indent = indent + 1
 |  | lx.col = lx.col + 3
 |  | lx.pos = lx.pos + 3
 |  \_
 |
 | RET [ indent ]
 \_

B1 lex_is_block_end: [ @Lexer lx ]
 | RET [ (lex_peek)[ lx ] == ' ' && (lex_look)[ lx | 1 ] == '\\' && (lex_look)[ lx | 2 ] == '_' ]
 \_

Token lex_string: [ @Lexer lx | C1 term | I32 kind ]
 | I32 line = lx.line
 | I32 col  = lx.col
 | U64 start = lx.pos
 |
 | (lex_nextc)[ lx ]
 |
 | WHILE [ (lex_peek)[ lx ] != 0 && (lex_peek)[ lx ] != term ]
 |  | IF [ (lex_peek)[ lx ] == '\\' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  \_
 |  | (lex_nextc)[ lx ]
 |  \_
 |
 | IF [ (lex_peek)[ lx ] != term ]
 |  | (printf)[ "UNTERMINATED SYMBOLIC LITERAL! At %d:%d\n" | lx.line | lx.col ]
 |  | (exit)[ 1 ]
 |  \_
 | (lex_nextc)[ lx ]
 |
 | U64 len = lx.pos - start
 | @C1 lex = (str_substr)[ lx.src | start | len ]
 | RET [ (make_tok)[ kind | lex | line | col | -1 ] ]
 \_

Token lex_number: [ @Lexer lx ]
 | I32 line = lx.line
 | I32 col  = lx.col
 | U64 start = lx.pos
 | B1  is_float = FALSE
 |
 | WHILE [ (isalnum)[ (lex_peek)[ lx ] AS I32 ] != 0 || (lex_peek)[ lx ] == '_' || (lex_peek)[ lx ] == '.' ]
 |  | IF [ (lex_peek)[ lx ] == '.' ]
 |  |  | is_float = TRUE
 |  |  \_
 |  | (lex_nextc)[ lx ]
 |  \_
 |
 | U64 len = lx.pos - start
 | @C1 lex = (str_substr)[ lx.src | start | len ]
 |
 | I32 kind = TOK_INTEGER
 | IF [ is_float ]
 |  | kind = TOK_FLOAT
 |  \_
 | RET [ (make_tok)[ kind | lex | line | col | -1 ] ]
 \_

; src/lexer.c keeps a kw_table array; this is the same list as a chain.
I32 lex_keyword_kind: [ @C1 s ]
 | IF [ (strcmp)[ s | "TYPE" ] == 0 ]
 |  | RET [ TOK_TYPE ]
 | ELIF [ (strcmp)[ s | "STRUCT" ] == 0 ]
 |  | RET [ TOK_STRUCTURE ]
 | ELIF [ (strcmp)[ s | "UNION" ] == 0 ]
 |  | RET [ TOK_UNION ]
 | ELIF [ (strcmp)[ s | "ENUM" ] == 0 ]
 |  | RET [ TOK_ENUMERATION ]
 | ELIF [ (strcmp)[ s | "IF" ] == 0 ]
 |  | RET [ TOK_IF ]
 | ELIF [ (strcmp)[ s | "ELIF" ] == 0 ]
 |  | RET [ TOK_ELIF ]
 | ELIF [ (strcmp)[ s | "ELSE" ] == 0 ]
 |  | RET [ TOK_ELSE ]
 | ELIF [ (strcmp)[ s | "LOOP" ] == 0 ]
 |  | RET [ TOK_LOOP ]
 | ELIF [ (strcmp)[ s | "WHILE" ] == 0 ]
 |  | RET [ TOK_WHILE ]
 | ELIF [ (strcmp)[ s | "BREAK" ] == 0 ]
 |  | RET [ TOK_BREAK ]
 | ELIF [ (strcmp)[ s | "CONTINUE" ] == 0 ]
 |  | RET [ TOK_CONTINUE ]
 | ELIF [ (strcmp)[ s | "RET" ] == 0 ]
 |  | RET [ TOK_RET ]
 | ELIF [ (strcmp)[ s | "SIZE" ] == 0 ]
 |  | RET [ TOK_SIZE ]
 | ELIF [ (strcmp)[ s | "AS" ] == 0 ]
 |  | RET [ TOK_AS ]
 | ELIF [ (strcmp)[ s | "TRUE" ] == 0 ]
 |  | RET [ TOK_TRUE ]
 | ELIF [ (strcmp)[ s | "FALSE" ] == 0 ]
 |  | RET [ TOK_FALSE ]
 | ELIF [ (strcmp)[ s | "IFACE" ] == 0 ]
 |  | RET [ TOK_IFACE ]
 | ELIF [ (strcmp)[ s | "CLASS" ] == 0 ]
 |  | RET [ TOK_CLASS ]
 | ELIF [ (strcmp)[ s | "IMPL" ] == 0 ]
 |  | RET [ TOK_IMPL ]
 | ELIF [ (strcmp)[ s | "NULL" ] == 0 ]
 |  | RET [ TOK_NULL ]
 | ELSE
 |  | RET [ -1 ]
 |  \_
 \_

Token lex_indent_or_keyword: [ @Lexer lx ]
 | I32 line = lx.line
 | I32 col  = lx.col
 | U64 start = lx.pos
 |
 | (lex_nextc)[ lx ]
 | WHILE [ (isalnum)[ (lex_peek)[ lx ] AS I32 ] != 0 || (lex_peek)[ lx ] == '_' ]
 |  | (lex_nextc)[ lx ]
 |  \_
 |
 | U64 len = lx.pos - start
 | @C1 lex = (str_substr)[ lx.src | start | len ]
 |
 | I32 kw = (lex_keyword_kind)[ lex ]
 | IF [ kw >= 0 ]
 |  | (free)[ lex AS @ABYSS ]
 |  | RET [ (make_tok)[ kw | 0 | line | col | -1 ] ]
 |  \_
 |
 | RET [ (make_tok)[ TOK_IDENTIFIER | lex | line | col | -1 ] ]
 \_

B1 is_op_start: [ C1 c ]
 | RET [ c == '+' || c == '-' || c == '*' || c == '/' || c == '%' || c == '<' || c == '>' || c == '=' || c == '!' || c == '&' || c == '^' || c == '~' ]
 \_

Token lexer_next: [ @Lexer lx ]
 | LOOP
 |  | C1 c = (lex_peek)[ lx ]
 |  |
 |  | IF [ c == 0 ]
 |  |  | RET [ (make_tok)[ TOK_EOF | 0 | lx.line | lx.col | -1 ] ]
 |  |  \_
 |  |
 |  | IF [ c == '\n' || c == '\r' ]
 |  |  | IF [ c == '\r' && (lex_look)[ lx | 1 ] == '\n' ]
 |  |  |  | (lex_nextc)[ lx ]
 |  |  |  \_
 |  |  | (lex_nextc)[ lx ]
 |  |  | lx.line = lx.line + 1
 |  |  | lx.col = 1
 |  |  |
 |  |  | I32 indent = (lex_count_indent)[ lx ]
 |  |  | IF [ (lex_is_block_end)[ lx ] ]
 |  |  |  | lx.col = lx.col + 3
 |  |  |  | lx.pos = lx.pos + 3
 |  |  |  | RET [ (make_tok)[ TOK_END_BLOCK | 0 | lx.line | 1 | indent ] ]
 |  |  |  \_
 |  |  | RET [ (make_tok)[ TOK_NEWLINE | 0 | lx.line | 1 | indent ] ]
 |  |  \_
 |  |
 |  | IF [ c == ' ' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  | CONTINUE
 |  |  \_
 |  |
 |  | IF [ c == '\t' ]
 |  |  | (printf)[ "TABS ARE RESTRICTED! Tab at %d:%d\n" | lx.line | lx.col ]
 |  |  | (exit)[ 33 ]
 |  |  \_
 |  |
 |  | IF [ c == ';' ]
 |  |  | WHILE [ (lex_peek)[ lx ] != 0 && (lex_peek)[ lx ] != '\n' && (lex_peek)[ lx ] != '\r' ]
 |  |  |  | (lex_nextc)[ lx ]
 |  |  |  \_
 |  |  | CONTINUE
 |  |  \_
 |  |
 |  | IF [ c == ':' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  | RET [ (make_tok)[ TOK_COLON | 0 | lx.line | lx.col - 1 | -1 ] ]
 |  |  \_
 |  | IF [ c == '[' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  | RET [ (make_tok)[ TOK_LBRACKET | 0 | lx.line | lx.col - 1 | -1 ] ]
 |  |  \_
 |  | IF [ c == ']' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  | RET [ (make_tok)[ TOK_RBRACKET | 0 | lx.line | lx.col - 1 | -1 ] ]
 |  |  \_
 |  | IF [ c == '(' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  | RET [ (make_tok)[ TOK_LPAREN | 0 | lx.line | lx.col - 1 | -1 ] ]
 |  |  \_
 |  | IF [ c == ')' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  | RET [ (make_tok)[ TOK_RPAREN | 0 | lx.line | lx.col - 1 | -1 ] ]
 |  |  \_
 |  | IF [ c == '{' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  | RET [ (make_tok)[ TOK_LBRACE | 0 | lx.line | lx.col - 1 | -1 ] ]
 |  |  \_
 |  | IF [ c == '}' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  | RET [ (make_tok)[ TOK_RBRACE | 0 | lx.line | lx.col - 1 | -1 ] ]
 |  |  \_
 |  |
 |  | IF [ c == '|' && (lex_look)[ lx | 1 ] == '|' ]
 |  |  | I32 line = lx.line
 |  |  | I32 col  = lx.col
 |  |  | lx.col = lx.col + 2
 |  |  | lx.pos = lx.pos + 2
 |  |  | RET [ (make_tok)[ TOK_OPERATOR | (str_substr)[ lx.src | lx.pos - 2 | 2 ] | line | col | -1 ] ]
 |  |  \_
 |  | IF [ c == '|' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  | RET [ (make_tok)[ TOK_VBAR | 0 | lx.line | lx.col - 1 | -1 ] ]
 |  |  \_
 |  | IF [ c == '&' && (lex_look)[ lx | 1 ] == '&' ]
 |  |  | I32 line = lx.line
 |  |  | I32 col  = lx.col
 |  |  | lx.col = lx.col + 2
 |  |  | lx.pos = lx.pos + 2
 |  |  | RET [ (make_tok)[ TOK_OPERATOR | (str_substr)[ lx.src | lx.pos - 2 | 2 ] | line | col | -1 ] ]
 |  |  \_
 |  |
 |  | IF [ c == '?' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  | RET [ (make_tok)[ TOK_QMARK | 0 | lx.line | lx.col - 1 | -1 ] ]
 |  |  \_
 |  | IF [ c == '@' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  | RET [ (make_tok)[ TOK_AT | 0 | lx.line | lx.col - 1 | -1 ] ]
 |  |  \_
 |  | IF [ c == '.' && (lex_look)[ lx | 1 ] == '.' && (lex_look)[ lx | 2 ] == '.' ]
 |  |  | lx.col = lx.col + 3
 |  |  | lx.pos = lx.pos + 3
 |  |  | RET [ (make_tok)[ TOK_ELLIPSIS | 0 | lx.line | lx.col - 3 | -1 ] ]
 |  |  \_
 |  | IF [ c == '.' ]
 |  |  | (lex_nextc)[ lx ]
 |  |  | RET [ (make_tok)[ TOK_DOT | 0 | lx.line | lx.col - 1 | -1 ] ]
 |  |  \_
 |  |
 |  | IF [ c == '"' ]
 |  |  | RET [ (lex_string)[ lx | '"' | TOK_STRING ] ]
 |  |  \_
 |  | IF [ c == '\'' ]
 |  |  | RET [ (lex_string)[ lx | '\'' | TOK_CHARACTER ] ]
 |  |  \_
 |  |
 |  | IF [ (isdigit)[ c AS I32 ] != 0 ]
 |  |  | RET [ (lex_number)[ lx ] ]
 |  |  \_
 |  |
 |  | IF [ (isalpha)[ c AS I32 ] != 0 || c == '_' ]
 |  |  | RET [ (lex_indent_or_keyword)[ lx ] ]
 |  |  \_
 |  |
 |  | IF [ (is_op_start)[ c ] ]
 |  |  | I32 line = lx.line
 |  |  | I32 col  = lx.col
 |  |  | U64 start = lx.pos
 |  |  |
 |  |  | (lex_nextc)[ lx ]
 |  |  | C1 n = (lex_peek)[ lx ]
 |  |  | IF [ n == '=' || n == '<' || n == '>' ]
 |  |  |  | (lex_nextc)[ lx ]
 |  |  |  \_
 |  |  |
 |  |  | U64 len = lx.pos - start
 |  |  | RET [ (make_tok)[ TOK_OPERATOR | (str_substr)[ lx.src | start | len ] | line | col | -1 ] ]
 |  |  \_
 |  |
 |  | (printf)[ "UNKNOWN CHARACTER ENCOUNTER!!! %d:%d:`%c`\n" | lx.line | lx.col | c ]
 |  | (exit)[ 1 ]
 |  \_
 \_
