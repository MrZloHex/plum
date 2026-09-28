; Exercises plum/meta.pl -- symbol collection over a parsed unit.

!USES <../../src/parser.pl>
!USES <../../src/meta.pl>

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
 | AST ast
 | (ast_init)[ @ast ]
 | (parse_unit)[ @ast | @src ]
 |
 | Meta m
 | (meta_init)[ @m ]
 | (meta_pass)[ @m | @ast ]
 |
 | (printf)[ "func_decls=%d types=%d str_lits=%d\n" | (map_size)[ @(m.func_decls) ] | (map_size)[ @(m.types) ] | (map_size)[ @(m.str_lits) ] ]
 |
 | @ABYSS out = 0
 | (printf)[ "lookup add   hit=%d\n" | (map_get)[ @(m.func_decls) | "add" | @out AS @@ABYSS ] ]
 | (printf)[ "lookup main  hit=%d\n" | (map_get)[ @(m.func_decls) | "main" | @out AS @@ABYSS ] ]
 | (printf)[ "lookup Node  hit=%d\n" | (map_get)[ @(m.types) | "Node" | @out AS @@ABYSS ] ]
 | (printf)[ "lookup nope  hit=%d\n" | (map_get)[ @(m.func_decls) | "nope" | @out AS @@ABYSS ] ]
 |
 | ; string literals live inside IF/ELIF/ELSE blocks, which src/meta.c
 | ; never walks -- this is the fix paying off
 | (printf)[ "lookup \"one\\n\"  hit=%d\n" | (map_get)[ @(m.str_lits) | "\"one\\n\"" | @out AS @@ABYSS ] ]
 |
 | (meta_deinit)[ @m ]
 | (ast_deinit)[ @ast ]
 | RET [ 0 ]
 \_
