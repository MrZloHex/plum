; main.pl -- the PLUM counterpart of src/main.c
;
; The driver: read, preprocess, parse, collect metadata, emit.
; This is plc, written in PLUM.

!USES <preproc.pl>
!USES <parser.pl>
!USES <meta.pl>
!USES <check.pl>
!USES <codegen.pl>
!USES <../extern/unistd.pl>

ABYSS usage: [ @C1 progname ]
 | (printf)[ "Usage: %s [--emit=<AST|IR>] [-o output] file1 [file2 ...]\n" | progname ]
 | (printf)[ "  --emit=<AST|IR>   Specify the output type to emit (AST or IR)\n" ]
 | (printf)[ "  -o output        Specify the output filename\n" ]
 | (printf)[ "  file1 ...        One or more source files to compile\n" ]
 | RET
 \_

; Basename without directory or extension; names the LLVM module.
@C1 module_name_of: [ @C1 path ]
 | @C1 slash = (strrchr)[ path | 47 ]
 | @C1 base = path
 | IF [ slash != 0 ]
 |  | base = slash + 1
 |  \_
 |
 | @C1 buf = (malloc)[ 256 ] AS @C1
 | (snprintf)[ buf | 256 | "%s" | base ]
 | @C1 dot = (strrchr)[ buf | 46 ]
 | IF [ dot != 0 ]
 |  | ?(dot) = '\0'
 |  \_
 | RET [ buf ]
 \_

I32 main: [ I32 argc | @@C1 argv ]
 | @C1 out_file = 0
 | @C1 emit     = 0
 | @C1 source   = 0
 |
 | I32 i = 1
 | WHILE [ i < argc ]
 |  | @C1 a = ?(argv + i)
 |  |
 |  | IF [ (strncmp)[ a | "--emit=" | 7 ] == 0 ]
 |  |  | emit = a + 7
 |  | ELIF [ (strcmp)[ a | "-o" ] == 0 ]
 |  |  | i += 1
 |  |  | IF [ i >= argc ]
 |  |  |  | (printf)[ "Error: -o needs an argument.\n" ]
 |  |  |  | RET [ 1 ]
 |  |  |  \_
 |  |  | out_file = ?(argv + i)
 |  | ELIF [ (strcmp)[ a | "-h" ] == 0 || (strcmp)[ a | "--help" ] == 0 ]
 |  |  | (usage)[ ?(argv) ]
 |  |  | RET [ 0 ]
 |  | ELIF [ source == 0 ]
 |  |  | source = a
 |  | ELSE
 |  |  | (printf)[ "Warning: only `%s' is compiled; further input ignored.\n" | source ]
 |  |  \_
 |  |
 |  | i += 1
 |  \_
 |
 | IF [ source == 0 ]
 |  | (printf)[ "Error: No input files provided.\n" ]
 |  | (usage)[ ?(argv) ]
 |  | RET [ 1 ]
 |  \_
 |
 | ; IR is the default; the AST dump is a debugging aid
 | B1 emit_ir = TRUE
 | IF [ emit != 0 ]
 |  | IF [ (strcmp)[ emit | "AST" ] == 0 ]
 |  |  | emit_ir = FALSE
 |  |  \_
 |  \_
 |
 | @C1 full = (realpath)[ source | 0 ]
 | IF [ full == 0 ]
 |  | (printf)[ "Failed to resolve source file: %s\n" | source ]
 |  | RET [ 1 ]
 |  \_
 |
 | @ABYSS f = (fopen)[ full | "r" ]
 | IF [ f == 0 ]
 |  | (printf)[ "Failed to open source file: %s\n" | full ]
 |  | RET [ 1 ]
 |  \_
 |
 | String src
 | (str_init_file)[ @src | f ]
 | (fclose)[ f ]
 |
 | IF [ (preprocess)[ @src | full ] != 0 ]
 |  | (printf)[ "Preprocessing failed: %s\n" | full ]
 |  | RET [ 1 ]
 |  \_
 |
 | AST ast
 | (ast_init)[ @ast ]
 | (parse_unit)[ @ast | @src ]
 |
 | Meta meta
 | (meta_init)[ @meta ]
 | (meta_pass)[ @meta | @ast ]
 |
 | Checker ck
 | (check_init)[ @ck | @meta ]
 | IF [ !(check_unit)[ @ck | ast.root ] ]
 |  | (check_deinit)[ @ck ]
 |  | RET [ 1 ]
 |  \_
 | (check_deinit)[ @ck ]
 |
 | IF [ emit_ir ]
 |  | CodegenContext cg
 |  | (codegen_init)[ @cg | (module_name_of)[ full ] | @meta ]
 |  | (codegen_generate)[ ast.root | @cg ]
 |  | @C1 dest = "/dev/stdout"
 |  | IF [ out_file != 0 ]
 |  |  | dest = out_file
 |  |  \_
 |  | (codegen_deinit)[ @cg | dest ]
 | ELSE
 |  | ; the AST dump lives in the C driver; here we report the shape
 |  | I32 n = 0
 |  | @ASTNode ts = ast.root.as.tu.tu_stmt
 |  | WHILE [ ts != 0 ]
 |  |  | n += 1
 |  |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  |  \_
 |  | (printf)[ "%d top-level statements\n" | n ]
 |  \_
 |
 | (meta_deinit)[ @meta ]
 | (ast_deinit)[ @ast ]
 | (str_deinit)[ @src ]
 | RET [ 0 ]
 \_
