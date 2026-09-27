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
;   * float arithmetic reaching LLVM as `sdiv double` -- floats have their
;     own opcodes now; what is rejected is a bitwise operator on one
;
; Each of those is now an error here, with a line and column.

!USES <ast.pl>
!USES <meta.pl>
!USES <diag.pl>
!USES <generic.pl>
!USES <../lib/string.pl>
!USES <../lib/vector.pl>
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
 | TY_FN               ; a function pointer; decl is its signature
 \_

TYPE Type: STRUCT
 | I32      kind
 | U64      ptrs       ; pointer depth
 | I32      bits       ; width for TY_INT and TY_FLOAT
 | B1       sign       ; TY_INT only
 | @C1      name       ; TY_RECORD / TY_ENUM
 | @ASTNode decl       ; the NT_TYPE_DEF, for field lookup
 | U64      arr        ; N for an array `T x{N}`, which reads as a pointer
 \_

TYPE CkSym: STRUCT
 | @C1      name
 | Type     ty
 | @ASTNode decl       ; where it is declared, for the index
 \_

TYPE CkScope: STRUCT
 | Vector<CkSym> syms
 | @CkScope  parent
 \_

TYPE Checker: STRUCT
 | @Meta     meta
 | @CkScope  scope
 | Type      ret_type     ; of the function being checked
 | @ASTNode  tu           ; the translation unit, for enum lookup
 | @C1       owner        ; the class whose method is being checked, or 0
 | I32       loops        ; how many loops enclose the statement being checked
 | I32       errors
 | @Index    ix           ; where resolved names are noted, or 0
 \_

; --- the index ------------------------------------------------------------
;
; For the language server: every name the checker resolves, and the
; declaration it resolved to. Only filled when Checker.ix is set.

TYPE IxRef: STRUCT
 | @ASTNode use          ; the NT_IDENT as written
 | @ASTNode decl         ; NT_VAR_DECL, NT_PARAMETRE, NT_FIELD, NT_FN_DECL, NT_TYPE_DEF or NT_ENUM_FIELDS
 | @ASTNode owner        ; the NT_TYPE_DEF a field or an enum constant is in, or 0
 \_

TYPE Index: STRUCT
 | Vector<IxRef> refs
 \_

ABYSS ix_add: [ @Index ix | @ASTNode use | @ASTNode decl | @ASTNode owner ]
 | IF [ ix == 0 || use == 0 || decl == 0 ]
 |  | RET
 |  \_
 | IxRef r
 | r.use = use
 | r.decl = decl
 | r.owner = owner
 | (ix.refs.push)[ r ]
 | RET
 \_

ABYSS ck_ref: [ @Checker c | @ASTNode use | @ASTNode decl | @ASTNode owner ]
 | (ix_add)[ c.ix | use | decl | owner ]
 | RET
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
 | t.arr = 0
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
 | RET [ t.kind == TY_INT || t.kind == TY_BOOL || t.kind == TY_ENUM || t.kind == TY_FLOAT || t.kind == TY_FN ]
 \_

B1 ty_is_aggregate: [ Type t ]
 | RET [ t.ptrs == 0 && t.kind == TY_RECORD ]
 \_

ABYSS append_sig: [ @String s | @ASTNode sig ]

; A declared type as written, for diagnostics.
ABYSS append_tn: [ @String s | @ASTNode tn ]
 | IF [ tn == 0 ]
 |  | (str_append_str)[ s | "?" ]
 |  | RET
 |  \_
 | U64 i = 0
 | WHILE [ i < tn.as.type.ptrs ]
 |  | (str_append)[ s | '@' ]
 |  | i = i + 1
 |  \_
 | IF [ tn.as.type.kind == TT_BASE_TYPE ]
 |  | (str_append_str)[ s | (base_type_name)[ tn.as.type.type.as.base_type ] ]
 | ELIF [ tn.as.type.kind == TT_FN_TYPE ]
 |  | (append_sig)[ s | tn ]
 | ELSE
 |  | (str_append_str)[ s | tn.as.type.type.as.ident ]
 |  \_
 | RET
 \_

ABYSS append_sig: [ @String s | @ASTNode sig ]
 | (str_append_str)[ s | "FN " ]
 | (append_tn)[ s | (sig_ret)[ sig ] ]
 | (str_append_str)[ s | " [" ]
 | @ASTNode p = (sig_params)[ sig ]
 | WHILE [ p != 0 ]
 |  | (str_append)[ s | ' ' ]
 |  | IF [ (sig_is_va)[ p ] ]
 |  |  | (str_append_str)[ s | "..." ]
 |  | ELSE
 |  |  | (append_tn)[ s | (sig_ptype)[ p ] ]
 |  |  \_
 |  | p = (sig_next)[ p ]
 |  | IF [ p != 0 ]
 |  |  | (str_append_str)[ s | " |" ]
 |  |  \_
 |  \_
 | (str_append_str)[ s | " ]" ]
 | RET
 \_

; A short spelling, for diagnostics. Caller owns nothing; the buffer is
; reused, so print it before building another.
@C1 ty_str: [ Type t ]
 | @C1 buf = (malloc)[ 256 ] AS @C1
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
 | ELIF [ t.kind == TY_FN ]
 |  | ; the whole signature: FN I32 [ I32 | @C1 ]
 |  | String sig
 |  | (str_init_cstr)[ @sig | "" ]
 |  | (append_sig)[ @sig | t.decl ]
 |  | base = sig.data
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
 | (snprintf)[ buf | 256 | "%s%s" | stars | base ]
 | RET [ buf ]
 \_

ABYSS ck_error: [ @Checker c | @ASTNode at | @C1 msg ]
 | (diag_at)[ at.loc | msg ]
 | c.errors = c.errors + 1
 | RET
 \_

ABYSS ck_error2: [ @Checker c | @ASTNode at | @C1 fmt | @C1 a | @C1 b ]
 | (diag_at2)[ at.loc | fmt | a | b ]
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
 | IF [ tn.as.type.kind == TT_FN_TYPE ]
 |  | t = (ty_make)[ TY_FN | tn.as.type.ptrs | 64 | FALSE ]
 |  | t.decl = tn
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
 |  |  | ; an alias of a struct is that struct: keep the definition that
 |  |  | ; has the fields, and the name its methods are filed under
 |  |  | IF [ t.decl == 0 ]
 |  |  |  | t.name = nm
 |  |  |  | t.decl = td
 |  |  |  \_
 |  | ELSE
 |  |  | (ck_error2)[ c | tn | "unknown type `%s`%s" | nm | "" ]
 |  |  \_
 |  \_
 |
 | t.ptrs = t.ptrs + tn.as.type.ptrs
 | RET [ t ]
 \_

; The type a declared variable or field has in an expression: an array
; `T x{N}` is used as a pointer to its first element, like C's.
Type ty_decl: [ @Checker c | @ASTNode tn ]
 | Type t = (ty_resolve)[ c | tn ]
 | IF [ tn != 0 && tn.as.type.arr > 0 ]
 |  | t.ptrs = t.ptrs + 1
 |  | t.arr = tn.as.type.arr
 |  \_
 | RET [ t ]
 \_

B1 ty_is_float: [ Type t ]
 | RET [ t.ptrs == 0 && t.kind == TY_FLOAT ]
 \_

B1 ty_is_integral: [ Type t ]
 | RET [ t.ptrs == 0 && (t.kind == TY_INT || t.kind == TY_BOOL || t.kind == TY_ENUM) ]
 \_

; --- scopes ---------------------------------------------------------------

ABYSS ck_push: [ @Checker c ]
 | @CkScope s = (malloc)[ SIZE [ CkScope ] ] AS @CkScope
 | (s.syms.init)[ 16 ]
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
 | (s.syms.deinit)[]
 | (free)[ s AS @ABYSS ]
 | RET
 \_

B1 ck_declared_here: [ @Checker c | @C1 name ]
 | U64 i = 0
 | WHILE [ i < (c.scope.syms.size)[] ]
 |  | @CkSym s = (c.scope.syms.at)[ i ]
 |  | IF [ (strcmp)[ s.name | name ] == 0 ]
 |  |  | RET [ TRUE ]
 |  |  \_
 |  | i = i + 1
 |  \_
 | RET [ FALSE ]
 \_

ABYSS ck_define: [ @Checker c | @C1 name | Type t | @ASTNode decl ]
 | CkSym s
 | s.name = name
 | s.ty = t
 | s.decl = decl
 | (c.scope.syms.push)[ s ]
 | RET
 \_

; The innermost variable of that name, or 0. Valid until the next define.
@CkSym ck_find: [ @Checker c | @C1 name ]
 | @CkScope s = c.scope
 | WHILE [ s != 0 ]
 |  | U64 n = (s.syms.size)[]
 |  | U64 i = n
 |  | WHILE [ i > 0 ]
 |  |  | i = i - 1
 |  |  | @CkSym sym = (s.syms.at)[ i ]
 |  |  | IF [ (strcmp)[ sym.name | name ] == 0 ]
 |  |  |  | RET [ sym ]
 |  |  |  \_
 |  |  \_
 |  | s = s.parent
 |  \_
 | RET [ NULL ]
 \_

B1 ck_lookup: [ @Checker c | @C1 name | @Type out ]
 | @CkSym sym = (ck_find)[ c | name ]
 | IF [ sym == NULL ]
 |  | RET [ FALSE ]
 |  \_
 | ?(out) = sym.ty
 | RET [ TRUE ]
 \_

; --- assignability --------------------------------------------------------
;
; Deliberately permissive where PLUM's implicit coercion already is --
; integer widths convert, pointers convert to one another -- and strict
; where silence was costing correctness: aggregates convert to nothing.

B1 ty_same: [ @Checker c | Type a | Type b ]

; Two signatures agree when their return and parameter types are the same
; and both or neither are variadic.
B1 sig_same: [ @Checker c | @ASTNode a | @ASTNode b ]
 | IF [ !(ty_same)[ c | (ty_resolve)[ c | (sig_ret)[ a ] ] | (ty_resolve)[ c | (sig_ret)[ b ] ] ] ]
 |  | RET [ FALSE ]
 |  \_
 | @ASTNode p = (sig_params)[ a ]
 | @ASTNode q = (sig_params)[ b ]
 | WHILE [ p != 0 && q != 0 ]
 |  | IF [ (sig_is_va)[ p ] || (sig_is_va)[ q ] ]
 |  |  | RET [ (sig_is_va)[ p ] && (sig_is_va)[ q ] ]
 |  |  \_
 |  | IF [ !(ty_same)[ c | (ty_resolve)[ c | (sig_ptype)[ p ] ] | (ty_resolve)[ c | (sig_ptype)[ q ] ] ] ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | p = (sig_next)[ p ]
 |  | q = (sig_next)[ q ]
 |  \_
 | RET [ p == 0 && q == 0 ]
 \_

B1 ty_same: [ @Checker c | Type a | Type b ]
 | IF [ a.kind == TY_UNKNOWN || b.kind == TY_UNKNOWN ]
 |  | RET [ TRUE ]
 |  \_
 | IF [ a.kind != b.kind || a.ptrs != b.ptrs ]
 |  | RET [ FALSE ]
 |  \_
 | IF [ a.kind == TY_INT ]
 |  | RET [ a.bits == b.bits && a.sign == b.sign ]
 |  \_
 | IF [ a.kind == TY_FLOAT ]
 |  | RET [ a.bits == b.bits ]
 |  \_
 | IF [ a.kind == TY_RECORD || a.kind == TY_ENUM ]
 |  | IF [ a.name == 0 || b.name == 0 ]
 |  |  | RET [ TRUE ]
 |  |  \_
 |  | RET [ (strcmp)[ a.name | b.name ] == 0 ]
 |  \_
 | IF [ a.kind == TY_FN ]
 |  | RET [ (sig_same)[ c | a.decl | b.decl ] ]
 |  \_
 | RET [ TRUE ]
 \_

B1 ty_assignable: [ @Checker c | Type to | Type from ]
 | IF [ to.kind == TY_UNKNOWN || from.kind == TY_UNKNOWN ]
 |  | RET [ TRUE ]
 |  \_
 |
 | ; a function pointer takes a function of exactly its signature, or NULL
 | IF [ to.kind == TY_FN && to.ptrs == 0 ]
 |  | IF [ from.kind == TY_FN && from.ptrs == 0 ]
 |  |  | RET [ (sig_same)[ c | to.decl | from.decl ] ]
 |  |  \_
 |  | RET [ from.ptrs == 0 && from.kind == TY_INT ]
 |  \_
 | IF [ from.kind == TY_FN && from.ptrs == 0 ]
 |  | ; only as far as an opaque @ABYSS, like C's void *
 |  | RET [ to.kind == TY_VOID && to.ptrs > 0 ]
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

; An operand, which must have a value: an ABYSS call has none.
Type ck_value: [ @Checker c | @ASTNode e ]
 | Type t = (ck_expr)[ c | e ]
 | IF [ t.kind == TY_VOID && t.ptrs == 0 ]
 |  | (ck_error)[ c | e | "an ABYSS call has no value to use here" ]
 |  | RET [ (ty_unknown)[] ]
 |  \_
 | RET [ t ]
 \_

; Something with an address: what `=` can store to and `@` can point at.
B1 ck_is_place: [ @Checker c | @ASTNode e ]
 | @ASTNode n = (ck_strip)[ e ]
 | IF [ n == 0 ]
 |  | RET [ FALSE ]
 |  \_
 | IF [ n.kind == NT_IDENT ]
 |  | Type vt = (ty_unknown)[]
 |  | RET [ (ck_lookup)[ c | n.as.ident | @vt ] ]
 |  \_
 | IF [ n.kind == NT_UNY_OP ]
 |  | RET [ n.as.uny_op.kind == UOT_DEREF ]
 |  \_
 | IF [ n.kind == NT_BIN_OP ]
 |  | RET [ n.as.bin_op.kind == BOT_MEMBER || n.as.bin_op.kind == BOT_INDEX ]
 |  \_
 | RET [ FALSE ]
 \_

; The NT_FIELD named `field` in a record type, or 0.
@ASTNode ck_field_decl: [ Type base | @C1 field ]
 | IF [ base.decl == 0 ]
 |  | RET [ NULL ]
 |  \_
 | @ASTNode rec = base.decl.as.type_def.tdef
 | @ASTNode f = rec.as.record.fields
 | WHILE [ f != 0 ]
 |  | IF [ (strcmp)[ f.as.rcrd_flds.ident.as.ident | field ] == 0 ]
 |  |  | RET [ f ]
 |  |  \_
 |  | f = f.as.rcrd_flds.next_field
 |  \_
 | RET [ NULL ]
 \_

; `use` is the field's name as written, noted in the index.
B1 ck_field: [ @Checker c | Type base | @C1 field | @Type out | @ASTNode use ]
 | @ASTNode f = (ck_field_decl)[ base | field ]
 | IF [ f == NULL ]
 |  | RET [ FALSE ]
 |  \_
 | (ck_ref)[ c | use | f | base.decl ]
 | ?(out) = (ty_decl)[ c | f.as.rcrd_flds.type ]
 | RET [ TRUE ]
 \_

; The signature behind a function-pointer value, or 0 with an error.
@ASTNode ck_fn_value: [ @Checker c | @ASTNode at | Type t ]
 | IF [ t.kind == TY_UNKNOWN ]
 |  | RET [ 0 ]
 |  \_
 | IF [ t.kind != TY_FN || t.ptrs != 0 ]
 |  | @C1 s = (ty_str)[ t ]
 |  | (ck_error2)[ c | at | "%s is not a function, so it cannot be called%s" | s | "" ]
 |  | (free)[ s AS @ABYSS ]
 |  | RET [ 0 ]
 |  \_
 | RET [ t.decl ]
 \_

; What a call goes through -- an NT_FN_DECL or an FN type -- or 0 once an
; error is reported. skip_me is set for a method, whose `me` the call
; supplies itself.
;
;   (name)[ ... ]      a variable holding a function pointer, else the function
;   (obj.name)[ ... ]  the method "<obj's type>.name", else a pointer field
;   (expr)[ ... ]      whatever function pointer expr yields
@ASTNode ck_callee: [ @Checker c | @ASTNode n | @B1 skip_me ]
 | ?(skip_me) = FALSE
 |
 | IF [ n.as.fn_call.ident == 0 ]
 |  | RET [ (ck_fn_value)[ c | n | (ck_expr)[ c | n.as.fn_call.target ] ] ]
 |  \_
 | @C1 m = n.as.fn_call.ident.as.ident
 |
 | IF [ n.as.fn_call.recv == 0 ]
 |  | @CkSym vs = (ck_find)[ c | m ]
 |  | IF [ vs != NULL && vs.ty.kind == TY_FN && vs.ty.ptrs == 0 ]
 |  |  | (ck_ref)[ c | n.as.fn_call.ident | vs.decl | 0 ]
 |  |  | RET [ vs.ty.decl ]
 |  |  \_
 |  | @ABYSS d = 0
 |  | IF [ (map_get)[ @(c.meta.func_decls) | m | @d AS @@ABYSS ] != 1 ]
 |  |  | (ck_error2)[ c | n | "call to undeclared function `%s`%s" | m | "" ]
 |  |  | RET [ 0 ]
 |  |  \_
 |  | (ck_ref)[ c | n.as.fn_call.ident | d AS @ASTNode | 0 ]
 |  | RET [ d AS @ASTNode ]
 |  \_
 |
 | Type rt = (ck_expr)[ c | n.as.fn_call.recv ]
 | IF [ rt.kind == TY_UNKNOWN ]
 |  | RET [ 0 ]
 |  \_
 | IF [ rt.kind != TY_RECORD || rt.ptrs > 1 || rt.name == 0 ]
 |  | @C1 s = (ty_str)[ rt ]
 |  | (ck_error2)[ c | n | "%s has no methods, so no `%s`" | s | m ]
 |  | (free)[ s AS @ABYSS ]
 |  | RET [ 0 ]
 |  \_
 |
 | @ABYSS d = 0
 | IF [ (map_get)[ @(c.meta.func_decls) | (method_name)[ rt.name | m ] | @d AS @@ABYSS ] == 1 ]
 |  | @ASTNode decl = d AS @ASTNode
 |  | IF [ decl.as.fn_decl.is_private ]
 |  |  | IF [ c.owner == 0 || (strcmp)[ c.owner | decl.as.fn_decl.owner ] != 0 ]
 |  |  |  | (ck_error2)[ c | n | "`%s` is PRIVATE to `%s`" | m | decl.as.fn_decl.owner ]
 |  |  |  \_
 |  |  \_
 |  | (ck_ref)[ c | n.as.fn_call.ident | decl | 0 ]
 |  | ?(skip_me) = TRUE
 |  | RET [ decl ]
 |  \_
 |
 | Type obj = rt
 | obj.ptrs = 0
 | Type ft = (ty_unknown)[]
 | IF [ (ck_field)[ c | obj | m | @ft | n.as.fn_call.ident ] ]
 |  | RET [ (ck_fn_value)[ c | n | ft ] ]
 |  \_
 | (ck_error2)[ c | n | "`%s` has no method or field `%s`" | rt.name | m ]
 | RET [ 0 ]
 \_

Type ck_call: [ @Checker c | @ASTNode n ]
 | @C1 name = "this function pointer"
 | IF [ n.as.fn_call.ident != 0 ]
 |  | name = n.as.fn_call.ident.as.ident
 |  \_
 |
 | B1 skip_me = FALSE
 | @ASTNode sig = (ck_callee)[ c | n | @skip_me ]
 | IF [ sig == 0 ]
 |  | @ASTNode x = n.as.fn_call.args
 |  | WHILE [ x != 0 ]
 |  |  | (ck_expr)[ c | x.as.argument.argument ]
 |  |  | x = x.as.argument.next_arg
 |  |  \_
 |  | RET [ (ty_unknown)[] ]
 |  \_
 |
 | @ASTNode params = (sig_params)[ sig ]
 | IF [ skip_me ]
 |  | params = (sig_next)[ params ]
 |  \_
 |
 | ; count declared parameters, and note whether it is variadic
 | I32 want = 0
 | B1 va = FALSE
 | @ASTNode p = params
 | WHILE [ p != 0 ]
 |  | IF [ (sig_is_va)[ p ] ]
 |  |  | va = TRUE
 |  | ELSE
 |  |  | want = want + 1
 |  |  \_
 |  | p = (sig_next)[ p ]
 |  \_
 |
 | ; walk the arguments against them
 | I32 got = 0
 | p = params
 | @ASTNode a = n.as.fn_call.args
 | WHILE [ a != 0 ]
 |  | Type at = (ck_value)[ c | a.as.argument.argument ]
 |  |
 |  | IF [ p != 0 && !(sig_is_va)[ p ] ]
 |  |  | Type pt = (ty_resolve)[ c | (sig_ptype)[ p ] ]
 |  |  | IF [ !(ty_assignable)[ c | pt | at ] ]
 |  |  |  | @C1 sw = (ty_str)[ pt ]
 |  |  |  | @C1 sg = (ty_str)[ at ]
 |  |  |  | (ck_error2)[ c | a | "argument expects %s, got %s" | sw | sg ]
 |  |  |  | (free)[ sw AS @ABYSS ]
 |  |  |  | (free)[ sg AS @ABYSS ]
 |  |  |  \_
 |  |  | p = (sig_next)[ p ]
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
 | RET [ (ty_resolve)[ c | (sig_ret)[ sig ] ] ]
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
 |  | IF [ base.arr > 0 ]
 |  |  | (ck_error)[ c | n | "`.` applied to an array; index it first, as in a{0}.field" ]
 |  |  | RET [ (ty_unknown)[] ]
 |  |  \_
 |  |
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
 |  | IF [ !(ck_field)[ c | obj | fn.as.ident | @ft | fn ] ]
 |  |  | (ck_error2)[ c | n | "no field `%s` in `%s`" | fn.as.ident | obj.name ]
 |  |  | RET [ (ty_unknown)[] ]
 |  |  \_
 |  | RET [ ft ]
 |  \_
 |
 | Type lt = (ck_value)[ c | n.as.bin_op.left ]
 | Type rt = (ck_value)[ c | n.as.bin_op.right ]
 |
 | ; x{i}: x an array or a pointer, i an integer
 | IF [ k == BOT_INDEX ]
 |  | IF [ rt.kind != TY_UNKNOWN && !(ty_is_integral)[ rt ] ]
 |  |  | @C1 si = (ty_str)[ rt ]
 |  |  | (ck_error2)[ c | n | "an index must be an integer, not %s%s" | si | "" ]
 |  |  | (free)[ si AS @ABYSS ]
 |  |  \_
 |  | IF [ lt.kind == TY_UNKNOWN ]
 |  |  | RET [ lt ]
 |  |  \_
 |  | IF [ lt.ptrs == 0 ]
 |  |  | @C1 sl = (ty_str)[ lt ]
 |  |  | (ck_error2)[ c | n | "cannot index %s: it is neither an array nor a pointer%s" | sl | "" ]
 |  |  | (free)[ sl AS @ABYSS ]
 |  |  | RET [ (ty_unknown)[] ]
 |  |  \_
 |  | IF [ lt.ptrs == 1 && lt.kind == TY_VOID ]
 |  |  | (ck_error)[ c | n | "cannot index @ABYSS; cast it to a typed pointer first" ]
 |  |  | RET [ (ty_unknown)[] ]
 |  |  \_
 |  | lt.ptrs = lt.ptrs - 1
 |  | lt.arr = 0
 |  | RET [ lt ]
 |  \_
 |
 | IF [ k == BOT_ASSIGN ]
 |  | IF [ !(ck_is_place)[ c | n.as.bin_op.left ] ]
 |  |  | (ck_error)[ c | n | "the left side of `=` is not a variable, a field, an element or ?pointer" ]
 |  |  | RET [ lt ]
 |  |  \_
 |  | IF [ lt.arr > 0 ]
 |  |  | (ck_error)[ c | n | "cannot assign to a whole array; assign its elements" ]
 |  |  | RET [ lt ]
 |  |  \_
 |  | IF [ !(ty_assignable)[ c | lt | rt ] ]
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
 | lt.arr = 0
 | rt.arr = 0
 |
 | ; floats: + - * / % and comparisons, which were handled above
 | IF [ (ty_is_float)[ lt ] || (ty_is_float)[ rt ] ]
 |  | B1 bitwise = k == BOT_BAND || k == BOT_BOR || k == BOT_BXOR
 |  | IF [ bitwise || k == BOT_SHL || k == BOT_SHR ]
 |  |  | (ck_error)[ c | n | "bitwise operator on a float" ]
 |  |  | RET [ (ty_unknown)[] ]
 |  |  \_
 |  | IF [ lt.ptrs > 0 || rt.ptrs > 0 ]
 |  |  | (ck_error)[ c | n | "pointer arithmetic needs an integer, not a float" ]
 |  |  | RET [ (ty_unknown)[] ]
 |  |  \_
 |  | ; the wider float wins; an integer operand is converted
 |  | IF [ !(ty_is_float)[ lt ] ]
 |  |  | RET [ rt ]
 |  |  \_
 |  | IF [ (ty_is_float)[ rt ] && rt.bits > lt.bits ]
 |  |  | RET [ rt ]
 |  |  \_
 |  | RET [ lt ]
 |  \_
 |
 | ; pointers: p + n and n + p move by whole elements, p - q counts them
 | IF [ lt.ptrs > 0 || rt.ptrs > 0 ]
 |  | B1 lp = lt.ptrs > 0
 |  | B1 rp = rt.ptrs > 0
 |  | IF [ k == BOT_MINUS && lp && rp ]
 |  |  | IF [ !(ty_same)[ c | lt | rt ] ]
 |  |  |  | @C1 sl = (ty_str)[ lt ]
 |  |  |  | @C1 sr = (ty_str)[ rt ]
 |  |  |  | (ck_error2)[ c | n | "cannot subtract %s from %s" | sr | sl ]
 |  |  |  | (free)[ sl AS @ABYSS ]
 |  |  |  | (free)[ sr AS @ABYSS ]
 |  |  |  \_
 |  |  | RET [ (ty_int)[ 64 | TRUE ] ]
 |  |  \_
 |  | IF [ k == BOT_PLUS && lp && !rp ]
 |  |  | RET [ lt ]
 |  |  \_
 |  | IF [ k == BOT_PLUS && rp && !lp ]
 |  |  | RET [ rt ]
 |  |  \_
 |  | IF [ k == BOT_MINUS && lp && !rp ]
 |  |  | RET [ lt ]
 |  |  \_
 |  | (ck_error)[ c | n | "on pointers only p + n, n + p, p - n and p - q are defined; cast to U64 for the rest" ]
 |  | RET [ (ty_unknown)[] ]
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
 |  |  | I64 v = n.as.literal.as.int_lit
 |  |  | IF [ v < -2147483648 || v > 2147483647 ]
 |  |  |  | RET [ (ty_int)[ 64 | TRUE ] ]
 |  |  |  \_
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
 |  | @CkSym sym = (ck_find)[ c | n.as.ident ]
 |  | IF [ sym != NULL ]
 |  |  | (ck_ref)[ c | n | sym.decl | 0 ]
 |  |  | RET [ sym.ty ]
 |  |  \_
 |  | ; an enum constant is an I32; meta has the type table
 |  | @ASTNode en = 0
 |  | @ASTNode ec = (ck_enum_const)[ c | n.as.ident | @en ]
 |  | IF [ ec != NULL ]
 |  |  | (ck_ref)[ c | n | ec | en ]
 |  |  | RET [ (ty_int)[ 32 | TRUE ] ]
 |  |  \_
 |  | ; a function's name is a pointer to it
 |  | @ABYSS fd = 0
 |  | IF [ (map_get)[ @(c.meta.func_decls) | n.as.ident | @fd AS @@ABYSS ] == 1 ]
 |  |  | (ck_ref)[ c | n | fd AS @ASTNode | 0 ]
 |  |  | Type ft = (ty_make)[ TY_FN | 0 | 64 | FALSE ]
 |  |  | ft.decl = fd AS @ASTNode
 |  |  | RET [ ft ]
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
 |  | Type from = (ck_value)[ c | n.as.cast.expr ]
 |  | Type to = (ty_resolve)[ c | n.as.cast.type ]
 |  | IF [ (ty_is_aggregate)[ from ] || (ty_is_aggregate)[ to ] ]
 |  |  | (ck_error)[ c | n | "AS converts scalars and pointers; a struct cannot be cast" ]
 |  |  \_
 |  | RET [ to ]
 |  \_
 |
 | IF [ n.kind == NT_BUILTIN ]
 |  | Type st = (ty_resolve)[ c | n.as.builtin.size ]
 |  | IF [ st.kind == TY_VOID && st.ptrs == 0 ]
 |  |  | (ck_error)[ c | n | "ABYSS has no size" ]
 |  |  \_
 |  | RET [ (ty_int)[ 64 | FALSE ] ]
 |  \_
 |
 | IF [ n.kind == NT_UNY_OP ]
 |  | I32 uk = n.as.uny_op.kind
 |  | Type t = (ck_value)[ c | n.as.uny_op.operand ]
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
 |  |  | IF [ t.ptrs == 1 && t.kind == TY_VOID ]
 |  |  |  | (ck_error)[ c | n | "cannot dereference @ABYSS; cast it to a typed pointer first" ]
 |  |  |  | RET [ (ty_unknown)[] ]
 |  |  |  \_
 |  |  | t.ptrs = t.ptrs - 1
 |  |  | t.arr = 0
 |  |  | RET [ t ]
 |  |  \_
 |  |
 |  | IF [ uk == UOT_REF ]
 |  |  | IF [ t.kind == TY_UNKNOWN ]
 |  |  |  | RET [ t ]
 |  |  |  \_
 |  |  | IF [ t.kind != TY_FN && !(ck_is_place)[ c | n.as.uny_op.operand ] ]
 |  |  |  | (ck_error)[ c | n | "cannot take the address of a value that is not stored anywhere" ]
 |  |  |  | RET [ (ty_unknown)[] ]
 |  |  |  \_
 |  |  | ; @f of a function f: its name already is its address
 |  |  | @ASTNode on = (ck_strip)[ n.as.uny_op.operand ]
 |  |  | Type vt = (ty_unknown)[]
 |  |  | IF [ t.kind == TY_FN && on.kind == NT_IDENT && !(ck_lookup)[ c | on.as.ident | @vt ] ]
 |  |  |  | (ck_error2)[ c | n | "`@%s`: a function's name alone is already its address%s" | on.as.ident | "" ]
 |  |  |  | RET [ t ]
 |  |  |  \_
 |  |  | ; an array already reads as the address of its first element
 |  |  | IF [ t.arr > 0 ]
 |  |  |  | t.arr = 0
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
 |  | IF [ uk == UOT_BNOT && (ty_is_float)[ t ] ]
 |  |  | (ck_error)[ c | n | "bitwise operator on a float" ]
 |  |  \_
 |  | IF [ t.ptrs > 0 || t.kind == TY_FN ]
 |  |  | (ck_error)[ c | n | "`-` and `~` do not apply to pointers" ]
 |  |  \_
 |  | t.arr = 0
 |  | RET [ t ]
 |  \_
 |
 | RET [ (ty_unknown)[] ]
 \_

; The NT_ENUM_FIELDS of the constant `name`, with its enum put in `owner`;
; 0 when there is none.
@ASTNode ck_enum_const: [ @Checker c | @C1 name | @@ASTNode owner ]
 | ; enum constants are not in meta by name, so scan the type definitions
 | @ASTNode ts = c.tu.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | IF [ ts.as.tu_stmt.kind == TUST_TYPE_DEF ]
 |  |  | @ASTNode td = ts.as.tu_stmt.tu_stmt
 |  |  | IF [ td.as.type_def.kind == TD_ENUM ]
 |  |  |  | @ASTNode f = td.as.type_def.tdef.as.enumeration.fields
 |  |  |  | WHILE [ f != 0 ]
 |  |  |  |  | IF [ (strcmp)[ f.as.enum_flds.ident.as.ident | name ] == 0 ]
 |  |  |  |  |  | ?(owner) = td
 |  |  |  |  |  | RET [ f ]
 |  |  |  |  |  \_
 |  |  |  |  | f = f.as.enum_flds.next_field
 |  |  |  |  \_
 |  |  |  \_
 |  |  \_
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 | RET [ NULL ]
 \_

; --- statements -----------------------------------------------------------

ABYSS ck_block: [ @Checker c | @ASTNode blk ]

ABYSS ck_cond_expr: [ @Checker c | @ASTNode e | @C1 what ]
 | Type t = (ck_value)[ c | e ]
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
 |  | Type dt = (ty_decl)[ c | d.as.var_decl.type ]
 |  |
 |  | IF [ dt.kind == TY_VOID && dt.ptrs == 0 ]
 |  |  | (ck_error2)[ c | d | "`%s` cannot have type ABYSS%s" | nm | "" ]
 |  |  \_
 |  | IF [ (ck_declared_here)[ c | nm ] ]
 |  |  | (ck_error2)[ c | d | "`%s` is already declared in this scope%s" | nm | "" ]
 |  |  \_
 |  |
 |  | IF [ d.as.var_decl.init != 0 && dt.arr > 0 ]
 |  |  | (ck_error2)[ c | d | "array `%s` cannot have an initialiser; assign its elements%s" | nm | "" ]
 |  |  | (ck_define)[ c | nm | dt | d ]
 |  |  | RET
 |  |  \_
 |  |
 |  | IF [ d.as.var_decl.init != 0 ]
 |  |  | Type it = (ck_expr)[ c | d.as.var_decl.init ]
 |  |  | IF [ !(ty_assignable)[ c | dt | it ] ]
 |  |  |  | @C1 sd = (ty_str)[ dt ]
 |  |  |  | @C1 si = (ty_str)[ it ]
 |  |  |  | (ck_error2)[ c | d | "cannot initialise %s from %s" | sd | si ]
 |  |  |  | (free)[ sd AS @ABYSS ]
 |  |  |  | (free)[ si AS @ABYSS ]
 |  |  |  \_
 |  |  \_
 |  |
 |  | (ck_define)[ c | nm | dt | d ]
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
 |  | ELIF [ !(ty_assignable)[ c | c.ret_type | rt ] ]
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
 |  | c.loops = c.loops + 1
 |  | (ck_block)[ c | lp.as.loop.block ]
 |  | c.loops = c.loops - 1
 |  | RET
 |  \_
 |
 | IF [ k == ST_BREAK || k == ST_CONTINUE ]
 |  | IF [ c.loops == 0 ]
 |  |  | @C1 what = "BREAK"
 |  |  | IF [ k == ST_CONTINUE ]
 |  |  |  | what = "CONTINUE"
 |  |  |  \_
 |  |  | (ck_error2)[ c | st | "%s outside of a loop%s" | what | "" ]
 |  |  \_
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

; --- reaching the end of a function ---------------------------------------
;
; A function that returns a value must not fall off its end: codegen would
; quietly return 0. These decide, conservatively, whether control can.

B1 block_ends: [ @ASTNode blk ]

; C functions that never return
B1 is_noreturn_call: [ @ASTNode e ]
 | @ASTNode n = (ck_strip)[ e ]
 | IF [ n == 0 || n.kind != NT_FN_CALL || n.as.fn_call.ident == 0 || n.as.fn_call.recv != 0 ]
 |  | RET [ FALSE ]
 |  \_
 | @C1 nm = n.as.fn_call.ident.as.ident
 | RET [ (strcmp)[ nm | "exit" ] == 0 || (strcmp)[ nm | "abort" ] == 0 || (strcmp)[ nm | "_exit" ] == 0 ]
 \_

; Is there a BREAK that leaves this loop -- not one of a loop inside it?
B1 has_break: [ @ASTNode blk ]
 | IF [ blk == 0 ]
 |  | RET [ FALSE ]
 |  \_
 | @ASTNode s = blk.as.block.stmts
 | WHILE [ s != 0 ]
 |  | I32 k = s.as.stmt.kind
 |  | IF [ k == ST_BREAK ]
 |  |  | RET [ TRUE ]
 |  |  \_
 |  | IF [ k == ST_COND ]
 |  |  | @ASTNode cond = s.as.stmt.stmt
 |  |  | IF [ (has_break)[ cond.as.cond.if_part.as.if_cond.block ] ]
 |  |  |  | RET [ TRUE ]
 |  |  |  \_
 |  |  | @ASTNode el = cond.as.cond.elif_part
 |  |  | WHILE [ el != 0 ]
 |  |  |  | IF [ (has_break)[ el.as.elif_cond.block ] ]
 |  |  |  |  | RET [ TRUE ]
 |  |  |  |  \_
 |  |  |  | el = el.as.elif_cond.next_elif
 |  |  |  \_
 |  |  | IF [ cond.as.cond.else_part != 0 && (has_break)[ cond.as.cond.else_part.as.else_cond.block ] ]
 |  |  |  | RET [ TRUE ]
 |  |  |  \_
 |  |  \_
 |  | s = s.as.stmt.next_stmt
 |  \_
 | RET [ FALSE ]
 \_

; Control never continues past this statement.
B1 stmt_ends: [ @ASTNode st ]
 | I32 k = st.as.stmt.kind
 | IF [ k == ST_RET ]
 |  | RET [ TRUE ]
 |  \_
 | IF [ k == ST_EXPR ]
 |  | RET [ (is_noreturn_call)[ st.as.stmt.stmt ] ]
 |  \_
 | IF [ k == ST_LOOP ]
 |  | ; LOOP without a way out never falls through; WHILE may not run at all
 |  | @ASTNode lp = st.as.stmt.stmt
 |  | RET [ lp.as.loop.expr == 0 && !(has_break)[ lp.as.loop.block ] ]
 |  \_
 | IF [ k == ST_COND ]
 |  | @ASTNode cond = st.as.stmt.stmt
 |  | IF [ cond.as.cond.else_part == 0 ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | IF [ !(block_ends)[ cond.as.cond.if_part.as.if_cond.block ] ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | @ASTNode el = cond.as.cond.elif_part
 |  | WHILE [ el != 0 ]
 |  |  | IF [ !(block_ends)[ el.as.elif_cond.block ] ]
 |  |  |  | RET [ FALSE ]
 |  |  |  \_
 |  |  | el = el.as.elif_cond.next_elif
 |  |  \_
 |  | RET [ (block_ends)[ cond.as.cond.else_part.as.else_cond.block ] ]
 |  \_
 | RET [ FALSE ]
 \_

B1 block_ends: [ @ASTNode blk ]
 | IF [ blk == 0 ]
 |  | RET [ FALSE ]
 |  \_
 | @ASTNode s = blk.as.block.stmts
 | WHILE [ s != 0 ]
 |  | IF [ (stmt_ends)[ s ] ]
 |  |  | RET [ TRUE ]
 |  |  \_
 |  | s = s.as.stmt.next_stmt
 |  \_
 | RET [ FALSE ]
 \_

ABYSS ck_fn: [ @Checker c | @ASTNode def ]
 | @ASTNode decl = def.as.fn_def.decl
 | c.ret_type = (ty_resolve)[ c | decl.as.fn_decl.type ]
 | c.owner = decl.as.fn_decl.owner
 |
 | (ck_push)[ c ]
 | @ASTNode p = decl.as.fn_decl.params
 | WHILE [ p != 0 ]
 |  | IF [ !(p.as.parametre.vaarg) ]
 |  |  | @C1 pn = p.as.parametre.ident.as.ident
 |  |  | (ck_define)[ c | pn | (ty_resolve)[ c | p.as.parametre.type ] | p ]
 |  |  \_
 |  | p = p.as.parametre.next_param
 |  \_
 |
 | c.loops = 0
 | (ck_block)[ c | def.as.fn_def.block ]
 | (ck_pop)[ c ]
 |
 | ; main may end without RET, as in C: it returns 0
 | @C1 fname = decl.as.fn_decl.ident.as.ident
 | B1 is_void = c.ret_type.kind == TY_VOID && c.ret_type.ptrs == 0
 | IF [ !is_void && (strcmp)[ fname | "main" ] != 0 && !(block_ends)[ def.as.fn_def.block ] ]
 |  | (ck_error2)[ c | def | "`%s` can reach its end without RET%s" | fname | "" ]
 |  \_
 | RET
 \_

; --- entry point ----------------------------------------------------------

ABYSS check_init: [ @Checker c | @Meta m ]
 | c.meta = m
 | c.scope = 0
 | c.errors = 0
 | c.tu = 0
 | c.owner = 0
 | c.loops = 0
 | c.ix = 0
 | c.ret_type = (ty_void)[]
 | RET
 \_

; Every name at the top level means one thing. USES includes a file once,
; so a second definition is always a mistake -- as is declaring a function
; twice with different signatures, which codegen would silently resolve in
; favour of whichever came first.
ABYSS ck_duplicates: [ @Checker c | @ASTNode root ]
 | Map types
 | Map fns
 | Map defs
 | Map globals
 | (map_init)[ @types | 128 ]
 | (map_init)[ @fns | 256 ]
 | (map_init)[ @defs | 256 ]
 | (map_init)[ @globals | 64 ]
 | @ABYSS d = 0
 |
 | @ASTNode ts = root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | I32 k = ts.as.tu_stmt.kind
 |  | @ASTNode node = ts.as.tu_stmt.tu_stmt
 |  |
 |  | IF [ k == TUST_TYPE_DEF ]
 |  |  | @C1 nm = node.as.type_def.ident.as.ident
 |  |  | IF [ (map_get)[ @types | nm | @d AS @@ABYSS ] == 1 ]
 |  |  |  | (ck_error2)[ c | node | "TYPE `%s` is defined twice%s" | nm | "" ]
 |  |  |  \_
 |  |  | (map_put)[ @types | nm | node AS @ABYSS ]
 |  |  \_
 |  |
 |  | IF [ k == TUST_VAR_DECL ]
 |  |  | @C1 nm = node.as.var_decl.ident.as.ident
 |  |  | IF [ (map_get)[ @globals | nm | @d AS @@ABYSS ] == 1 ]
 |  |  |  | (ck_error2)[ c | node | "global `%s` is defined twice%s" | nm | "" ]
 |  |  |  \_
 |  |  | (map_put)[ @globals | nm | node AS @ABYSS ]
 |  |  \_
 |  |
 |  | IF [ k == TUST_FN_DEF || k == TUST_FN_DECL ]
 |  |  | @ASTNode decl = node
 |  |  | IF [ k == TUST_FN_DEF ]
 |  |  |  | decl = node.as.fn_def.decl
 |  |  |  | @C1 dn = decl.as.fn_decl.ident.as.ident
 |  |  |  | IF [ (map_get)[ @defs | dn | @d AS @@ABYSS ] == 1 ]
 |  |  |  |  | (ck_error2)[ c | node | "function `%s` is defined twice%s" | dn | "" ]
 |  |  |  |  \_
 |  |  |  | (map_put)[ @defs | dn | node AS @ABYSS ]
 |  |  |  \_
 |  |  | @C1 fn = decl.as.fn_decl.ident.as.ident
 |  |  | IF [ (map_get)[ @fns | fn | @d AS @@ABYSS ] == 1 ]
 |  |  |  | IF [ !(sig_same)[ c | d AS @ASTNode | decl ] ]
 |  |  |  |  | (ck_error2)[ c | decl | "`%s` is declared again with a different signature%s" | fn | "" ]
 |  |  |  |  \_
 |  |  | ELSE
 |  |  |  | (map_put)[ @fns | fn | decl AS @ABYSS ]
 |  |  |  \_
 |  |  \_
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 |
 | (map_deinit)[ @types ]
 | (map_deinit)[ @fns ]
 | (map_deinit)[ @defs ]
 | (map_deinit)[ @globals ]
 | RET
 \_

B1 check_unit: [ @Checker c | @ASTNode root ]
 | c.tu = root
 | (ck_push)[ c ]
 | (ck_duplicates)[ c | root ]
 |
 | ; globals first, so every function can see them
 | @ASTNode ts = root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | IF [ ts.as.tu_stmt.kind == TUST_VAR_DECL ]
 |  |  | @ASTNode d = ts.as.tu_stmt.tu_stmt
 |  |  | @C1 nm = d.as.var_decl.ident.as.ident
 |  |  | Type gt = (ty_decl)[ c | d.as.var_decl.type ]
 |  |  | IF [ gt.kind == TY_VOID && gt.ptrs == 0 ]
 |  |  |  | (ck_error2)[ c | d | "`%s` cannot have type ABYSS%s" | nm | "" ]
 |  |  |  \_
 |  |  | (ck_define)[ c | nm | gt | d ]
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
 |  | (diag_summary)[]
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
