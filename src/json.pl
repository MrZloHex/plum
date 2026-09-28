; json.pl -- just enough JSON for the language server
;
; json_parse builds a tree in an arena, which the server resets after
; every message. Strings come out decoded (\uXXXX as UTF-8); every node
; also keeps where it lay in the text, so a request id -- a number or a
; string -- can be echoed back exactly as it came.

!USES <../lib/arena.pl>
!USES <../lib/string.pl>
!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>

TYPE JKind: ENUM
 | J_NULL
 | J_BOOL
 | J_NUM
 | J_STR
 | J_ARR
 | J_OBJ
 \_

TYPE JNode: STRUCT
 | I32    kind
 | B1     truth       ; J_BOOL
 | I64    num         ; J_NUM, the integer part
 | @C1    str         ; J_STR, decoded
 | @C1    key         ; the member's name, inside an object
 | @JNode child       ; the first element or member
 | @JNode next
 | @C1    raw         ; the node as written
 | U64    raw_len
 \_

TYPE JParser: STRUCT
 | @C1    s
 | U64    pos
 | U64    len
 | @Arena arena
 | B1     bad
 | I32    depth       ; arrays and objects open around this point
 \_

; --- reading --------------------------------------------------------------

C1 jp_peek: [ @JParser p ]
 | IF [ p.pos >= p.len ]
 |  | RET [ '\0' ]
 |  \_
 | RET [ p.s{p.pos} ]
 \_

ABYSS jp_ws: [ @JParser p ]
 | WHILE [ p.pos < p.len ]
 |  | C1 c = p.s{p.pos}
 |  | IF [ c != ' ' && c != '\t' && c != '\n' && c != '\r' ]
 |  |  | RET
 |  |  \_
 |  | p.pos += 1
 |  \_
 \_

B1 jp_lit: [ @JParser p | @C1 word ]
 | U64 n = (strlen)[ word ]
 | IF [ p.pos + n > p.len || (strncmp)[ p.s + p.pos | word | n ] != 0 ]
 |  | p.bad = TRUE
 |  | RET [ FALSE ]
 |  \_
 | p.pos += n
 | RET [ TRUE ]
 \_

I32 jp_hex4: [ @JParser p ]
 | IF [ p.pos + 4 > p.len ]
 |  | p.bad = TRUE
 |  | RET [ 0 ]
 |  \_
 | I32 v = 0
 | I32 i = 0
 | WHILE [ i < 4 ]
 |  | C1 h = p.s{p.pos}
 |  | I32 d = 0
 |  | IF [ h >= '0' && h <= '9' ]
 |  |  | d = (h AS I32) - 48
 |  | ELIF [ h >= 'a' && h <= 'f' ]
 |  |  | d = (h AS I32) - 87
 |  | ELIF [ h >= 'A' && h <= 'F' ]
 |  |  | d = (h AS I32) - 55
 |  | ELSE
 |  |  | p.bad = TRUE
 |  |  \_
 |  | v = v * 16 + d
 |  | p.pos += 1
 |  | i += 1
 |  \_
 | RET [ v ]
 \_

; Code point `cp` as UTF-8 at `out`; how many bytes that took.
U64 utf8_put: [ @C1 out | I32 cp ]
 | IF [ cp < 128 ]
 |  | out{0} = cp AS C1
 |  | RET [ 1 ]
 |  \_
 | IF [ cp < 2048 ]
 |  | out{0} = (192 + (cp >> 6)) AS C1
 |  | out{1} = (128 + (cp & 63)) AS C1
 |  | RET [ 2 ]
 |  \_
 | IF [ cp < 65536 ]
 |  | out{0} = (224 + (cp >> 12)) AS C1
 |  | out{1} = (128 + ((cp >> 6) & 63)) AS C1
 |  | out{2} = (128 + (cp & 63)) AS C1
 |  | RET [ 3 ]
 |  \_
 | out{0} = (240 + (cp >> 18)) AS C1
 | out{1} = (128 + ((cp >> 12) & 63)) AS C1
 | out{2} = (128 + ((cp >> 6) & 63)) AS C1
 | out{3} = (128 + (cp & 63)) AS C1
 | RET [ 4 ]
 \_

; At the opening quote. Decoding never lengthens the text, so the result
; fits in as many bytes as the literal took.
@C1 jp_string: [ @JParser p ]
 | p.pos += 1
 | U64 start = p.pos
 | WHILE [ p.pos < p.len && p.s{p.pos} != '"' ]
 |  | IF [ p.s{p.pos} == '\\' ]
 |  |  | p.pos += 1
 |  |  \_
 |  | p.pos += 1
 |  \_
 | IF [ p.pos >= p.len ]
 |  | p.bad = TRUE
 |  | RET [ "" ]
 |  \_
 | U64 end = p.pos
 | p.pos += 1
 |
 | @C1 out = (arena_alloc)[ p.arena | end - start + 1 ] AS @C1
 | U64 n = 0
 | U64 i = start
 | WHILE [ i < end ]
 |  | C1 c = p.s{i}
 |  | i += 1
 |  | IF [ c != '\\' ]
 |  |  | out{n} = c
 |  |  | n += 1
 |  |  | CONTINUE
 |  |  \_
 |  |
 |  | C1 e = p.s{i}
 |  | i += 1
 |  | IF [ e == 'n' ]
 |  |  | out{n} = '\n'
 |  | ELIF [ e == 't' ]
 |  |  | out{n} = '\t'
 |  | ELIF [ e == 'r' ]
 |  |  | out{n} = '\r'
 |  | ELIF [ e == 'b' ]
 |  |  | out{n} = '\x08'
 |  | ELIF [ e == 'f' ]
 |  |  | out{n} = '\x0c'
 |  | ELIF [ e == 'u' ]
 |  |  | p.pos = i
 |  |  | I32 cp = (jp_hex4)[ p ]
 |  |  | i = p.pos
 |  |  | ; a surrogate pair is one code point
 |  |  | IF [ cp >= 55296 && cp < 56320 && i + 6 <= end && p.s{i} == '\\' && p.s{i + 1} == 'u' ]
 |  |  |  | p.pos = i + 2
 |  |  |  | I32 lo = (jp_hex4)[ p ]
 |  |  |  | IF [ lo >= 56320 && lo < 57344 ]
 |  |  |  |  | cp = 65536 + ((cp - 55296) << 10) + (lo - 56320)
 |  |  |  |  | i = p.pos
 |  |  |  |  \_
 |  |  |  \_
 |  |  | p.pos = end + 1
 |  |  | n += (utf8_put)[ out + n | cp ]
 |  |  | CONTINUE
 |  | ELSE
 |  |  | ; \" \\ \/
 |  |  | out{n} = e
 |  |  \_
 |  | n += 1
 |  \_
 | out{n} = '\0'
 | RET [ out ]
 \_

@JNode jp_value: [ @JParser p ]
 | (jp_ws)[ p ]
 | @JNode n = (arena_alloc)[ p.arena | SIZE [ JNode ] ] AS @JNode
 | (memset)[ n AS @ABYSS | 0 | SIZE [ JNode ] ]
 | n.raw = p.s + p.pos
 | U64 start = p.pos
 | C1 c = (jp_peek)[ p ]
 |
 | IF [ c == '{' || c == '[' ]
 |  | ; each level is a level of recursion here: past this, not JSON we take
 |  | p.depth += 1
 |  | IF [ p.depth > 512 ]
 |  |  | p.bad = TRUE
 |  |  | RET [ n ]
 |  |  \_
 |  | C1 close = ']'
 |  | n.kind = J_ARR
 |  | IF [ c == '{' ]
 |  |  | close = '}'
 |  |  | n.kind = J_OBJ
 |  |  \_
 |  | p.pos += 1
 |  | @@JNode tail = @(n.child)
 |  | (jp_ws)[ p ]
 |  | IF [ (jp_peek)[ p ] == close ]
 |  |  | p.pos += 1
 |  |  | n.raw_len = p.pos - start
 |  |  | RET [ n ]
 |  |  \_
 |  | LOOP
 |  |  | @C1 key = NULL
 |  |  | IF [ n.kind == J_OBJ ]
 |  |  |  | (jp_ws)[ p ]
 |  |  |  | IF [ (jp_peek)[ p ] != '"' ]
 |  |  |  |  | p.bad = TRUE
 |  |  |  |  | RET [ n ]
 |  |  |  |  \_
 |  |  |  | key = (jp_string)[ p ]
 |  |  |  | (jp_ws)[ p ]
 |  |  |  | IF [ (jp_peek)[ p ] != ':' ]
 |  |  |  |  | p.bad = TRUE
 |  |  |  |  | RET [ n ]
 |  |  |  |  \_
 |  |  |  | p.pos += 1
 |  |  |  \_
 |  |  | @JNode item = (jp_value)[ p ]
 |  |  | IF [ p.bad ]
 |  |  |  | RET [ n ]
 |  |  |  \_
 |  |  | item.key = key
 |  |  | ?(tail) = item
 |  |  | tail = @(item.next)
 |  |  | (jp_ws)[ p ]
 |  |  | C1 sep = (jp_peek)[ p ]
 |  |  | p.pos += 1
 |  |  | IF [ sep == close ]
 |  |  |  | BREAK
 |  |  |  \_
 |  |  | IF [ sep != ',' ]
 |  |  |  | p.bad = TRUE
 |  |  |  | RET [ n ]
 |  |  |  \_
 |  |  \_
 |  | n.raw_len = p.pos - start
 |  | p.depth -= 1
 |  | RET [ n ]
 |  \_
 |
 | IF [ c == '"' ]
 |  | n.kind = J_STR
 |  | n.str = (jp_string)[ p ]
 | ELIF [ c == 't' ]
 |  | n.kind = J_BOOL
 |  | n.truth = (jp_lit)[ p | "true" ]
 | ELIF [ c == 'f' ]
 |  | n.kind = J_BOOL
 |  | (jp_lit)[ p | "false" ]
 | ELIF [ c == 'n' ]
 |  | n.kind = J_NULL
 |  | (jp_lit)[ p | "null" ]
 | ELIF [ c == '-' || (c >= '0' && c <= '9') ]
 |  | n.kind = J_NUM
 |  | B1 neg = c == '-'
 |  | IF [ neg ]
 |  |  | p.pos += 1
 |  |  \_
 |  | WHILE [ (jp_peek)[ p ] >= '0' && (jp_peek)[ p ] <= '9' ]
 |  |  | n.num = n.num * 10 + ((jp_peek)[ p ] AS I64) - 48
 |  |  | p.pos += 1
 |  |  \_
 |  | IF [ neg ]
 |  |  | n.num = -(n.num)
 |  |  \_
 |  | ; a fraction or an exponent: skipped, the server never needs one
 |  | C1 d = (jp_peek)[ p ]
 |  | WHILE [ d == '.' || d == 'e' || d == 'E' || d == '+' || d == '-' || (d >= '0' && d <= '9') ]
 |  |  | p.pos += 1
 |  |  | d = (jp_peek)[ p ]
 |  |  \_
 | ELSE
 |  | p.bad = TRUE
 |  \_
 | n.raw_len = p.pos - start
 | RET [ n ]
 \_

; The tree of `text`, or 0 when it is not JSON.
@JNode json_parse: [ @Arena a | @C1 text | U64 len ]
 | JParser p
 | p.s = text
 | p.pos = 0
 | p.len = len
 | p.arena = a
 | p.bad = FALSE
 | p.depth = 0
 | @JNode root = (jp_value)[ @p ]
 | IF [ p.bad ]
 |  | RET [ NULL ]
 |  \_
 | RET [ root ]
 \_

; --- looking inside -------------------------------------------------------

; The member `key` of an object, or 0. Safe on 0 and on non-objects, so
; lookups chain: (json_get)[ (json_get)[ msg | "params" ] | "textDocument" ]
@JNode json_get: [ @JNode obj | @C1 key ]
 | IF [ obj == NULL || obj.kind != J_OBJ ]
 |  | RET [ NULL ]
 |  \_
 | @JNode m = obj.child
 | WHILE [ m != NULL ]
 |  | IF [ (strcmp)[ m.key | key ] == 0 ]
 |  |  | RET [ m ]
 |  |  \_
 |  | m = m.next
 |  \_
 | RET [ NULL ]
 \_

@C1 json_str: [ @JNode n ]
 | IF [ n == NULL || n.kind != J_STR ]
 |  | RET [ NULL ]
 |  \_
 | RET [ n.str ]
 \_

I64 json_int: [ @JNode n | I64 dflt ]
 | IF [ n == NULL || n.kind != J_NUM ]
 |  | RET [ dflt ]
 |  \_
 | RET [ n.num ]
 \_

; --- writing --------------------------------------------------------------

; How many bytes the UTF-8 sequence at s takes, or 0 when it is not one:
; no overlong forms, no UTF-16 surrogates, nothing past U+10FFFF.
U64 utf8_len: [ @C1 s ]
 | I32 b = (s{0} AS I32) & 255
 | I32 b1 = (s{1} AS I32) & 255
 | U64 n = 0
 | IF [ b >= 194 && b < 224 ]
 |  | n = 2
 | ELIF [ b >= 224 && b < 240 ]
 |  | n = 3
 |  | IF [ (b == 224 && b1 < 160) || (b == 237 && b1 >= 160) ]
 |  |  | RET [ 0 ]
 |  |  \_
 | ELIF [ b >= 240 && b < 245 ]
 |  | n = 4
 |  | IF [ (b == 240 && b1 < 144) || (b == 244 && b1 >= 144) ]
 |  |  | RET [ 0 ]
 |  |  \_
 | ELSE
 |  | RET [ 0 ]
 |  \_
 | U64 k = 1
 | WHILE [ k < n ]
 |  | IF [ ((s{k} AS I32) & 192) != 128 ]
 |  |  | RET [ 0 ]
 |  |  \_
 |  | k += 1
 |  \_
 | RET [ n ]
 \_

ABYSS jw_str: [ @String o | @C1 s ]
 | (o.push)[ '"' ]
 | U64 i = 0
 | WHILE [ s{i} != '\0' ]
 |  | C1 c = s{i}
 |  | IF [ c == '"' ]
 |  |  | (o.append)[ "\\\"" ]
 |  | ELIF [ c == '\\' ]
 |  |  | (o.append)[ "\\\\" ]
 |  | ELIF [ c == '\n' ]
 |  |  | (o.append)[ "\\n" ]
 |  | ELIF [ c == '\r' ]
 |  |  | (o.append)[ "\\r" ]
 |  | ELIF [ c == '\t' ]
 |  |  | (o.append)[ "\\t" ]
 |  | ELIF [ c >= '\0' && c < ' ' ]
 |  |  | C1 buf{8}
 |  |  | (snprintf)[ buf | 8 | "\\u%04x" | c AS I32 ]
 |  |  | (o.append)[ buf ]
 |  | ELIF [ c >= '\0' ]
 |  |  | (o.push)[ c ]
 |  | ELSE
 |  |  | ; JSON is UTF-8: what is not becomes U+FFFD, so no byte from a
 |  |  | ; file name or a string literal can break the message
 |  |  | U64 n = (utf8_len)[ s + i ]
 |  |  | IF [ n == 0 ]
 |  |  |  | (o.append)[ "\\ufffd" ]
 |  |  |  | n = 1
 |  |  | ELSE
 |  |  |  | (jw_raw)[ o | s + i | n ]
 |  |  |  \_
 |  |  | i += n - 1
 |  |  \_
 |  | i += 1
 |  \_
 | (o.push)[ '"' ]
 \_

ABYSS jw_int: [ @String o | I64 v ]
 | C1 buf{24}
 | (snprintf)[ buf | 24 | "%ld" | v ]
 | (o.append)[ buf ]
 \_

; `n` bytes of `s`, as they are.
ABYSS jw_raw: [ @String o | @C1 s | U64 n ]
 | U64 i = 0
 | WHILE [ i < n ]
 |  | (o.push)[ s{i} ]
 |  | i += 1
 |  \_
 \_
