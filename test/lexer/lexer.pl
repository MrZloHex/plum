; Exercises plum/lexer.pl -- token kinds, lexemes, indent counting.

!USES <../../src/lexer.pl>

I32 main: []
 | String src
 | @ABYSS f = (fopen)[ "sample.txt" | "r" ]
 | IF [ f == 0 ]
 |  | (puts)[ "cannot open sample.txt" ]
 |  | RET [ 1 ]
 |  \_
 | (src.init_file)[ f ]
 | (fclose)[ f ]
 |
 | Lexer lx
 | (lexer_init)[ @lx | @src ]
 |
 | I32 n = 0
 | LOOP
 |  | Token t = (lexer_next)[ @lx ]
 |  | IF [ t.kind == TOK_EOF ]
 |  |  | BREAK
 |  |  \_
 |  |
 |  | IF [ t.lexeme != 0 ]
 |  |  | (printf)[ "%2d:%-2d %-11s `%s`\n" | t.loc.line | t.loc.col | (token_str)[ t.kind ] | t.lexeme ]
 |  | ELIF [ t.kind == TOK_NEWLINE || t.kind == TOK_END_BLOCK ]
 |  |  | (printf)[ "%2d:%-2d %-11s indent=%d\n" | t.loc.line | t.loc.col | (token_str)[ t.kind ] | t.indent ]
 |  | ELSE
 |  |  | (printf)[ "%2d:%-2d %s\n" | t.loc.line | t.loc.col | (token_str)[ t.kind ] ]
 |  |  \_
 |  | n += 1
 |  \_
 |
 | (printf)[ "-- %d tokens --\n" | n ]
 | RET [ 0 ]
 \_
