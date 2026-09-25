; check.pl -- the type checker
;
; Runs between meta and codegen. It only ever rejects; it never changes
; what is emitted, so a program that passes compiles exactly as before.
;
; It exists because every bug that cost real time during the bootstrap was
; a type error nothing was positioned to catch:
;
;   * a U64 hash flowing into a signed SRem, indexing before an array
;   * a struct value assigned to a pointer, silently producing garbage
;   * `!p.field` grouping as `(!p).field`, loading a field off an i1
;   * float arithmetic reaching LLVM as `sdiv double`
;
; Each of those is now an error here, with a line and column.

!USES <ast.pl>
!USES <meta.pl>
!USES <../lib/vec.pl>
!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>

TYPE TyKind: ENUM
 | TY_UNKNOWN          ; could not be determined; never an error by itself
 | TY_VOID
 | TY_BOOL
 | TY_INT
 | TY_FLOAT
 | TY_RECORD
 | TY_ENUM
 \_

TYPE Type: STRUCT
 | I32      kind
 | U64      ptrs       ; pointer depth
 | I32      bits       ; width for TY_INT and TY_FLOAT
 | B1       sign       ; TY_INT only
 | @C1      name       ; TY_RECORD / TY_ENUM
 | @ASTNode decl       ; the NT_TYPE_DEF, for field lookup
 \_

TYPE CkSym: STRUCT
 | @C1  name
 | Type ty
 \_

TYPE CkScope: STRUCT
 | Vec       syms
 | @CkScope  parent
 \_

TYPE Checker: STRUCT
 | @Meta     meta
 | @CkScope  scope
 | Type      ret_type     ; of the function being checked
 | @ASTNode  tu           ; the translation unit, for enum lookup
 | I32       errors
 \_

; --- constructing types ---------------------------------------------------

Type ty_make: [ I32 kind | U64 ptrs | I32 bits | B1 sign ]
 | Type t
 | t.kind = kind
 | t.ptrs = ptrs
 | t.bits = bits
 | t.sign = sign
 | t.name = 0
 | t.decl = 0
 | RET [ t ]
 \_

Type ty_unknown: []
 | RET [ (ty_make)[ TY_UNKNOWN | 0 | 0 | FALSE ] ]
 \_

Type ty_int: [ I32 bits | B1 sign ]
 | RET [ (ty_make)[ TY_INT | 0 | bits | sign ] ]
 \_

Type ty_bool: []
 | RET [ (ty_make)[ TY_BOOL | 0 | 1 | FALSE ] ]
 \_

Type ty_void: []
 | RET [ (ty_make)[ TY_VOID | 0 | 0 | FALSE ] ]
 \_

B1 ty_is_ptr: [ Type t ]
 | RET [ t.ptrs > 0 ]
 \_

B1 ty_is_scalar: [ Type t ]
 | IF [ t.ptrs > 0 ]
 |  | RET [ TRUE ]
 |  \_
 | RET [ t.kind == TY_INT || t.kind == TY_BOOL || t.kind == TY_ENUM || t.kind == TY_FLOAT ]
 \_

B1 ty_is_aggregate: [ Type t ]
 | RET [ t.ptrs == 0 && t.kind == TY_RECORD ]
 \_

; A short spelling, for diagnostics. Caller owns nothing; the buffer is
; reused, so print it before building another.
@C1 ty_str: [ Type t ]
 | @C1 buf = (malloc)[ 64 ] AS @C1
 | @C1 base = "?"
 |
 | IF [ t.kind == TY_VOID ]
 |  | base = "ABYSS"
 | ELIF [ t.kind == TY_BOOL ]
 |  | base = "B1"
 | ELIF [ t.kind == TY_FLOAT ]
 |  | IF [ t.bits == 32 ]
 |  |  | base = "F32"
 |  | ELSE
 |  |  | base = "F64"
 |  |  \_
 | ELIF [ t.kind == TY_RECORD || t.kind == TY_ENUM ]
 |  | base = t.name
 | ELIF [ t.kind == TY_UNKNOWN ]
 |  | base = "<unknown>"
 | ELIF [ t.kind == TY_INT ]
 |  | IF [ t.bits == 8 && !(t.sign) ]
 |  |  | base = "U8"
 |  | ELIF [ t.bits == 8 ]
 |  |  | base = "I8"
 |  | ELIF [ t.bits == 16 && !(t.sign) ]
 |  |  | base = "U16"
 |  | ELIF [ t.bits == 16 ]
 |  |  | base = "I16"
 |  | ELIF [ t.bits == 32 && !(t.sign) ]
 |  |  | base = "U32"
 |  | ELIF [ t.bits == 32 ]
 |  |  | base = "I32"
 |  | ELIF [ t.bits == 64 && !(t.sign) ]
 |  |  | base = "U64"
 |  | ELSE
 |  |  | base = "I64"
 |  |  \_
 |  \_
 |
 | @C1 stars = ""
 | IF [ t.ptrs == 1 ]
 |  | stars = "@"
 | ELIF [ t.ptrs == 2 ]
 |  | stars = "@@"
 | ELIF [ t.ptrs >= 3 ]
 |  | stars = "@@@"
 |  \_
 |
 | (snprintf)[ buf | 64 | "%s%s" | stars | base ]
 | RET [ buf ]
 \_

ABYSS ck_error: [ @Checker c | @ASTNode at | @C1 msg ]
 | (printf)[ "%d:%d: %s\n" | at.loc.line | at.loc.col | msg ]
 | c.errors = c.errors + 1
 | RET
 \_

ABYSS ck_error2: [ @Checker c | @ASTNode at | @C1 fmt | @C1 a | @C1 b ]
 | @C1 buf = (malloc)[ 256 ] AS @C1
 | (snprintf)[ buf | 256 | fmt | a | b ]
 | (printf)[ "%d:%d: %s\n" | at.loc.line | at.loc.col | buf ]
 | (free)[ buf AS @ABYSS ]
 | c.errors = c.errors + 1
 | RET
 \_

; --- resolving a declared type -------------------------------------------

Type ty_of_base: [ I32 bt ]
 | IF [ bt == BT_ABYSS ]
 |  | RET [ (ty_void)[] ]
 |  \_
 | IF [ bt == BT_B1 ]
 |  | RET [ (ty_bool)[] ]
 |  \_
 | IF [ bt == BT_C1 ]
 |  | RET [ (ty_int)[ 8 | TRUE ] ]
 |  \_
 | IF [ bt == BT_U8 ]
 |  | RET [ (ty_int)[ 8 | FALSE ] ]
 |  \_
 | IF [ bt == BT_I8 ]
 |  | RET [ (ty_int)[ 8 | TRUE ] ]
 |  \_
 | IF [ bt == BT_U16 ]
 |  | RET [ (ty_int)[ 16 | FALSE ] ]
 |  \_
 | IF [ bt == BT_I16 ]
 |  | RET [ (ty_int)[ 16 | TRUE ] ]
 |  \_
 | IF [ bt == BT_U32 ]
 |  | RET [ (ty_int)[ 32 | FALSE ] ]
 |  \_
 | IF [ bt == BT_I32 ]
 |  | RET [ (ty_int)[ 32 | TRUE ] ]
 |  \_
 | IF [ bt == BT_U64 || bt == BT_USIZE ]
 |  | RET [ (ty_int)[ 64 | FALSE ] ]
 |  \_
 | IF [ bt == BT_I64 || bt == BT_ISIZE ]
 |  | RET [ (ty_int)[ 64 | TRUE ] ]
 |  \_
 | IF [ bt == BT_F32 ]
 |  | RET [ (ty_make)[ TY_FLOAT | 0 | 32 | TRUE ] ]
 |  \_
 | IF [ bt == BT_F64 ]
 |  | RET [ (ty_make)[ TY_FLOAT | 0 | 64 | TRUE ] ]
 |  \_
 | RET [ (ty_unknown)[] ]
 \_

Type ty_resolve: [ @Checker c | @ASTNode tn ]
 | Type t = (ty_unknown)[]
 | IF [ tn == 0 ]
 |  | RET [ t ]
 |  \_
 |
 | IF [ tn.as.type.kind == TT_BASE_TYPE ]
 |  | t = (ty_of_base)[ tn.as.type.type.as.base_type ]
 | ELSE
 |  | @C1 nm = tn.as.type.type.as.ident
 |  | @ABYSS d = 0
 |  | IF [ (map_get)[ @(c.meta.types) | nm | @d AS @@ABYSS ] == 1 ]
 |  |  | @ASTNode td = d AS @ASTNode
 |  |  | IF [ td.as.type_def.kind == TD_ENUM ]
 |  |  |  | t = (ty_make)[ TY_ENUM | 0 | 32 | TRUE ]
 |  |  | ELIF [ td.as.type_def.kind == TD_RECORD ]
 |  |  |  | t = (ty_make)[ TY_RECORD | 0 | 0 | FALSE ]
 |  |  | ELSE
 |  |  |  | t = (ty_resolve)[ c | td.as.type_def.tdef ]
 |  |  |  \_
 |  |  | t.name = nm
 |  |  | t.decl = td
 |  | ELSE
 |  |  | (ck_error2)[ c | tn | "unknown type `%s`%s" | nm | "" ]
 |  |  \_
 |  \_
 |
 | t.ptrs = t.ptrs + tn.as.type.ptrs
 | RET [ t ]
 \_

; --- scopes ---------------------------------------------------------------

ABYSS ck_push: [ @Checker c ]
 | @CkScope s = (malloc)[ SIZE [ CkScope ] ] AS @CkScope
 | (vec_init)[ @(s.syms) | SIZE [ CkSym ] | 16 ]
 | s.parent = c.scope
 | c.scope = s
 | RET
 \_

ABYSS ck_pop: [ @Checker c ]
 | @CkScope s = c.scope
 | IF [ s == 0 ]
 |  | RET
 |  \_
 | c.scope = s.parent
 | (vec_deinit)[ @(s.syms) ]
 | (free)[ s AS @ABYSS ]
 | RET
 \_

B1 ck_declared_here: [ @Checker c | @C1 name ]
 | U64 i = 0
 | WHILE [ i < (vec_size)[ @(c.scope.syms) ] ]
 |  | @CkSym s = (vec_at)[ @(c.scope.syms) | i ] AS @CkSym
 |  | IF [ (strcmp)[ s.name | name ] == 0 ]
 |  |  | RET [ TRUE ]
 |  |  \_
 |  | i = i + 1
 |  \_
 | RET [ FALSE ]
 \_

ABYSS ck_define: [ @Checker c | @C1 name | Type t ]
 | CkSym s
 | s.name = name
 | s.ty = t
 | (vec_append)[ @(c.scope.syms) | @s AS @ABYSS ]
 | RET
 \_

B1 ck_lookup: [ @Checker c | @C1 name | @Type out ]
 | @CkScope s = c.scope
 | WHILE [ s != 0 ]
 |  | U64 n = (vec_size)[ @(s.syms) ]
 |  | U64 i = n
 |  | WHILE [ i > 0 ]
 |  |  | i = i - 1
 |  |  | @CkSym sym = (vec_at)[ @(s.syms) | i ] AS @CkSym
 |  |  | IF [ (strcmp)[ sym.name | name ] == 0 ]
 |  |  |  | ?(out) = sym.ty
 |  |  |  | RET [ TRUE ]
 |  |  |  \_
 |  |  \_
 |  | s = s.parent
 |  \_
 | RET [ FALSE ]
 \_

; --- assignability --------------------------------------------------------
;
; Deliberately permissive where PLUM's implicit coercion already is --
; integer widths convert, pointers convert to one another -- and strict
; where silence was costing correctness: aggregates convert to nothing.

B1 ty_assignable: [ Type to | Type from ]
 | IF [ to.kind == TY_UNKNOWN || from.kind == TY_UNKNOWN ]
 |  | RET [ TRUE ]
 |  \_
 |
 | ; an aggregate only accepts the same aggregate
 | IF [ (ty_is_aggregate)[ to ] || (ty_is_aggregate)[ from ] ]
 |  | IF [ !(ty_is_aggregate)[ to ] || !(ty_is_aggregate)[ from ] ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | IF [ to.name == 0 || from.name == 0 ]
 |  |  | RET [ TRUE ]
 |  |  \_
 |  | RET [ (strcmp)[ to.name | from.name ] == 0 ]
 |  \_
 |
 | ; pointers interconvert, and accept a literal 0
 | IF [ to.ptrs > 0 ]
 |  | RET [ from.ptrs > 0 || from.kind == TY_INT || from.kind == TY_BOOL ]
 |  \_
 | IF [ from.ptrs > 0 ]
 |  | RET [ to.kind == TY_INT || to.kind == TY_BOOL ]
 |  \_
 |
 | IF [ to.kind == TY_VOID || from.kind == TY_VOID ]
 |  | RET [ to.kind == from.kind ]
 |  \_
 |
 | RET [ (ty_is_scalar)[ to ] && (ty_is_scalar)[ from ] ]
 \_

; --- expressions ----------------------------------------------------------

Type ck_expr: [ @Checker c | @ASTNode e ]

@ASTNode ck_strip: [ @ASTNode e ]
 | @ASTNode n = e
 | WHILE [ n != 0 && n.kind == NT_EXPR ]
 |  | n = n.as.expr.expr
 |  \_
 | RET [ n ]
 \_

B1 ck_field: [ @Checker c | Type base | @C1 field | @Type out | @ASTNode at ]
 | IF [ base.decl == 0 ]
 |  | RET [ FALSE ]
 |  \_
 | @ASTNode rec = base.decl.as.type_def.tdef
 | @ASTNode f = rec.as.record.fields
 | WHILE [ f != 0 ]
 |  | IF [ (strcmp)[ f.as.rcrd_flds.ident.as.ident | field ] == 0 ]
 |  |  | ?(out) = (ty_resolve)[ c | f.as.rcrd_flds.type ]
 |  |  | RET [ TRUE ]
 |  |  \_
 |  | f = f.as.rcrd_flds.next_field
 |  \_
 | RET [ FALSE ]
 \_

Type ck_call: [ @Checker c | @ASTNode n ]
 | @C1 name = n.as.fn_call.ident.as.ident
 | @ABYSS d = 0
 |
 | IF [ (map_get)[ @(c.meta.func_decls) | name | @d AS @@ABYSS ] != 1 ]
 |  | (ck_error2)[ c | n | "call to undeclared function `%s`%s" | name | "" ]
 |  | RET [ (ty_unknown)[] ]
 |  \_
 |
 | @ASTNode decl = d AS @ASTNode
 |
 | ; count declared parameters, and note whether it is variadic
 | I32 want = 0
 | B1 va = FALSE
 | @ASTNode p = decl.as.fn_decl.params
 | WHILE [ p != 0 ]
 |  | IF [ p.as.parametre.vaarg ]
 |  |  | va = TRUE
 |  | ELSE
 |  |  | want = want + 1
 |  |  \_
 |  | p = p.as.parametre.next_param
 |  \_
 |
 | ; walk the arguments against them
 | I32 got = 0
 | p = decl.as.fn_decl.params
 | @ASTNode a = n.as.fn_call.args
 | WHILE [ a != 0 ]
 |  | Type at = (ck_expr)[ c | a.as.argument.argument ]
 |  |
 |  | IF [ p != 0 && !(p.as.parametre.vaarg) ]
 |  |  | Type pt = (ty_resolve)[ c | p.as.parametre.type ]
 |  |  | IF [ !(ty_assignable)[ pt | at ] ]
 |  |  |  | @C1 sw = (ty_str)[ pt ]
 |  |  |  | @C1 sg = (ty_str)[ at ]
 |  |  |  | (ck_error2)[ c | a | "argument expects %s, got %s" | sw | sg ]
 |  |  |  | (free)[ sw AS @ABYSS ]
 |  |  |  | (free)[ sg AS @ABYSS ]
 |  |  |  \_
 |  |  | p = p.as.parametre.next_param
 |  |  \_
 |  |
 |  | got = got + 1
 |  | a = a.as.argument.next_arg
 |  \_
 |
 | IF [ got < want ]
 |  | (ck_error2)[ c | n | "too few arguments to `%s`%s" | name | "" ]
 |  \_
 | IF [ got > want && !va ]
 |  | (ck_error2)[ c | n | "too many arguments to `%s`%s" | name | "" ]
 |  \_
 |
 | RET [ (ty_resolve)[ c | decl.as.fn_decl.type ] ]
 \_

Type ck_binop: [ @Checker c | @ASTNode n ]
 | I32 k = n.as.bin_op.kind
 |
 | ; member access: the left side must be an aggregate, the field must exist
 | IF [ k == BOT_MEMBER ]
 |  | Type base = (ck_expr)[ c | n.as.bin_op.left ]
 |  | @ASTNode fn = (ck_strip)[ n.as.bin_op.right ]
 |  |
 |  | IF [ base.kind == TY_UNKNOWN ]
 |  |  | RET [ (ty_unknown)[] ]
 |  |  \_
 |  |
 |  | ; `.` steps through at most one pointer, as the backend does
 |  | Type obj = base
 |  | IF [ obj.ptrs == 1 ]
 |  |  | obj.ptrs = 0
 |  |  \_
 |  |
 |  | IF [ !(ty_is_aggregate)[ obj ] ]
 |  |  | @C1 s = (ty_str)[ base ]
 |  |  | (ck_error2)[ c | n | "`.` applied to %s, which has no fields%s" | s | "" ]
 |  |  | (free)[ s AS @ABYSS ]
 |  |  | RET [ (ty_unknown)[] ]
 |  |  \_
 |  |
 |  | IF [ fn == 0 || fn.kind != NT_IDENT ]
 |  |  | (ck_error)[ c | n | "`.` needs a field name on the right" ]
 |  |  | RET [ (ty_unknown)[] ]
 |  |  \_
 |  |
 |  | Type ft = (ty_unknown)[]
 |  | IF [ !(ck_field)[ c | obj | fn.as.ident | @ft | n ] ]
 |  |  | (ck_error2)[ c | n | "no field `%s` in `%s`" | fn.as.ident | obj.name ]
 |  |  | RET [ (ty_unknown)[] ]
 |  |  \_
 |  | RET [ ft ]
 |  \_
 |
 | Type lt = (ck_expr)[ c | n.as.bin_op.left ]
 | Type rt = (ck_expr)[ c | n.as.bin_op.right ]
 |
 | IF [ k == BOT_ASSIGN ]
 |  | IF [ !(ty_assignable)[ lt | rt ] ]
 |  |  | @C1 sl = (ty_str)[ lt ]
 |  |  | @C1 sr = (ty_str)[ rt ]
 |  |  | (ck_error2)[ c | n | "cannot assign %s to %s" | sr | sl ]
 |  |  | (free)[ sl AS @ABYSS ]
 |  |  | (free)[ sr AS @ABYSS ]
 |  |  \_
 |  | RET [ lt ]
 |  \_
 |
 | ; logical operators take anything scalar and yield a boolean
 | IF [ k == BOT_AND || k == BOT_OR ]
 |  | IF [ (ty_is_aggregate)[ lt ] || (ty_is_aggregate)[ rt ] ]
 |  |  | (ck_error)[ c | n | "a struct has no truth value" ]
 |  |  \_
 |  | RET [ (ty_bool)[] ]
 |  \_
 |
 | ; comparisons
 | B1 is_cmp = k == BOT_EQUAL || k == BOT_NEQ || k == BOT_LESS
 | IF [ !is_cmp ]
 |  | is_cmp = k == BOT_LEQ || k == BOT_GREAT || k == BOT_GEQ
 |  \_
 | IF [ is_cmp ]
 |  | IF [ (ty_is_aggregate)[ lt ] || (ty_is_aggregate)[ rt ] ]
 |  |  | (ck_error)[ c | n | "cannot compare structs" ]
 |  |  \_
 |  | RET [ (ty_bool)[] ]
 |  \_
 |
 | ; arithmetic and bitwise
 | IF [ (ty_is_aggregate)[ lt ] || (ty_is_aggregate)[ rt ] ]
 |  | (ck_error)[ c | n | "arithmetic on a struct" ]
 |  | RET [ (ty_unknown)[] ]
 |  \_
 |
 | ; the backend emits integer opcodes only -- float arithmetic would
 | ; reach LLVM as `sdiv double` and be rejected there
 | IF [ lt.ptrs == 0 && lt.kind == TY_FLOAT ]
 |  | (ck_error)[ c | n | "float arithmetic is not implemented by the backend" ]
 |  | RET [ lt ]
 |  \_
 | IF [ rt.ptrs == 0 && rt.kind == TY_FLOAT ]
 |  | (ck_error)[ c | n | "float arithmetic is not implemented by the backend" ]
 |  | RET [ rt ]
 |  \_
 |
 | ; pointer arithmetic keeps the pointer's type
 | IF [ lt.ptrs > 0 ]
 |  | RET [ lt ]
 |  \_
 | IF [ rt.ptrs > 0 ]
 |  | RET [ rt ]
 |  \_
 |
 | ; otherwise the wider operand wins
 | IF [ rt.bits > lt.bits ]
 |  | RET [ rt ]
 |  \_
 | RET [ lt ]
 \_

Type ck_expr: [ @Checker c | @ASTNode e ]
 | @ASTNode n = (ck_strip)[ e ]
 | IF [ n == 0 ]
 |  | RET [ (ty_unknown)[] ]
 |  \_
 |
 | IF [ n.kind == NT_LITERAL ]
 |  | I32 lk = n.as.literal.kind
 |  | IF [ lk == LT_INTEGER ]
 |  |  | RET [ (ty_int)[ 32 | TRUE ] ]
 |  |  \_
 |  | IF [ lk == LT_BOOLEAN ]
 |  |  | RET [ (ty_bool)[] ]
 |  |  \_
 |  | IF [ lk == LT_CHARACTER ]
 |  |  | RET [ (ty_int)[ 8 | TRUE ] ]
 |  |  \_
 |  | IF [ lk == LT_STRING ]
 |  |  | Type t = (ty_int)[ 8 | TRUE ]
 |  |  | t.ptrs = 1
 |  |  | RET [ t ]
 |  |  \_
 |  | RET [ (ty_make)[ TY_FLOAT | 0 | 64 | TRUE ] ]
 |  \_
 |
 | IF [ n.kind == NT_IDENT ]
 |  | Type t = (ty_unknown)[]
 |  | IF [ (ck_lookup)[ c | n.as.ident | @t ] ]
 |  |  | RET [ t ]
 |  |  \_
 |  | ; an enum constant is an I32; meta has the type table
 |  | IF [ (ck_is_enum_const)[ c | n.as.ident ] ]
 |  |  | RET [ (ty_int)[ 32 | TRUE ] ]
 |  |  \_
 |  | (ck_error2)[ c | n | "unknown identifier `%s`%s" | n.as.ident | "" ]
 |  | RET [ (ty_unknown)[] ]
 |  \_
 |
 | IF [ n.kind == NT_BIN_OP ]
 |  | RET [ (ck_binop)[ c | n ] ]
 |  \_
 |
 | IF [ n.kind == NT_FN_CALL ]
 |  | RET [ (ck_call)[ c | n ] ]
 |  \_
 |
 | IF [ n.kind == NT_CAST ]
 |  | (ck_expr)[ c | n.as.cast.expr ]
 |  | RET [ (ty_resolve)[ c | n.as.cast.type ] ]
 |  \_
 |
 | IF [ n.kind == NT_BUILTIN ]
 |  | RET [ (ty_int)[ 64 | FALSE ] ]
 |  \_
 |
 | IF [ n.kind == NT_UNY_OP ]
 |  | I32 uk = n.as.uny_op.kind
 |  | Type t = (ck_expr)[ c | n.as.uny_op.operand ]
 |  |
 |  | IF [ uk == UOT_DEREF ]
 |  |  | IF [ t.kind == TY_UNKNOWN ]
 |  |  |  | RET [ t ]
 |  |  |  \_
 |  |  | IF [ t.ptrs == 0 ]
 |  |  |  | @C1 s = (ty_str)[ t ]
 |  |  |  | (ck_error2)[ c | n | "cannot dereference %s, it is not a pointer%s" | s | "" ]
 |  |  |  | (free)[ s AS @ABYSS ]
 |  |  |  | RET [ (ty_unknown)[] ]
 |  |  |  \_
 |  |  | t.ptrs = t.ptrs - 1
 |  |  | RET [ t ]
 |  |  \_
 |  |
 |  | IF [ uk == UOT_REF ]
 |  |  | IF [ t.kind == TY_UNKNOWN ]
 |  |  |  | RET [ t ]
 |  |  |  \_
 |  |  | t.ptrs = t.ptrs + 1
 |  |  | RET [ t ]
 |  |  \_
 |  |
 |  | IF [ uk == UOT_NOT ]
 |  |  | IF [ (ty_is_aggregate)[ t ] ]
 |  |  |  | (ck_error)[ c | n | "a struct has no truth value" ]
 |  |  |  \_
 |  |  | RET [ (ty_bool)[] ]
 |  |  \_
 |  |
 |  | IF [ (ty_is_aggregate)[ t ] ]
 |  |  | (ck_error)[ c | n | "arithmetic on a struct" ]
 |  |  \_
 |  | RET [ t ]
 |  \_
 |
 | RET [ (ty_unknown)[] ]
 \_

B1 ck_is_enum_const: [ @Checker c | @C1 name ]
 | ; enum constants are not in meta by name, so scan the type definitions
 | @ASTNode ts = c.tu.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | IF [ ts.as.tu_stmt.kind == TUST_TYPE_DEF ]
 |  |  | @ASTNode td = ts.as.tu_stmt.tu_stmt
 |  |  | IF [ td.as.type_def.kind == TD_ENUM ]
 |  |  |  | @ASTNode f = td.as.type_def.tdef.as.enumeration.fields
 |  |  |  | WHILE [ f != 0 ]
 |  |  |  |  | IF [ (strcmp)[ f.as.enum_flds.ident.as.ident | name ] == 0 ]
 |  |  |  |  |  | RET [ TRUE ]
 |  |  |  |  |  \_
 |  |  |  |  | f = f.as.enum_flds.next_field
 |  |  |  |  \_
 |  |  |  \_
 |  |  \_
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 | RET [ FALSE ]
 \_

; --- statements -----------------------------------------------------------

ABYSS ck_block: [ @Checker c | @ASTNode blk ]

ABYSS ck_cond_expr: [ @Checker c | @ASTNode e | @C1 what ]
 | Type t = (ck_expr)[ c | e ]
 | IF [ (ty_is_aggregate)[ t ] ]
 |  | (ck_error2)[ c | e | "%s needs a scalar condition, got a struct%s" | what | "" ]
 |  \_
 | RET
 \_

ABYSS ck_stmt: [ @Checker c | @ASTNode st ]
 | I32 k = st.as.stmt.kind
 |
 | IF [ k == ST_VAR_DECL ]
 |  | @ASTNode d = st.as.stmt.stmt
 |  | @C1 nm = d.as.var_decl.ident.as.ident
 |  | Type dt = (ty_resolve)[ c | d.as.var_decl.type ]
 |  |
 |  | IF [ dt.kind == TY_VOID && dt.ptrs == 0 ]
 |  |  | (ck_error2)[ c | d | "`%s` cannot have type ABYSS%s" | nm | "" ]
 |  |  \_
 |  | IF [ (ck_declared_here)[ c | nm ] ]
 |  |  | (ck_error2)[ c | d | "`%s` is already declared in this scope%s" | nm | "" ]
 |  |  \_
 |  |
 |  | IF [ d.as.var_decl.init != 0 ]
 |  |  | Type it = (ck_expr)[ c | d.as.var_decl.init ]
 |  |  | IF [ !(ty_assignable)[ dt | it ] ]
 |  |  |  | @C1 sd = (ty_str)[ dt ]
 |  |  |  | @C1 si = (ty_str)[ it ]
 |  |  |  | (ck_error2)[ c | d | "cannot initialise %s from %s" | sd | si ]
 |  |  |  | (free)[ sd AS @ABYSS ]
 |  |  |  | (free)[ si AS @ABYSS ]
 |  |  |  \_
 |  |  \_
 |  |
 |  | (ck_define)[ c | nm | dt ]
 |  | RET
 |  \_
 |
 | IF [ k == ST_RET ]
 |  | @ASTNode r = st.as.stmt.stmt
 |  | B1 is_void = c.ret_type.kind == TY_VOID && c.ret_type.ptrs == 0
 |  |
 |  | IF [ r.as.ret.expr == 0 ]
 |  |  | IF [ !is_void ]
 |  |  |  | @C1 s = (ty_str)[ c.ret_type ]
 |  |  |  | (ck_error2)[ c | st | "this function must return %s%s" | s | "" ]
 |  |  |  | (free)[ s AS @ABYSS ]
 |  |  |  \_
 |  |  | RET
 |  |  \_
 |  |
 |  | Type rt = (ck_expr)[ c | r.as.ret.expr ]
 |  | IF [ is_void ]
 |  |  | (ck_error)[ c | st | "an ABYSS function cannot return a value" ]
 |  | ELIF [ !(ty_assignable)[ c.ret_type | rt ] ]
 |  |  | @C1 sw = (ty_str)[ c.ret_type ]
 |  |  | @C1 sg = (ty_str)[ rt ]
 |  |  | (ck_error2)[ c | st | "returning %s from a function declared %s" | sg | sw ]
 |  |  | (free)[ sw AS @ABYSS ]
 |  |  | (free)[ sg AS @ABYSS ]
 |  |  \_
 |  | RET
 |  \_
 |
 | IF [ k == ST_COND ]
 |  | @ASTNode cond = st.as.stmt.stmt
 |  | @ASTNode ifp = cond.as.cond.if_part
 |  | (ck_cond_expr)[ c | ifp.as.if_cond.expr | "IF" ]
 |  | (ck_block)[ c | ifp.as.if_cond.block ]
 |  |
 |  | @ASTNode el = cond.as.cond.elif_part
 |  | WHILE [ el != 0 ]
 |  |  | (ck_cond_expr)[ c | el.as.elif_cond.expr | "ELIF" ]
 |  |  | (ck_block)[ c | el.as.elif_cond.block ]
 |  |  | el = el.as.elif_cond.next_elif
 |  |  \_
 |  |
 |  | IF [ cond.as.cond.else_part != 0 ]
 |  |  | (ck_block)[ c | cond.as.cond.else_part.as.else_cond.block ]
 |  |  \_
 |  | RET
 |  \_
 |
 | IF [ k == ST_LOOP ]
 |  | @ASTNode lp = st.as.stmt.stmt
 |  | IF [ lp.as.loop.expr != 0 ]
 |  |  | (ck_cond_expr)[ c | lp.as.loop.expr | "WHILE" ]
 |  |  \_
 |  | (ck_block)[ c | lp.as.loop.block ]
 |  | RET
 |  \_
 |
 | IF [ k == ST_EXPR ]
 |  | (ck_expr)[ c | st.as.stmt.stmt ]
 |  | RET
 |  \_
 |
 | RET
 \_

ABYSS ck_block: [ @Checker c | @ASTNode blk ]
 | IF [ blk == 0 ]
 |  | RET
 |  \_
 | (ck_push)[ c ]
 | @ASTNode s = blk.as.block.stmts
 | WHILE [ s != 0 ]
 |  | (ck_stmt)[ c | s ]
 |  | s = s.as.stmt.next_stmt
 |  \_
 | (ck_pop)[ c ]
 | RET
 \_

ABYSS ck_fn: [ @Checker c | @ASTNode def ]
 | @ASTNode decl = def.as.fn_def.decl
 | c.ret_type = (ty_resolve)[ c | decl.as.fn_decl.type ]
 |
 | (ck_push)[ c ]
 | @ASTNode p = decl.as.fn_decl.params
 | WHILE [ p != 0 ]
 |  | IF [ !(p.as.parametre.vaarg) ]
 |  |  | @C1 pn = p.as.parametre.ident.as.ident
 |  |  | (ck_define)[ c | pn | (ty_resolve)[ c | p.as.parametre.type ] ]
 |  |  \_
 |  | p = p.as.parametre.next_param
 |  \_
 |
 | (ck_block)[ c | def.as.fn_def.block ]
 | (ck_pop)[ c ]
 | RET
 \_

; --- entry point ----------------------------------------------------------

ABYSS check_init: [ @Checker c | @Meta m ]
 | c.meta = m
 | c.scope = 0
 | c.errors = 0
 | c.tu = 0
 | c.ret_type = (ty_void)[]
 | RET
 \_

B1 check_unit: [ @Checker c | @ASTNode root ]
 | c.tu = root
 | (ck_push)[ c ]
 |
 | ; globals first, so every function can see them
 | @ASTNode ts = root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | IF [ ts.as.tu_stmt.kind == TUST_VAR_DECL ]
 |  |  | @ASTNode d = ts.as.tu_stmt.tu_stmt
 |  |  | @C1 nm = d.as.var_decl.ident.as.ident
 |  |  | (ck_define)[ c | nm | (ty_resolve)[ c | d.as.var_decl.type ] ]
 |  |  \_
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 |
 | ts = root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | IF [ ts.as.tu_stmt.kind == TUST_FN_DEF ]
 |  |  | (ck_fn)[ c | ts.as.tu_stmt.tu_stmt ]
 |  |  \_
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 |
 | (ck_pop)[ c ]
 |
 | IF [ c.errors > 0 ]
 |  | (printf)[ "%d type error(s)\n" | c.errors ]
 |  | RET [ FALSE ]
 |  \_
 | RET [ TRUE ]
 \_

ABYSS check_deinit: [ @Checker c ]
 | WHILE [ c.scope != 0 ]
 |  | (ck_pop)[ c ]
 |  \_
 | RET
 \_
