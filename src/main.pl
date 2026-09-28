; main.pl -- the PLUM counterpart of src/main.c
;
; The driver: read, preprocess, parse, collect metadata, emit.
; This is plc, written in PLUM. `--lsp` makes it a language server instead
; (lsp.pl), which runs plc again with --emit=INDEX for every analysis.

!USES <preproc.pl>
!USES <parser.pl>
!USES <generic.pl>
!USES <meta.pl>
!USES <check.pl>
!USES <index.pl>
!USES <dump.pl>
!USES <codegen.pl>
!USES <lsp.pl>
!USES <../extern/unistd.pl>

ABYSS usage: [ @C1 progname ]
 | (printf)[ "Usage: %s [--emit=<AST|IR|ASM|OBJ|INDEX>] [-O0..3] [--target=triple] [--cpu=name] [--data-sections] [--stdin] [-o output] file1 [file2 ...]\n" | progname ]
 | (printf)[ "       %s --lsp\n" | progname ]
 | (printf)[ "  --emit=<AST|IR|ASM|OBJ|INDEX>  What to write: LLVM IR (the default), assembly, an object file,\n" ]
 | (printf)[ "                   the syntax tree as parsed, or the index for --lsp\n" ]
 | (printf)[ "  -O0 .. -O3       Optimise, as clang does; -O0, the default, keeps every load and store\n" ]
 | (printf)[ "  --target=triple  Generate code for another machine, as thumbv6m-none-eabi\n" ]
 | (printf)[ "  --cpu=name       A particular CPU of that machine, as cortex-m0plus\n" ]
 | (printf)[ "  --data-sections  Put each global in a section of its own, .data.<name>\n" ]
 | (printf)[ "  --stdin          Read the file's text from stdin; its name still resolves USES\n" ]
 | (printf)[ "  --lsp            Serve the Language Server Protocol on stdin and stdout\n" ]
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

Location no_loc: []
 | Location l
 | l.file = NULL
 | l.line = 0
 | l.col = 0
 | RET [ l ]
 \_

I32 main: [ I32 argc | @@C1 argv ]
 | @C1 out_file = 0
 | @C1 emit     = 0
 | @C1 source   = 0
 | B1  stdin_src = FALSE
 |
 | I32 i = 1
 | WHILE [ i < argc ]
 |  | @C1 a = ?(argv + i)
 |  |
 |  | IF [ (strncmp)[ a | "--emit=" | 7 ] == 0 ]
 |  |  | emit = a + 7
 |  | ELIF [ (strncmp)[ a | "--target=" | 9 ] == 0 ]
 |  |  | cg_triple = a + 9
 |  | ELIF [ (strncmp)[ a | "--cpu=" | 6 ] == 0 ]
 |  |  | cg_cpu = a + 6
 |  | ELIF [ (strcmp)[ a | "--data-sections" ] == 0 ]
 |  |  | cg_data_sections = TRUE
 |  | ELIF [ (strncmp)[ a | "-O" | 2 ] == 0 ]
 |  |  | IF [ a{2} < '0' || a{2} > '3' || a{3} != '\0' ]
 |  |  |  | (diag_at2)[ (no_loc)[] | "`%s`: the optimisation levels are -O0, -O1, -O2 and -O3%s" | a | "" ]
 |  |  |  | RET [ 1 ]
 |  |  |  \_
 |  |  | cg_opt = (a{2} AS I32) - 48
 |  | ELIF [ (strcmp)[ a | "--lsp" ] == 0 ]
 |  |  | RET [ (lsp_main)[] ]
 |  | ELIF [ (strcmp)[ a | "--stdin" ] == 0 ]
 |  |  | stdin_src = TRUE
 |  | ELIF [ (strcmp)[ a | "-o" ] == 0 ]
 |  |  | i += 1
 |  |  | IF [ i >= argc ]
 |  |  |  | (diag_plain)[ "-o needs a file name after it" ]
 |  |  |  | RET [ 1 ]
 |  |  |  \_
 |  |  | out_file = ?(argv + i)
 |  | ELIF [ (strcmp)[ a | "-h" ] == 0 || (strcmp)[ a | "--help" ] == 0 ]
 |  |  | (usage)[ ?(argv) ]
 |  |  | RET [ 0 ]
 |  | ELIF [ source == 0 ]
 |  |  | source = a
 |  | ELSE
 |  |  | (dprintf)[ 2 | "warning: only `%s` is compiled; `%s` is ignored\n" | source | a ]
 |  |  \_
 |  |
 |  | i += 1
 |  \_
 |
 | IF [ source == 0 ]
 |  | (diag_plain)[ "no input file" ]
 |  | (usage)[ ?(argv) ]
 |  | RET [ 1 ]
 |  \_
 |
 | ; IR is the default; the AST dump is a debugging aid
 | B1 gen_code = TRUE
 | B1 emit_ast = FALSE
 | B1 emit_index = FALSE
 | IF [ emit != 0 ]
 |  | IF [ (strcmp)[ emit | "AST" ] == 0 ]
 |  |  | gen_code = FALSE
 |  |  | emit_ast = TRUE
 |  | ELIF [ (strcmp)[ emit | "INDEX" ] == 0 ]
 |  |  | gen_code = FALSE
 |  |  | emit_index = TRUE
 |  |  | diag_machine = TRUE
 |  | ELIF [ (strcmp)[ emit | "ASM" ] == 0 ]
 |  |  | cg_emit = CG_ASM
 |  | ELIF [ (strcmp)[ emit | "OBJ" ] == 0 ]
 |  |  | cg_emit = CG_OBJ
 |  | ELIF [ (strcmp)[ emit | "IR" ] != 0 ]
 |  |  | (diag_at2)[ (no_loc)[] | "--emit takes AST, IR, ASM, OBJ or INDEX, not `%s`%s" | emit | "" ]
 |  |  | RET [ 1 ]
 |  |  \_
 |  \_
 |
 | ; from stdin, the file is an editor's buffer and need not be saved yet
 | @C1 full = (realpath)[ source | 0 ]
 | IF [ full == 0 && stdin_src ]
 |  | full = source
 |  \_
 | IF [ full == 0 ]
 |  | (diag_at2)[ (no_loc)[] | "cannot find `%s`%s" | source | "" ]
 |  | RET [ 1 ]
 |  \_
 |
 | String src
 | IF [ stdin_src ]
 |  | (src.init_fd)[ 0 ]
 | ELSE
 |  | @ABYSS f = (fopen)[ full | "r" ]
 |  | IF [ f == 0 ]
 |  |  | (diag_at2)[ (no_loc)[] | "cannot open `%s`%s" | source | "" ]
 |  |  | RET [ 1 ]
 |  |  \_
 |  | (src.init_file)[ f ]
 |  | (fclose)[ f ]
 |  \_
 |
 | ; the preprocessor has said what went wrong
 | IF [ (preprocess_named)[ @src | full | source ] != 0 ]
 |  | RET [ 1 ]
 |  \_
 |
 | AST ast
 | (ast_init)[ @ast ]
 | (parse_file)[ @ast | @src | source ]
 |
 | ; the tree as the parser left it: before generics, and before any check
 | IF [ emit_ast ]
 |  | (dump_ast)[ ast.root ]
 |  | RET [ 0 ]
 |  \_
 |
 | Map contracts
 | (map_init)[ @contracts | 64 ]
 | (generics_pass)[ @ast | @contracts ]
 |
 | Meta meta
 | (meta_init)[ @meta ]
 | (meta_pass)[ @meta | @ast ]
 |
 | Checker ck
 | (check_init)[ @ck | @meta ]
 | ck.contracts = @contracts
 |
 | ; the index is wanted most when there are errors: keep going past them
 | IF [ emit_index ]
 |  | Index ix
 |  | (ix.refs.init)[ 1024 ]
 |  | ck.ix = @ix
 |  | B1 clean = (check_unit)[ @ck | ast.root ]
 |  | (ix_walk)[ @ix | @meta | ast.root ]
 |  | (ix_dump)[ @ix | ast.root ]
 |  | (check_deinit)[ @ck ]
 |  | IF [ !clean ]
 |  |  | RET [ 1 ]
 |  |  \_
 |  | RET [ 0 ]
 |  \_
 |
 | IF [ !(check_unit)[ @ck | ast.root ] ]
 |  | (check_deinit)[ @ck ]
 |  | RET [ 1 ]
 |  \_
 | (check_deinit)[ @ck ]
 |
 | IF [ gen_code ]
 |  | CodegenContext cg
 |  | (codegen_init)[ @cg | (module_name_of)[ full ] | @meta ]
 |  | (codegen_generate)[ ast.root | @cg ]
 |  | @C1 dest = "/dev/stdout"
 |  | IF [ out_file != 0 ]
 |  |  | dest = out_file
 |  |  \_
 |  | IF [ !(codegen_deinit)[ @cg | dest ] ]
 |  |  | RET [ 1 ]
 |  |  \_
 |  \_
 |
 | (meta_deinit)[ @meta ]
 | (ast_deinit)[ @ast ]
 | (src.deinit)[]
 | RET [ 0 ]
 \_
