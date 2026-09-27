; lsp.pl -- `plc --lsp`: the Language Server Protocol, on stdin and stdout
;
; The server analyses nothing itself. For each open file it runs
;
;   plc --emit=INDEX --stdin <file>
;
; in a child, feeds it the editor's unsaved text, and keeps the lines that
; come back (index.pl): diagnostics, and every name with its declaration.
; A child because the parser ends the process at the first error; and it
; is cheap -- all of plc checks in well under a tenth of a second.
;
; Served: diagnostics, go to definition (and declaration), hover.
; While a file does not parse, the last index that did is kept, so going
; to a definition keeps working in the middle of an edit.

!USES <json.pl>
!USES <../lib/string.pl>
!USES <../lib/vector.pl>
!USES <../lib/map.pl>
!USES <../lib/arena.pl>
!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>
!USES <../extern/unistd.pl>

; A name used at file:line:col, declared at to_file:to_line:to_col; one
; R line. Files are interned, so they compare as pointers.
TYPE Fact: STRUCT
 | @C1 file
 | I32 line
 | I32 col
 | @C1 to_file
 | I32 to_line
 | I32 to_col
 | @C1 hover
 \_

; One E line. `file` is 0 for a problem with no place.
TYPE Problem: STRUCT
 | @C1 file
 | I32 line
 | I32 col
 | @C1 msg
 \_

TYPE Doc: STRUCT
 | @C1          uri       ; as the client spelled it
 | @C1          path      ; interned
 | String       text
 | Vector<Fact> facts
 \_

TYPE Lsp: STRUCT
 | Vector<@Doc> docs
 | Map          interned   ; canonical path -> itself
 | Map          canon      ; a path as plc printed it -> interned
 | Arena        arena      ; the JSON of the message being handled
 | B1           utf8       ; positions count bytes, not UTF-16 units
 | B1           shut       ; `shutdown` has come
 \_

; --- reading and writing messages ------------------------------------------

C1  lsp_in{65536}
I64 lsp_in_len
I64 lsp_in_pos

; The next byte of stdin, or -1 at its end.
I32 lsp_getc: []
 | IF [ lsp_in_pos >= lsp_in_len ]
 |  | lsp_in_len = (read)[ 0 | lsp_in AS @ABYSS | 65536 ]
 |  | lsp_in_pos = 0
 |  | IF [ lsp_in_len <= 0 ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  \_
 | C1 c = lsp_in{lsp_in_pos}
 | lsp_in_pos += 1
 | RET [ (c AS I32) & 255 ]
 \_

; The body of the next message, malloc'd, its length in `len`; 0 at the end.
@C1 lsp_read: [ @U64 len ]
 | I64 want = -1
 | C1 line{256}
 | LOOP
 |  | ; a header line, without its CR LF
 |  | I32 n = 0
 |  | LOOP
 |  |  | I32 c = (lsp_getc)[]
 |  |  | IF [ c < 0 ]
 |  |  |  | RET [ NULL ]
 |  |  |  \_
 |  |  | IF [ c == 10 ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  | IF [ c != 13 && n < 255 ]
 |  |  |  | line{n} = c AS C1
 |  |  |  | n += 1
 |  |  |  \_
 |  |  \_
 |  | line{n} = '\0'
 |  |
 |  | IF [ n == 0 ]
 |  |  | IF [ want >= 0 ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  | CONTINUE
 |  |  \_
 |  | IF [ (strncmp)[ line | "Content-Length:" | 15 ] == 0 ]
 |  |  | want = (strtoll)[ line + 15 | NULL | 10 ]
 |  |  \_
 |  \_
 |
 | @C1 body = (malloc)[ (want AS U64) + 1 ] AS @C1
 | I64 i = 0
 | WHILE [ i < want ]
 |  | I32 c = (lsp_getc)[]
 |  | IF [ c < 0 ]
 |  |  | (free)[ body AS @ABYSS ]
 |  |  | RET [ NULL ]
 |  |  \_
 |  | body{i} = c AS C1
 |  | i += 1
 |  \_
 | body{want} = '\0'
 | ?(len) = want AS U64
 | RET [ body ]
 \_

ABYSS lsp_write_all: [ I32 fd | @C1 buf | U64 n ]
 | U64 done = 0
 | WHILE [ done < n ]
 |  | I64 w = (write)[ fd | (buf + done) AS @ABYSS | n - done ]
 |  | IF [ w <= 0 ]
 |  |  | RET
 |  |  \_
 |  | done += w AS U64
 |  \_
 \_

ABYSS lsp_send: [ @String body ]
 | C1 head{64}
 | (snprintf)[ head | 64 | "Content-Length: %lu\r\n\r\n" | body.size ]
 | (lsp_write_all)[ 1 | head | (strlen)[ head ] ]
 | (lsp_write_all)[ 1 | body.data | body.size ]
 \_

; `{"jsonrpc":"2.0","id":<id>,"result":` -- the caller appends the result
; and lsp_finish closes it.
ABYSS lsp_reply: [ @String o | @JNode id ]
 | (str_init_cap)[ o | 256 ]
 | (str_append_str)[ o | "{\"jsonrpc\":\"2.0\",\"id\":" ]
 | IF [ id == NULL ]
 |  | (str_append_str)[ o | "null" ]
 | ELSE
 |  | (jw_raw)[ o | id.raw | id.raw_len ]
 |  \_
 | (str_append_str)[ o | ",\"result\":" ]
 \_

ABYSS lsp_finish: [ @String o ]
 | (str_append)[ o | '}' ]
 | (lsp_send)[ o ]
 | (str_deinit)[ o ]
 \_

ABYSS lsp_reply_null: [ @JNode id ]
 | String o
 | (lsp_reply)[ @o | id ]
 | (str_append_str)[ @o | "null" ]
 | (lsp_finish)[ @o ]
 \_

ABYSS lsp_reply_error: [ @JNode id | I32 code | @C1 msg ]
 | String o
 | (str_init_cap)[ @o | 256 ]
 | (str_append_str)[ @o | "{\"jsonrpc\":\"2.0\",\"id\":" ]
 | IF [ id == NULL ]
 |  | (str_append_str)[ @o | "null" ]
 | ELSE
 |  | (jw_raw)[ @o | id.raw | id.raw_len ]
 |  \_
 | (str_append_str)[ @o | ",\"error\":{\"code\":" ]
 | (jw_int)[ @o | code ]
 | (str_append_str)[ @o | ",\"message\":" ]
 | (jw_str)[ @o | msg ]
 | (str_append)[ @o | '}' ]
 | (lsp_finish)[ @o ]
 \_

; --- paths and URIs ---------------------------------------------------------

I32 hex_val: [ C1 h ]
 | IF [ h >= '0' && h <= '9' ]
 |  | RET [ (h AS I32) - 48 ]
 |  \_
 | IF [ h >= 'a' && h <= 'f' ]
 |  | RET [ (h AS I32) - 87 ]
 |  \_
 | IF [ h >= 'A' && h <= 'F' ]
 |  | RET [ (h AS I32) - 55 ]
 |  \_
 | RET [ -1 ]
 \_

; file:///a%20b/c.pl -> /a b/c.pl, malloc'd. Also file:/a/c.pl, which is
; how YouCompleteMe spells it, and file://host/a/c.pl.
@C1 uri_to_path: [ @C1 uri ]
 | @C1 s = uri
 | IF [ (strncmp)[ s | "file:" | 5 ] == 0 ]
 |  | s = s + 5
 |  | IF [ (strncmp)[ s | "//" | 2 ] == 0 ]
 |  |  | s = s + 2
 |  |  | WHILE [ ?s != '\0' && ?s != '/' ]
 |  |  |  | s = s + 1
 |  |  |  \_
 |  |  \_
 |  \_
 | @C1 out = (malloc)[ (strlen)[ s ] + 1 ] AS @C1
 | U64 n = 0
 | WHILE [ ?s != '\0' ]
 |  | IF [ ?s == '%' && (hex_val)[ s{1} ] >= 0 && (hex_val)[ s{2} ] >= 0 ]
 |  |  | out{n} = ((hex_val)[ s{1} ] * 16 + (hex_val)[ s{2} ]) AS C1
 |  |  | s = s + 3
 |  | ELSE
 |  |  | out{n} = ?s
 |  |  | s = s + 1
 |  |  \_
 |  | n += 1
 |  \_
 | out{n} = '\0'
 | RET [ out ]
 \_

ABYSS jw_uri: [ @String o | @C1 path ]
 | (str_append_str)[ o | "\"file://" ]
 | U64 i = 0
 | WHILE [ path{i} != '\0' ]
 |  | C1 c = path{i}
 |  | B1 plain = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
 |  | IF [ plain || c == '/' || c == '-' || c == '.' || c == '_' || c == '~' ]
 |  |  | (str_append)[ o | c ]
 |  | ELSE
 |  |  | C1 buf{4}
 |  |  | (snprintf)[ buf | 4 | "%%%02X" | (c AS I32) & 255 ]
 |  |  | (str_append_str)[ o | buf ]
 |  |  \_
 |  | i += 1
 |  \_
 | (str_append)[ o | '"' ]
 \_

; One pointer per file, however it was named.
@C1 lsp_intern: [ @Lsp ls | @C1 path ]
 | @C1 real = (realpath)[ path | NULL ]
 | IF [ real == NULL ]
 |  | real = (strdup)[ path ]
 |  \_
 | @ABYSS have = NULL
 | IF [ (map_get)[ @(ls.interned) | real | @have ] == 1 ]
 |  | (free)[ real AS @ABYSS ]
 |  | RET [ have AS @C1 ]
 |  \_
 | (map_put)[ @(ls.interned) | real | real AS @ABYSS ]
 | RET [ real ]
 \_

; A file as plc printed it -- relative to the working directory, which the
; child shares -- as the interned path.
@C1 lsp_canon: [ @Lsp ls | @C1 name ]
 | @ABYSS have = NULL
 | IF [ (map_get)[ @(ls.canon) | name | @have ] == 1 ]
 |  | RET [ have AS @C1 ]
 |  \_
 | @C1 real = (lsp_intern)[ ls | name ]
 | (map_put)[ @(ls.canon) | (strdup)[ name ] | real AS @ABYSS ]
 | RET [ real ]
 \_

; --- documents -------------------------------------------------------------

@Doc lsp_doc: [ @Lsp ls | @C1 uri ]
 | IF [ uri == NULL ]
 |  | RET [ NULL ]
 |  \_
 | U64 i = 0
 | WHILE [ i < (ls.docs.size)[] ]
 |  | @Doc d = ?((ls.docs.at)[ i ])
 |  | IF [ (strcmp)[ d.uri | uri ] == 0 ]
 |  |  | RET [ d ]
 |  |  \_
 |  | i += 1
 |  \_
 | RET [ NULL ]
 \_

ABYSS lsp_drop_facts: [ @Vector<Fact> v ]
 | U64 i = 0
 | WHILE [ i < (v.size)[] ]
 |  | (free)[ (v.at)[ i ].hover AS @ABYSS ]
 |  | i += 1
 |  \_
 | (v.clear)[]
 \_

; Where line `line` (from 0) starts in the text, or the text's end.
U64 doc_line_start: [ @Doc d | I32 line ]
 | U64 i = 0
 | I32 l = 0
 | WHILE [ l < line && i < d.text.size ]
 |  | IF [ d.text.data{i} == '\n' ]
 |  |  | l += 1
 |  |  \_
 |  | i += 1
 |  \_
 | RET [ i ]
 \_

B1 lsp_is_ident: [ C1 c ]
 | RET [ (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' ]
 \_

; A column the client sent, as a byte offset into the line; the client
; counts UTF-16 units unless it agreed to UTF-8.
I32 doc_to_byte: [ @Lsp ls | @Doc d | I32 line | I32 ch ]
 | IF [ ls.utf8 ]
 |  | RET [ ch ]
 |  \_
 | U64 at = (doc_line_start)[ d | line ]
 | U64 i = at
 | I32 units = 0
 | WHILE [ units < ch && i < d.text.size && d.text.data{i} != '\n' ]
 |  | I32 b = (d.text.data{i} AS I32) & 255
 |  | IF [ b < 128 ]
 |  |  | i += 1
 |  |  | units += 1
 |  | ELIF [ b < 224 ]
 |  |  | i += 2
 |  |  | units += 1
 |  | ELIF [ b < 240 ]
 |  |  | i += 3
 |  |  | units += 1
 |  | ELSE
 |  |  | i += 4
 |  |  | units += 2
 |  |  \_
 |  \_
 | RET [ (i - at) AS I32 ]
 \_

; A byte offset into a line of this document as the client counts it.
I32 doc_from_byte: [ @Lsp ls | @Doc d | I32 line | I32 col ]
 | IF [ ls.utf8 ]
 |  | RET [ col ]
 |  \_
 | U64 at = (doc_line_start)[ d | line ]
 | U64 i = at
 | I32 units = 0
 | WHILE [ i < at + (col AS U64) && i < d.text.size && d.text.data{i} != '\n' ]
 |  | I32 b = (d.text.data{i} AS I32) & 255
 |  | IF [ b < 128 ]
 |  |  | i += 1
 |  | ELIF [ b < 224 ]
 |  |  | i += 2
 |  | ELIF [ b < 240 ]
 |  |  | i += 3
 |  | ELSE
 |  |  | ; beyond the BMP: a surrogate pair, two units
 |  |  | i += 4
 |  |  | units += 1
 |  |  \_
 |  | units += 1
 |  \_
 | RET [ units ]
 \_

; The identifier at or just before byte `col` of `line`: its first byte,
; or -1. Its length goes in `len`.
I32 doc_word: [ @Doc d | I32 line | I32 col | @I32 len ]
 | U64 at = (doc_line_start)[ d | line ]
 | U64 end = at
 | WHILE [ end < d.text.size && d.text.data{end} != '\n' ]
 |  | end += 1
 |  \_
 | U64 p = at + (col AS U64)
 | IF [ p > end ]
 |  | RET [ -1 ]
 |  \_
 | IF [ p == end || !(lsp_is_ident)[ d.text.data{p} ] ]
 |  | IF [ p == at || !(lsp_is_ident)[ d.text.data{p - 1} ] ]
 |  |  | RET [ -1 ]
 |  |  \_
 |  | p -= 1
 |  \_
 | WHILE [ p > at && (lsp_is_ident)[ d.text.data{p - 1} ] ]
 |  | p -= 1
 |  \_
 | U64 q = p
 | WHILE [ q < end && (lsp_is_ident)[ d.text.data{q} ] ]
 |  | q += 1
 |  \_
 | ?(len) = (q - p) AS I32
 | RET [ (p - at) AS I32 ]
 \_

; The fact for the name under the cursor, or 0; its first column and
; length, in bytes, go in `col` and `len`.
@Fact lsp_fact_at: [ @Lsp ls | @Doc d | @JNode pos | @I32 col | @I32 len ]
 | I32 line = (json_int)[ (json_get)[ pos | "line" ] | 0 ] AS I32
 | I32 ch = (json_int)[ (json_get)[ pos | "character" ] | 0 ] AS I32
 | I32 w = (doc_word)[ d | line | (doc_to_byte)[ ls | d | line | ch ] | len ]
 | IF [ w < 0 ]
 |  | RET [ NULL ]
 |  \_
 | ?(col) = w
 | U64 i = 0
 | WHILE [ i < (d.facts.size)[] ]
 |  | @Fact f = (d.facts.at)[ i ]
 |  | IF [ f.file == d.path && f.line == line + 1 && f.col == w + 1 ]
 |  |  | RET [ f ]
 |  |  \_
 |  | i += 1
 |  \_
 | RET [ NULL ]
 \_

; --- analysis ----------------------------------------------------------------

; plc --emit=INDEX on the document's text; what it printed goes in `out`.
ABYSS lsp_run_index: [ @Doc d | @String out ]
 | I32 inp{2}
 | I32 outp{2}
 | IF [ (pipe)[ inp ] != 0 || (pipe)[ outp ] != 0 ]
 |  | (str_init_cstr)[ out | "" ]
 |  | RET
 |  \_
 |
 | I32 pid = (fork)[]
 | IF [ pid == 0 ]
 |  | (dup2)[ inp{0} | 0 ]
 |  | (dup2)[ outp{1} | 1 ]
 |  | (close)[ inp{0} ]
 |  | (close)[ inp{1} ]
 |  | (close)[ outp{0} ]
 |  | (close)[ outp{1} ]
 |  | @C1 argv{5}
 |  | argv{0} = "plc"
 |  | argv{1} = "--emit=INDEX"
 |  | argv{2} = "--stdin"
 |  | argv{3} = d.path
 |  | argv{4} = NULL
 |  | (execv)[ "/proc/self/exe" | argv ]
 |  | (_exit)[ 127 ]
 |  \_
 |
 | (close)[ inp{0} ]
 | (close)[ outp{1} ]
 | IF [ pid > 0 ]
 |  | ; the child reads all of stdin before it writes a byte: no deadlock
 |  | (lsp_write_all)[ inp{1} | d.text.data | d.text.size ]
 |  \_
 | (close)[ inp{1} ]
 | (str_init_fd)[ out | outp{0} ]
 | (close)[ outp{0} ]
 | IF [ pid > 0 ]
 |  | I32 status = 0
 |  | (waitpid)[ pid | @status | 0 ]
 |  \_
 \_

; Split one line of plc's output at its tabs, in place; how many fields.
I32 lsp_fields: [ @C1 line | @@C1 f | I32 max ]
 | I32 n = 1
 | f{0} = line
 | @C1 p = line
 | WHILE [ ?p != '\0' && n < max ]
 |  | IF [ ?p == '\t' ]
 |  |  | ?p = '\0'
 |  |  | f{n} = p + 1
 |  |  | n += 1
 |  |  \_
 |  | p = p + 1
 |  \_
 | RET [ n ]
 \_

ABYSS jw_range: [ @String o | I32 line | I32 from | I32 to ]
 | (str_append_str)[ o | "{\"start\":{\"line\":" ]
 | (jw_int)[ o | line ]
 | (str_append_str)[ o | ",\"character\":" ]
 | (jw_int)[ o | from ]
 | (str_append_str)[ o | "},\"end\":{\"line\":" ]
 | (jw_int)[ o | line ]
 | (str_append_str)[ o | ",\"character\":" ]
 | (jw_int)[ o | to ]
 | (str_append_str)[ o | "}}" ]
 \_

; Problems in this document sit under the word they point at; those in a
; file it includes, and those with no place at all, go on its first line.
ABYSS lsp_publish: [ @Lsp ls | @Doc d | @Vector<Problem> probs ]
 | String o
 | (str_init_cap)[ @o | 512 ]
 | (str_append_str)[ @o | "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":" ]
 | (jw_str)[ @o | d.uri ]
 | (str_append_str)[ @o | ",\"diagnostics\":[" ]
 |
 | U64 i = 0
 | WHILE [ i < (probs.size)[] ]
 |  | @Problem p = (probs.at)[ i ]
 |  | IF [ i > 0 ]
 |  |  | (str_append)[ @o | ',' ]
 |  |  \_
 |  | (str_append_str)[ @o | "{\"range\":" ]
 |  | IF [ p.file == d.path ]
 |  |  | I32 line = p.line - 1
 |  |  | I32 len = 1
 |  |  | I32 w = (doc_word)[ d | line | p.col - 1 | @len ]
 |  |  | IF [ w != p.col - 1 ]
 |  |  |  | len = 1
 |  |  |  \_
 |  |  | I32 from = (doc_from_byte)[ ls | d | line | p.col - 1 ]
 |  |  | I32 to = (doc_from_byte)[ ls | d | line | p.col - 1 + len ]
 |  |  | (jw_range)[ @o | line | from | to ]
 |  |  | (str_append_str)[ @o | ",\"message\":" ]
 |  |  | (jw_str)[ @o | p.msg ]
 |  | ELSE
 |  |  | (jw_range)[ @o | 0 | 0 | 0 ]
 |  |  | String m
 |  |  | (str_init_cap)[ @m | 256 ]
 |  |  | IF [ p.file != NULL ]
 |  |  |  | C1 at{32}
 |  |  |  | (str_append_str)[ @m | p.file ]
 |  |  |  | (snprintf)[ at | 32 | ":%d:%d: " | p.line | p.col ]
 |  |  |  | (str_append_str)[ @m | at ]
 |  |  |  \_
 |  |  | (str_append_str)[ @m | p.msg ]
 |  |  | (str_append_str)[ @o | ",\"message\":" ]
 |  |  | (jw_str)[ @o | m.data ]
 |  |  | (str_deinit)[ @m ]
 |  |  \_
 |  | (str_append_str)[ @o | ",\"severity\":1,\"source\":\"plc\"}" ]
 |  | i += 1
 |  \_
 |
 | (str_append_str)[ @o | "]}}" ]
 | (lsp_send)[ @o ]
 | (str_deinit)[ @o ]
 \_

ABYSS lsp_analyse: [ @Lsp ls | @Doc d ]
 | String out
 | (lsp_run_index)[ d | @out ]
 |
 | Vector<Fact> facts
 | (facts.init)[ 1024 ]
 | Vector<Problem> probs
 | (probs.init)[ 8 ]
 |
 | @C1 f{8}
 | @C1 line = out.data
 | WHILE [ line != NULL && ?line != '\0' ]
 |  | @C1 nl = line
 |  | WHILE [ ?nl != '\0' && ?nl != '\n' ]
 |  |  | nl = nl + 1
 |  |  \_
 |  | @C1 next = NULL
 |  | IF [ ?nl == '\n' ]
 |  |  | ?nl = '\0'
 |  |  | next = nl + 1
 |  |  \_
 |  |
 |  | I32 n = (lsp_fields)[ line | f | 8 ]
 |  | IF [ n == 8 && (strcmp)[ f{0} | "R" ] == 0 ]
 |  |  | Fact x
 |  |  | x.file = (lsp_canon)[ ls | f{1} ]
 |  |  | x.line = (atoi)[ f{2} ]
 |  |  | x.col = (atoi)[ f{3} ]
 |  |  | x.to_file = (lsp_canon)[ ls | f{4} ]
 |  |  | x.to_line = (atoi)[ f{5} ]
 |  |  | x.to_col = (atoi)[ f{6} ]
 |  |  | x.hover = (strdup)[ f{7} ]
 |  |  | (facts.push)[ x ]
 |  | ELIF [ n == 5 && (strcmp)[ f{0} | "E" ] == 0 ]
 |  |  | Problem p
 |  |  | p.file = NULL
 |  |  | IF [ ?(f{1}) != '\0' ]
 |  |  |  | p.file = (lsp_canon)[ ls | f{1} ]
 |  |  |  \_
 |  |  | p.line = (atoi)[ f{2} ]
 |  |  | p.col = (atoi)[ f{3} ]
 |  |  | p.msg = f{4}
 |  |  | (probs.push)[ p ]
 |  |  \_
 |  | line = next
 |  \_
 |
 | ; a file that stops parsing yields no facts: keep the last ones
 | IF [ (facts.size)[] > 0 || (probs.size)[] == 0 ]
 |  | (lsp_drop_facts)[ @(d.facts) ]
 |  | (d.facts.deinit)[]
 |  | d.facts = facts
 | ELSE
 |  | (facts.deinit)[]
 |  \_
 |
 | (lsp_publish)[ ls | d | @probs ]
 | (probs.deinit)[]
 | (str_deinit)[ @out ]
 \_

; --- requests ----------------------------------------------------------------

ABYSS lsp_initialize: [ @Lsp ls | @JNode id | @JNode params ]
 | @JNode encs = (json_get)[ (json_get)[ (json_get)[ params | "capabilities" ] | "general" ] | "positionEncodings" ]
 | IF [ encs != NULL && encs.kind == J_ARR ]
 |  | @JNode e = encs.child
 |  | WHILE [ e != NULL ]
 |  |  | @C1 s = (json_str)[ e ]
 |  |  | IF [ s != NULL && (strcmp)[ s | "utf-8" ] == 0 ]
 |  |  |  | ls.utf8 = TRUE
 |  |  |  \_
 |  |  | e = e.next
 |  |  \_
 |  \_
 |
 | String o
 | (lsp_reply)[ @o | id ]
 | (str_append_str)[ @o | "{\"capabilities\":{" ]
 | IF [ ls.utf8 ]
 |  | (str_append_str)[ @o | "\"positionEncoding\":\"utf-8\"," ]
 |  \_
 | (str_append_str)[ @o | "\"textDocumentSync\":{\"openClose\":true,\"change\":1,\"save\":{\"includeText\":false}}," ]
 | (str_append_str)[ @o | "\"definitionProvider\":true,\"declarationProvider\":true,\"hoverProvider\":true}," ]
 | (str_append_str)[ @o | "\"serverInfo\":{\"name\":\"plc\"}}" ]
 | (lsp_finish)[ @o ]
 \_

ABYSS lsp_open: [ @Lsp ls | @JNode params ]
 | @JNode td = (json_get)[ params | "textDocument" ]
 | @C1 uri = (json_str)[ (json_get)[ td | "uri" ] ]
 | @C1 text = (json_str)[ (json_get)[ td | "text" ] ]
 | IF [ uri == NULL || text == NULL ]
 |  | RET
 |  \_
 |
 | @Doc d = (lsp_doc)[ ls | uri ]
 | IF [ d == NULL ]
 |  | d = (malloc)[ SIZE [ Doc ] ] AS @Doc
 |  | d.uri = (strdup)[ uri ]
 |  | @C1 p = (uri_to_path)[ uri ]
 |  | d.path = (lsp_intern)[ ls | p ]
 |  | (free)[ p AS @ABYSS ]
 |  | (d.facts.init)[ 1024 ]
 |  | (ls.docs.push)[ d ]
 |  | (str_init_cstr)[ @(d.text) | text ]
 | ELSE
 |  | (str_deinit)[ @(d.text) ]
 |  | (str_init_cstr)[ @(d.text) | text ]
 |  \_
 | (lsp_analyse)[ ls | d ]
 \_

ABYSS lsp_change: [ @Lsp ls | @JNode params ]
 | @Doc d = (lsp_doc)[ ls | (json_str)[ (json_get)[ (json_get)[ params | "textDocument" ] | "uri" ] ] ]
 | @JNode ch = (json_get)[ params | "contentChanges" ]
 | IF [ d == NULL || ch == NULL || ch.kind != J_ARR || ch.child == NULL ]
 |  | RET
 |  \_
 | ; full sync: the last change is the whole text
 | @JNode last = ch.child
 | WHILE [ last.next != NULL ]
 |  | last = last.next
 |  \_
 | @C1 text = (json_str)[ (json_get)[ last | "text" ] ]
 | IF [ text == NULL ]
 |  | RET
 |  \_
 | (str_deinit)[ @(d.text) ]
 | (str_init_cstr)[ @(d.text) | text ]
 | (lsp_analyse)[ ls | d ]
 \_

ABYSS lsp_close: [ @Lsp ls | @JNode params ]
 | @C1 uri = (json_str)[ (json_get)[ (json_get)[ params | "textDocument" ] | "uri" ] ]
 | U64 i = 0
 | WHILE [ uri != NULL && i < (ls.docs.size)[] ]
 |  | @Doc d = ?((ls.docs.at)[ i ])
 |  | IF [ (strcmp)[ d.uri | uri ] == 0 ]
 |  |  | Vector<Problem> none
 |  |  | (none.init)[ 1 ]
 |  |  | (lsp_publish)[ ls | d | @none ]
 |  |  | (none.deinit)[]
 |  |  | (lsp_drop_facts)[ @(d.facts) ]
 |  |  | (d.facts.deinit)[]
 |  |  | (str_deinit)[ @(d.text) ]
 |  |  | (free)[ d.uri AS @ABYSS ]
 |  |  | (free)[ d AS @ABYSS ]
 |  |  | (ls.docs.remove)[ i ]
 |  |  | RET
 |  |  \_
 |  | i += 1
 |  \_
 \_

; A file on disk changed, and any open file may include it.
ABYSS lsp_saved: [ @Lsp ls ]
 | U64 i = 0
 | WHILE [ i < (ls.docs.size)[] ]
 |  | (lsp_analyse)[ ls | ?((ls.docs.at)[ i ]) ]
 |  | i += 1
 |  \_
 \_

ABYSS lsp_definition: [ @Lsp ls | @JNode id | @JNode params ]
 | @Doc d = (lsp_doc)[ ls | (json_str)[ (json_get)[ (json_get)[ params | "textDocument" ] | "uri" ] ] ]
 | I32 col = 0
 | I32 len = 0
 | @Fact f = NULL
 | IF [ d != NULL ]
 |  | f = (lsp_fact_at)[ ls | d | (json_get)[ params | "position" ] | @col | @len ]
 |  \_
 | IF [ f == NULL ]
 |  | (lsp_reply_null)[ id ]
 |  | RET
 |  \_
 |
 | I32 line = f.to_line - 1
 | I32 from = f.to_col - 1
 | I32 to = from + len
 | IF [ f.to_file == d.path ]
 |  | to = (doc_from_byte)[ ls | d | line | to ]
 |  | from = (doc_from_byte)[ ls | d | line | from ]
 |  \_
 | String o
 | (lsp_reply)[ @o | id ]
 | (str_append_str)[ @o | "{\"uri\":" ]
 | (jw_uri)[ @o | f.to_file ]
 | (str_append_str)[ @o | ",\"range\":" ]
 | (jw_range)[ @o | line | from | to ]
 | (str_append)[ @o | '}' ]
 | (lsp_finish)[ @o ]
 \_

ABYSS lsp_hover: [ @Lsp ls | @JNode id | @JNode params ]
 | @Doc d = (lsp_doc)[ ls | (json_str)[ (json_get)[ (json_get)[ params | "textDocument" ] | "uri" ] ] ]
 | I32 col = 0
 | I32 len = 0
 | @Fact f = NULL
 | IF [ d != NULL ]
 |  | f = (lsp_fact_at)[ ls | d | (json_get)[ params | "position" ] | @col | @len ]
 |  \_
 | IF [ f == NULL ]
 |  | (lsp_reply_null)[ id ]
 |  | RET
 |  \_
 |
 | I32 line = f.line - 1
 | String o
 | (lsp_reply)[ @o | id ]
 | (str_append_str)[ @o | "{\"contents\":{\"kind\":\"plaintext\",\"value\":" ]
 | (jw_str)[ @o | f.hover ]
 | (str_append_str)[ @o | "},\"range\":" ]
 | (jw_range)[ @o | line | (doc_from_byte)[ ls | d | line | col ] | (doc_from_byte)[ ls | d | line | col + len ] ]
 | (str_append)[ @o | '}' ]
 | (lsp_finish)[ @o ]
 \_

; FALSE once the client has said `exit`.
B1 lsp_dispatch: [ @Lsp ls | @JNode msg ]
 | @C1 method = (json_str)[ (json_get)[ msg | "method" ] ]
 | @JNode id = (json_get)[ msg | "id" ]
 | @JNode params = (json_get)[ msg | "params" ]
 | IF [ method == NULL ]
 |  | ; a response: the server asks nothing, so there is none to wait for
 |  | RET [ TRUE ]
 |  \_
 |
 | IF [ (strcmp)[ method | "initialize" ] == 0 ]
 |  | (lsp_initialize)[ ls | id | params ]
 | ELIF [ (strcmp)[ method | "shutdown" ] == 0 ]
 |  | ls.shut = TRUE
 |  | (lsp_reply_null)[ id ]
 | ELIF [ (strcmp)[ method | "exit" ] == 0 ]
 |  | RET [ FALSE ]
 | ELIF [ (strcmp)[ method | "textDocument/didOpen" ] == 0 ]
 |  | (lsp_open)[ ls | params ]
 | ELIF [ (strcmp)[ method | "textDocument/didChange" ] == 0 ]
 |  | (lsp_change)[ ls | params ]
 | ELIF [ (strcmp)[ method | "textDocument/didSave" ] == 0 ]
 |  | (lsp_saved)[ ls ]
 | ELIF [ (strcmp)[ method | "textDocument/didClose" ] == 0 ]
 |  | (lsp_close)[ ls | params ]
 | ELIF [ (strcmp)[ method | "textDocument/definition" ] == 0 || (strcmp)[ method | "textDocument/declaration" ] == 0 ]
 |  | (lsp_definition)[ ls | id | params ]
 | ELIF [ (strcmp)[ method | "textDocument/hover" ] == 0 ]
 |  | (lsp_hover)[ ls | id | params ]
 | ELIF [ id != NULL ]
 |  | (lsp_reply_error)[ id | -32601 | "plc does not serve this request" ]
 |  \_
 | RET [ TRUE ]
 \_

I32 lsp_main: []
 | ; a child that dies before reading its input must not take us with it
 | (signal)[ 13 | 1 AS @ABYSS ]
 |
 | Lsp ls
 | (ls.docs.init)[ 8 ]
 | (map_init)[ @(ls.interned) | 256 ]
 | (map_init)[ @(ls.canon) | 256 ]
 | (arena_init)[ @(ls.arena) | 65536 ]
 | ls.utf8 = FALSE
 | ls.shut = FALSE
 |
 | LOOP
 |  | U64 len = 0
 |  | @C1 body = (lsp_read)[ @len ]
 |  | IF [ body == NULL ]
 |  |  | BREAK
 |  |  \_
 |  | (arena_reset)[ @(ls.arena) ]
 |  | @JNode msg = (json_parse)[ @(ls.arena) | body | len ]
 |  | B1 more = TRUE
 |  | IF [ msg == NULL ]
 |  |  | (lsp_reply_error)[ NULL | -32700 | "not JSON" ]
 |  | ELSE
 |  |  | more = (lsp_dispatch)[ @ls | msg ]
 |  |  \_
 |  | (free)[ body AS @ABYSS ]
 |  | IF [ !more ]
 |  |  | BREAK
 |  |  \_
 |  \_
 |
 | ; the protocol's convention: exit without shutdown is an error
 | IF [ ls.shut ]
 |  | RET [ 0 ]
 |  \_
 | RET [ 1 ]
 \_
