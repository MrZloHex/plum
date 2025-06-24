!USES <cstdio.pl>
!USES <cstdlib.pl>
!USES <cunistd.pl>


ABYSS usage: [ @C1 progname ]
 | (printf)[ "Usage: %s [--emit=<AST|IR>] [-o output] file1 [file2 ...]%c" | progname | '\n' ]
 | (printf)[ "%c--emit=<AST|IR>   Specify the output type to emit (AST or IR)%c" | '\t' | '\n' ]
 | (printf)[ "%c-o output        Specify the output filename%c" | '\t' | '\n' ]
 | (printf)[ "%cfile1 ...        One or more source files to compile%c" | '\t' | '\n' ]
 | RET []
 \_
 
 ABYSS parse_cli_opts: []
  | RET []
  \_

I32 main: [ I32 argc | @@C1 argv ]
 | @C1 cwd = (get_current_dir_name)[]
 | IF [ cwd != 0 ]
 |  | (printf)[ "Current working dir: %s%c" | cwd | '\n' ]
 |  \_
 |
 | @C1 opt_output_file
 | @C1 opt_emit_type
 | I32 file_start_index
;| (parse_cli_opts)[ argc | argv | <
 | 
 | 
 | @C1 progname = @argv
 | (usage)[ progname ]
 | 
 | (free)[cwd]
 |
 | RET [ 0 ]
 \_
