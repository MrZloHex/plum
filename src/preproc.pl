; preproc.pl -- the PLUM counterpart of src/preproc.c
;
; Textual pass over the whole source: expands the USES directive in place,
; resolving each path against the including file's directory. Runs before
; the lexer ever sees the text. Comments and string literals are skipped.
;
; Each file is included once: a directive naming a file already pulled in
; -- by any path that resolves to the same file -- expands to nothing.
; PLUM declarations do not depend on order, so the first copy serves all.

!USES <../lib/string.pl>
!USES <diag.pl>
!USES <../extern/string.pl>
!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>
!USES <../extern/unistd.pl>

I32 MAX_INCLUDE_DEPTH = 32

; How a file is named in diagnostics: relative to the working directory
; when it is under it, as the user would type it; absolute otherwise.
@C1 pp_display: [ @C1 path ]
 | @C1 canon = (realpath)[ path | NULL ]
 | IF [ canon == NULL ]
 |  | RET [ (strdup)[ path ] ]
 |  \_
 | @C1 cwd = (getcwd)[ NULL | 0 ]
 | IF [ cwd == NULL ]
 |  | RET [ canon ]
 |  \_
 | U64 n = (strlen)[ cwd ]
 | IF [ (strncmp)[ canon | cwd | n ] == 0 && canon{n} == '/' ]
 |  | @C1 rel = (strdup)[ canon + n + 1 ]
 |  | (free)[ canon AS @ABYSS ]
 |  | (free)[ cwd AS @ABYSS ]
 |  | RET [ rel ]
 |  \_
 | (free)[ cwd AS @ABYSS ]
 | RET [ canon ]
 \_

; Where offset `pos` of the text lies in the file it came from. Included
; files already pasted in are skipped over by their markers.
Location pp_where: [ @String s | U64 pos | @C1 name ]
 | Location l
 | l.file = name
 | l.line = 1
 | l.col = 1
 | I32 depth = 0
 | U64 i = 0
 | WHILE [ i < pos && i < s.size ]
 |  | I32 b = s.data{i} AS I32
 |  | IF [ b == 1 ]
 |  |  | depth += 1
 |  |  \_
 |  | IF [ b == 2 ]
 |  |  | depth -= 1
 |  |  \_
 |  | IF [ depth == 0 && b != 2 ]
 |  |  | IF [ b == 10 ]
 |  |  |  | l.line += 1
 |  |  |  | l.col = 1
 |  |  | ELSE
 |  |  |  | l.col += 1
 |  |  |  \_
 |  |  \_
 |  | i += 1
 |  \_
 | RET [ l ]
 \_

; canonical paths of every file included so far
@@C1 pp_seen
U64  pp_nseen
U64  pp_cap

; TRUE the first time `path` is seen, FALSE ever after. A path that does
; not resolve is left for fopen to report.
B1 pp_first_visit: [ @C1 path ]
 | @C1 canon = (realpath)[ path | 0 ]
 | IF [ canon == 0 ]
 |  | RET [ TRUE ]
 |  \_
 |
 | U64 i = 0
 | WHILE [ i < pp_nseen ]
 |  | IF [ (strcmp)[ ?(pp_seen + i) | canon ] == 0 ]
 |  |  | (free)[ canon AS @ABYSS ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | i = i + 1
 |  \_
 |
 | IF [ pp_nseen == pp_cap ]
 |  | pp_cap = pp_cap * 2 + 16
 |  | pp_seen = (realloc)[ pp_seen AS @ABYSS | pp_cap * 8 ] AS @@C1
 |  \_
 | ?(pp_seen + pp_nseen) = canon
 | pp_nseen = pp_nseen + 1
 | RET [ TRUE ]
 \_

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

I32 preproc_internal: [ @String src | I32 depth | @C1 dir | @C1 name ]

; `at` is where the directive was, for diagnostics.
; Bytes 1 and 2 mark where an included file begins and ends; one in a
; file itself would throw every location after it. 0, or -1 once said.
I32 pp_no_markers: [ @String s | @C1 name ]
 | Location l
 | l.file = name
 | l.line = 1
 | l.col = 1
 | U64 i = 0
 | WHILE [ i < s.size ]
 |  | C1 b = s.data{i}
 |  | IF [ b == '\x01' || b == '\x02' ]
 |  |  | C1 code{8}
 |  |  | (snprintf)[ code | 8 | "\\x%02x" | b AS I32 ]
 |  |  | (diag_at2)[ l | "a control character, `%s`, is not part of PLUM%s" | code | "" ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | IF [ b == '\n' ]
 |  |  | l.line += 1
 |  |  | l.col = 1
 |  | ELSE
 |  |  | l.col += 1
 |  |  \_
 |  | i += 1
 |  \_
 | RET [ 0 ]
 \_

I32 insert_file: [ @String dst | U64 at | @C1 path | I32 depth | @C1 dir | Location where ]
 | IF [ depth > MAX_INCLUDE_DEPTH ]
 |  | (diag_at2)[ where | "USES nested more than %s deep, including `%s`; do files include each other?" | "32" | path ]
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
 | IF [ !(pp_first_visit)[ full ] ]
 |  | (free)[ full AS @ABYSS ]
 |  | RET [ 0 ]
 |  \_
 |
 | @ABYSS f = (fopen)[ full | "r" ]
 | IF [ f == 0 ]
 |  | (diag_at2)[ where | "cannot open `%s` (looked for %s)" | path | full ]
 |  | (free)[ full AS @ABYSS ]
 |  | RET [ -1 ]
 |  \_
 | @C1 shown = (pp_display)[ full ]
 |
 | String buf
 | (buf.init_file)[ f ]
 | (fclose)[ f ]
 | IF [ (pp_no_markers)[ @buf | shown ] != 0 ]
 |  | (free)[ full AS @ABYSS ]
 |  | (buf.deinit)[]
 |  | RET [ -1 ]
 |  \_
 |
 | @C1 sub_dir = (dir_of)[ full ]
 | (free)[ full AS @ABYSS ]
 | IF [ sub_dir == 0 ]
 |  | (buf.deinit)[]
 |  | RET [ -1 ]
 |  \_
 |
 | I32 rc = (preproc_internal)[ @buf | depth + 1 | sub_dir | shown ]
 | (free)[ sub_dir AS @ABYSS ]
 |
 | IF [ rc != 0 ]
 |  | (buf.deinit)[]
 |  | RET [ -1 ]
 |  \_
 |
 | ; bracket it for the lexer: byte 1, the name, a newline ... byte 2
 | String wrapped
 | (wrapped.init)[ buf.size + (strlen)[ shown ] + 8 ]
 | (wrapped.push)[ 1 AS C1 ]
 | (wrapped.append)[ shown ]
 | (wrapped.push)[ '\n' ]
 | (wrapped.append)[ buf.data ]
 | (wrapped.push)[ '\n' ]
 | (wrapped.push)[ 2 AS C1 ]
 | (dst.insert)[ at | wrapped.data ]
 | (wrapped.deinit)[]
 | (buf.deinit)[]
 | RET [ 0 ]
 \_

I32 preproc_uses: [ @String s | U64 pos | I32 depth | @C1 dir | @C1 name ]
 | Location where = (pp_where)[ s | pos | name ]
 | U64 i = pos + 5
 |
 | WHILE [ i < s.size && (?(s.data + i) == ' ' || ?(s.data + i) == '\t') ]
 |  | i = i + 1
 |  \_
 |
 | IF [ i >= s.size || ?(s.data + i) != '<' ]
 |  | (diag_at)[ where | "USES takes a file in angle brackets, as in !USES <io.pl>" ]
 |  | RET [ -1 ]
 |  \_
 | i = i + 1
 |
 | ; the name ends at `>`, and never runs onto the next line
 | U64 name_begin = i
 | WHILE [ i < s.size && ?(s.data + i) != '>' && ?(s.data + i) != '\n' ]
 |  | i = i + 1
 |  \_
 |
 | IF [ i >= s.size || ?(s.data + i) != '>' ]
 |  | (diag_at)[ where | "this USES is never closed with `>`" ]
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
 | (s.remove)[ pos | directive_len ]
 |
 | IF [ (insert_file)[ s | pos | fname | depth | dir | where ] != 0 ]
 |  | (free)[ fname AS @ABYSS ]
 |  | RET [ -1 ]
 |  \_
 |
 | (free)[ fname AS @ABYSS ]
 | RET [ 0 ]
 \_

I32 preproc_internal: [ @String src | I32 depth | @C1 dir | @C1 name ]
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
 |  |  |  | IF [ (preproc_uses)[ src | i | depth | dir | name ] != 0 ]
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

I32 preprocess_named: [ @String src | @C1 path | @C1 name ]

I32 preprocess: [ @String src | @C1 path ]
 | RET [ (preprocess_named)[ src | path | (pp_display)[ path ] ] ]
 \_

; `name` is how diagnostics call the root file.
I32 preprocess_named: [ @String src | @C1 path | @C1 name ]
 | IF [ src == 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | @C1 dir = (dir_of)[ path ]
 | IF [ dir == 0 ]
 |  | RET [ -1 ]
 |  \_
 |
 | IF [ (pp_no_markers)[ src | name ] != 0 ]
 |  | (free)[ dir AS @ABYSS ]
 |  | RET [ -1 ]
 |  \_
 |
 | ; a fresh run: the root file counts as included, so it cannot pull
 | ; itself in again
 | pp_nseen = 0
 | (pp_first_visit)[ path ]
 |
 | I32 rc = (preproc_internal)[ src | 0 | dir | name ]
 | (free)[ dir AS @ABYSS ]
 | RET [ rc ]
 \_
