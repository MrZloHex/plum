; preproc.pl -- the PLUM counterpart of src/preproc.c
;
; Textual pass over the whole source: expands the USES directive in place,
; resolving each path against the including file's directory. Runs before
; the lexer ever sees the text, and is deliberately not comment-aware -- a
; commented-out directive really does still include, as in the C version.
; (Which is why this comment spells none of it out literally.)

!USES <../lib/string.pl>
!USES <../extern/string.pl>
!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>

I32 MAX_INCLUDE_DEPTH = 32

; Directory part of a path, or "." -- caller owns the result.
@C1 dir_of: [ @C1 path ]
 | IF [ path == 0 ]
 |  | RET [ (strdup)[ "." ] ]
 |  \_
 |
 | @C1 slash = (strrchr)[ path | 47 ]
 | IF [ slash == 0 ]
 |  | RET [ (strdup)[ "." ] ]
 |  \_
 |
 | U64 n = (slash AS U64) - (path AS U64)
 | @C1 d = (malloc)[ n + 1 ] AS @C1
 | IF [ d == 0 ]
 |  | RET [ 0 ]
 |  \_
 | (memcpy)[ d AS @ABYSS | path AS @ABYSS | n ]
 | ?(d + n) = '\0'
 | RET [ d ]
 \_

I32 preproc_internal: [ @String src | I32 depth | @C1 dir ]

I32 insert_file: [ @String dst | U64 at | @C1 path | I32 depth | @C1 dir ]
 | IF [ depth > MAX_INCLUDE_DEPTH ]
 |  | (printf)[ "preproc: include depth exceeded (%s)\n" | path ]
 |  | RET [ -1 ]
 |  \_
 |
 | @C1 full = 0
 | IF [ ?(path) == '/' ]
 |  | full = (strdup)[ path ]
 | ELSE
 |  | U64 n = (strlen)[ dir ] + 1 + (strlen)[ path ] + 1
 |  | full = (malloc)[ n ] AS @C1
 |  | IF [ full != 0 ]
 |  |  | (snprintf)[ full | n | "%s/%s" | dir | path ]
 |  |  \_
 |  \_
 | IF [ full == 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | @ABYSS f = (fopen)[ full | "r" ]
 | IF [ f == 0 ]
 |  | (printf)[ "preproc: cannot open \"%s\"\n" | full ]
 |  | (free)[ full AS @ABYSS ]
 |  | RET [ -1 ]
 |  \_
 |
 | String buf
 | (str_init_file)[ @buf | f ]
 | (fclose)[ f ]
 |
 | @C1 sub_dir = (dir_of)[ full ]
 | (free)[ full AS @ABYSS ]
 | IF [ sub_dir == 0 ]
 |  | (str_deinit)[ @buf ]
 |  | RET [ -1 ]
 |  \_
 |
 | I32 rc = (preproc_internal)[ @buf | depth + 1 | sub_dir ]
 | (free)[ sub_dir AS @ABYSS ]
 |
 | IF [ rc != 0 ]
 |  | (str_deinit)[ @buf ]
 |  | RET [ -1 ]
 |  \_
 |
 | (str_insert_str)[ dst | at | buf.data ]
 | (str_deinit)[ @buf ]
 | RET [ 0 ]
 \_

I32 preproc_uses: [ @String s | U64 pos | I32 depth | @C1 dir ]
 | U64 i = pos + 5
 |
 | WHILE [ i < s.size && (?(s.data + i) == ' ' || ?(s.data + i) == '\t') ]
 |  | i = i + 1
 |  \_
 |
 | IF [ i >= s.size ]
 |  | (printf)[ "preproc: expected '<' after !USES\n" ]
 |  | RET [ -1 ]
 |  \_
 | IF [ ?(s.data + i) != '<' ]
 |  | (printf)[ "preproc: expected '<' after !USES\n" ]
 |  | RET [ -1 ]
 |  \_
 | i = i + 1
 |
 | U64 name_begin = i
 | WHILE [ i < s.size && ?(s.data + i) != '>' ]
 |  | i = i + 1
 |  \_
 |
 | IF [ i >= s.size ]
 |  | (printf)[ "preproc: missing '>' for !USES\n" ]
 |  | RET [ -1 ]
 |  \_
 |
 | U64 name_len = i - name_begin
 | @C1 fname = (strndup)[ s.data + name_begin | name_len ]
 | IF [ fname == 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | U64 directive_len = (i + 1) - pos
 | (str_remove_range)[ s | pos | directive_len ]
 |
 | IF [ (insert_file)[ s | pos | fname | depth | dir ] != 0 ]
 |  | (free)[ fname AS @ABYSS ]
 |  | RET [ -1 ]
 |  \_
 |
 | (free)[ fname AS @ABYSS ]
 | RET [ 0 ]
 \_

I32 preproc_internal: [ @String src | I32 depth | @C1 dir ]
 | U64 i = 0
 | WHILE [ i < src.size ]
 |  | C1 c = ?(src.data + i)
 |  |
 |  | ; Comments and literals are skipped, so a directive only counts when
 |  | ; it is really code -- which is what lets this very file name it.
 |  | IF [ c == ';' ]
 |  |  | WHILE [ i < src.size && ?(src.data + i) != '\n' ]
 |  |  |  | i = i + 1
 |  |  |  \_
 |  | ELIF [ c == '"' || c == '\'' ]
 |  |  | C1 quote = c
 |  |  | i = i + 1
 |  |  | WHILE [ i < src.size && ?(src.data + i) != quote ]
 |  |  |  | IF [ ?(src.data + i) == '\\' ]
 |  |  |  |  | i = i + 1
 |  |  |  |  \_
 |  |  |  | i = i + 1
 |  |  |  \_
 |  |  | i = i + 1
 |  | ELSE
 |  |  | B1 hit = FALSE
 |  |  | IF [ c == '!' && i + 5 < src.size ]
 |  |  |  | IF [ (strncmp)[ src.data + i | "!USES" | 5 ] == 0 ]
 |  |  |  |  | hit = TRUE
 |  |  |  |  \_
 |  |  |  \_
 |  |  |
 |  |  | IF [ hit ]
 |  |  |  | IF [ (preproc_uses)[ src | i | depth | dir ] != 0 ]
 |  |  |  |  | RET [ -1 ]
 |  |  |  |  \_
 |  |  |  | i = 0
 |  |  | ELSE
 |  |  |  | i = i + 1
 |  |  |  \_
 |  |  \_
 |  \_
 | RET [ 0 ]
 \_

I32 preprocess: [ @String src | @C1 path ]
 | IF [ src == 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | @C1 dir = (dir_of)[ path ]
 | IF [ dir == 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | I32 rc = (preproc_internal)[ src | 0 | dir ]
 | (free)[ dir AS @ABYSS ]
 | RET [ rc ]
 \_
