; codegen.pl -- the PLUM counterpart of src/codegen.c
;
; Emits LLVM IR through the C API, driven entirely from PLUM: every LLVM
; handle is an opaque @ABYSS.
;
; meta_pass destroys its scopes on the way out, so nothing it collected
; about locals survives. Codegen keeps its own scope stack, and uses Meta
; only for the global layer (func_decls, types).

!USES <ast.pl>
!USES <meta.pl>
!USES <../extern/llvm.pl>
!USES <../lib/vec.pl>
!USES <../extern/stdio.pl>
!USES <../extern/stdlib.pl>
!USES <../extern/string.pl>

; Opaque pointers mean LLVMTypeOf(alloca) is just `ptr`, so a symbol has to
; remember what it points AT -- and the AST type, for pointer arithmetic.
TYPE CGSym: STRUCT
 | @C1      name
 | @ABYSS   value
 | @ABYSS   type
 | @ASTNode ntype
 \_

TYPE CGScope: STRUCT
 | Vec      syms
 | @CGScope parent
 \_

TYPE CGType: STRUCT
 | @C1      name
 | @ABYSS   type
 | @ASTNode record
 | B1       is_union
 | B1       body_set
 \_

TYPE CGEnumConst: STRUCT
 | @C1 name
 | I64 value
 \_

TYPE CGStr: STRUCT
 | @C1    text
 | @ABYSS global
 \_

TYPE CodegenContext: STRUCT
 | @ABYSS   ctx
 | @ABYSS   mod
 | @ABYSS   builder
 | @Meta    meta
 | @CGScope scope
 | Vec      types
 | Vec      consts
 | Vec      strs
 | @ABYSS   fn
 | @ABYSS   ret_type
 | @ABYSS   loop_break
 | @ABYSS   loop_continue
 \_

; A declared type plus how many pointer levels survive derefs and refs.
; `node` is 0 when it cannot be worked out, which only costs pointer scaling.
TYPE TypeInfo: STRUCT
 | @ASTNode node
 | U64      ptrs
 \_

TYPE LValue: STRUCT
 | @ABYSS ptr
 | @ABYSS type
 \_

ABYSS cg_fatal: [ @C1 msg ]
 | (printf)[ "codegen: %s\n" | msg ]
 | (exit)[ 1 ]
 | RET
 \_

; --- scopes ---------------------------------------------------------------

ABYSS scope_push: [ @CodegenContext c ]
 | @CGScope s = (malloc)[ SIZE [ CGScope ] ] AS @CGScope
 | (vec_init)[ @(s.syms) | SIZE [ CGSym ] | 16 ]
 | s.parent = c.scope
 | c.scope = s
 | RET
 \_

ABYSS scope_pop: [ @CodegenContext c ]
 | @CGScope s = c.scope
 | IF [ s == 0 ]
 |  | RET
 |  \_
 | c.scope = s.parent
 | (vec_deinit)[ @(s.syms) ]
 | (free)[ s AS @ABYSS ]
 | RET
 \_

ABYSS scope_define: [ @CodegenContext c | @C1 name | @ABYSS v | @ABYSS t | @ASTNode ntype ]
 | CGSym sym
 | sym.name  = name
 | sym.value = v
 | sym.type  = t
 | sym.ntype = ntype
 | (vec_append)[ @(c.scope.syms) | @sym AS @ABYSS ]
 | RET
 \_

@CGSym scope_lookup: [ @CodegenContext c | @C1 name ]
 | @CGScope s = c.scope
 | WHILE [ s != 0 ]
 |  | U64 n = (vec_size)[ @(s.syms) ]
 |  | U64 i = n
 |  | WHILE [ i > 0 ]
 |  |  | i = i - 1
 |  |  | @CGSym sym = (vec_at)[ @(s.syms) | i ] AS @CGSym
 |  |  | IF [ (strcmp)[ sym.name | name ] == 0 ]
 |  |  |  | RET [ sym ]
 |  |  |  \_
 |  |  \_
 |  | s = s.parent
 |  \_
 | RET [ 0 ]
 \_

; --- user types -----------------------------------------------------------

@CGType type_lookup: [ @CodegenContext c | @C1 name ]
 | U64 i = 0
 | WHILE [ i < (vec_size)[ @(c.types) ] ]
 |  | @CGType t = (vec_at)[ @(c.types) | i ] AS @CGType
 |  | IF [ (strcmp)[ t.name | name ] == 0 ]
 |  |  | RET [ t ]
 |  |  \_
 |  | i = i + 1
 |  \_
 | RET [ 0 ]
 \_

@CGType type_add: [ @CodegenContext c | @C1 name ]
 | CGType t
 | t.name = name
 | t.type = 0
 | t.record = 0
 | t.is_union = FALSE
 | t.body_set = FALSE
 | (vec_append)[ @(c.types) | @t AS @ABYSS ]
 | RET [ (vec_at)[ @(c.types) | (vec_size)[ @(c.types) ] - 1 ] AS @CGType ]
 \_

@CGType type_of_struct: [ @CodegenContext c | @ABYSS ty ]
 | U64 i = 0
 | WHILE [ i < (vec_size)[ @(c.types) ] ]
 |  | @CGType t = (vec_at)[ @(c.types) | i ] AS @CGType
 |  | IF [ t.type == ty ]
 |  |  | RET [ t ]
 |  |  \_
 |  | i = i + 1
 |  \_
 | RET [ 0 ]
 \_

ABYSS enum_const_add: [ @CodegenContext c | @C1 name | I64 v ]
 | CGEnumConst e
 | e.name = name
 | e.value = v
 | (vec_append)[ @(c.consts) | @e AS @ABYSS ]
 | RET
 \_

B1 enum_const_get: [ @CodegenContext c | @C1 name | @I64 out ]
 | U64 i = 0
 | WHILE [ i < (vec_size)[ @(c.consts) ] ]
 |  | @CGEnumConst e = (vec_at)[ @(c.consts) | i ] AS @CGEnumConst
 |  | IF [ (strcmp)[ e.name | name ] == 0 ]
 |  |  | ?(out) = e.value
 |  |  | RET [ TRUE ]
 |  |  \_
 |  | i = i + 1
 |  \_
 | RET [ FALSE ]
 \_

; --- types ----------------------------------------------------------------

@ABYSS map_base_type: [ @CodegenContext c | I32 bt ]
 | IF [ bt == BT_ABYSS ]
 |  | RET [ (LLVMVoidTypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ bt == BT_B1 ]
 |  | RET [ (LLVMInt1TypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ bt == BT_C1 || bt == BT_U8 || bt == BT_I8 ]
 |  | RET [ (LLVMInt8TypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ bt == BT_U16 || bt == BT_I16 ]
 |  | RET [ (LLVMInt16TypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ bt == BT_U32 || bt == BT_I32 ]
 |  | RET [ (LLVMInt32TypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ bt == BT_U64 || bt == BT_I64 || bt == BT_USIZE || bt == BT_ISIZE ]
 |  | RET [ (LLVMInt64TypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ bt == BT_F32 ]
 |  | RET [ (LLVMFloatTypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ bt == BT_F64 ]
 |  | RET [ (LLVMDoubleTypeInContext)[ c.ctx ] ]
 |  \_
 | (cg_fatal)[ "unmapped base type" ]
 | RET [ 0 ]
 \_

@ABYSS map_type: [ @CodegenContext c | @ASTNode tn ]
 | @ABYSS base = 0
 |
 | IF [ tn.as.type.kind == TT_BASE_TYPE ]
 |  | base = (map_base_type)[ c | tn.as.type.type.as.base_type ]
 | ELSE
 |  | @CGType ut = (type_lookup)[ c | tn.as.type.type.as.ident ]
 |  | IF [ ut == 0 ]
 |  |  | (printf)[ "codegen: unknown type `%s` at %d:%d\n" | tn.as.type.type.as.ident | tn.loc.line | tn.loc.col ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  | base = ut.type
 |  \_
 |
 | U64 i = 0
 | WHILE [ i < tn.as.type.ptrs ]
 |  | base = (LLVMPointerType)[ base | 0 ]
 |  | i = i + 1
 |  \_
 | RET [ base ]
 \_

@ABYSS llvm_of: [ @CodegenContext c | TypeInfo ti ]
 | IF [ ti.node == 0 ]
 |  | RET [ 0 ]
 |  \_
 |
 | @ABYSS base = 0
 | IF [ ti.node.as.type.kind == TT_BASE_TYPE ]
 |  | base = (map_base_type)[ c | ti.node.as.type.type.as.base_type ]
 | ELSE
 |  | @CGType ut = (type_lookup)[ c | ti.node.as.type.type.as.ident ]
 |  | IF [ ut == 0 ]
 |  |  | RET [ 0 ]
 |  |  \_
 |  | base = ut.type
 |  \_
 |
 | U64 i = 0
 | WHILE [ i < ti.ptrs ]
 |  | base = (LLVMPointerType)[ base | 0 ]
 |  | i = i + 1
 |  \_
 | RET [ base ]
 \_

; Unwrap NT_EXPR down to the node that carries meaning.
@ASTNode strip: [ @ASTNode e ]
 | @ASTNode n = e
 | WHILE [ n != 0 && n.kind == NT_EXPR ]
 |  | n = n.as.expr.expr
 |  \_
 | RET [ n ]
 \_

B1 field_index: [ @ASTNode record | @C1 field | @I32 idx | @@ASTNode type_out ]
 | I32 i = 0
 | @ASTNode f = record.as.record.fields
 | WHILE [ f != 0 ]
 |  | IF [ (strcmp)[ f.as.rcrd_flds.ident.as.ident | field ] == 0 ]
 |  |  | ?(idx) = i
 |  |  | ?(type_out) = f.as.rcrd_flds.type
 |  |  | RET [ TRUE ]
 |  |  \_
 |  | i = i + 1
 |  | f = f.as.rcrd_flds.next_field
 |  \_
 | RET [ FALSE ]
 \_

@ABYSS gen_expr: [ @CodegenContext c | @ASTNode e ]
B1     gen_lvalue: [ @CodegenContext c | @ASTNode e | @LValue out ]
ABYSS  gen_block: [ @CodegenContext c | @ASTNode blk ]
TypeInfo infer: [ @CodegenContext c | @ASTNode e ]

TypeInfo infer: [ @CodegenContext c | @ASTNode e ]
 | TypeInfo none
 | none.node = 0
 | none.ptrs = 0
 |
 | @ASTNode n = (strip)[ e ]
 | IF [ n == 0 ]
 |  | RET [ none ]
 |  \_
 |
 | IF [ n.kind == NT_IDENT ]
 |  | @CGSym s = (scope_lookup)[ c | n.as.ident ]
 |  | IF [ s == 0 || s.ntype == 0 ]
 |  |  | RET [ none ]
 |  |  \_
 |  | TypeInfo r
 |  | r.node = s.ntype
 |  | r.ptrs = s.ntype.as.type.ptrs
 |  | RET [ r ]
 |  \_
 |
 | IF [ n.kind == NT_UNY_OP ]
 |  | TypeInfo i = (infer)[ c | n.as.uny_op.operand ]
 |  | IF [ n.as.uny_op.kind == UOT_DEREF ]
 |  |  | IF [ i.ptrs == 0 ]
 |  |  |  | RET [ none ]
 |  |  |  \_
 |  |  | TypeInfo r
 |  |  | r.node = i.node
 |  |  | r.ptrs = i.ptrs - 1
 |  |  | RET [ r ]
 |  |  \_
 |  | IF [ n.as.uny_op.kind == UOT_REF ]
 |  |  | IF [ i.node == 0 ]
 |  |  |  | RET [ none ]
 |  |  |  \_
 |  |  | TypeInfo r
 |  |  | r.node = i.node
 |  |  | r.ptrs = i.ptrs + 1
 |  |  | RET [ r ]
 |  |  \_
 |  | RET [ i ]
 |  \_
 |
 | IF [ n.kind == NT_CAST ]
 |  | TypeInfo r
 |  | r.node = n.as.cast.type
 |  | r.ptrs = n.as.cast.type.as.type.ptrs
 |  | RET [ r ]
 |  \_
 |
 | IF [ n.kind == NT_BIN_OP ]
 |  | IF [ n.as.bin_op.kind == BOT_MEMBER ]
 |  |  | TypeInfo base = (infer)[ c | n.as.bin_op.left ]
 |  |  | IF [ base.node == 0 ]
 |  |  |  | RET [ none ]
 |  |  |  \_
 |  |  |
 |  |  | TypeInfo flat
 |  |  | flat.node = base.node
 |  |  | flat.ptrs = 0
 |  |  | @ABYSS sty = (llvm_of)[ c | flat ]
 |  |  | IF [ sty == 0 ]
 |  |  |  | RET [ none ]
 |  |  |  \_
 |  |  |
 |  |  | @CGType ut = (type_of_struct)[ c | sty ]
 |  |  | IF [ ut == 0 || ut.record == 0 ]
 |  |  |  | RET [ none ]
 |  |  |  \_
 |  |  |
 |  |  | @ASTNode fname = (strip)[ n.as.bin_op.right ]
 |  |  | IF [ fname == 0 || fname.kind != NT_IDENT ]
 |  |  |  | RET [ none ]
 |  |  |  \_
 |  |  |
 |  |  | I32 idx = 0
 |  |  | @ASTNode ftype = 0
 |  |  | IF [ !(field_index)[ ut.record | fname.as.ident | @idx | @ftype AS @@ASTNode ] ]
 |  |  |  | RET [ none ]
 |  |  |  \_
 |  |  |
 |  |  | TypeInfo r
 |  |  | r.node = ftype
 |  |  | r.ptrs = ftype.as.type.ptrs
 |  |  | RET [ r ]
 |  |  \_
 |  | RET [ (infer)[ c | n.as.bin_op.left ] ]
 |  \_
 |
 | IF [ n.kind == NT_FN_CALL ]
 |  | @ABYSS d = 0
 |  | IF [ (map_get)[ @(c.meta.func_decls) | n.as.fn_call.ident.as.ident | @d AS @@ABYSS ] == 1 ]
 |  |  | @ASTNode decl = d AS @ASTNode
 |  |  | TypeInfo r
 |  |  | r.node = decl.as.fn_decl.type
 |  |  | r.ptrs = decl.as.fn_decl.type.as.type.ptrs
 |  |  | RET [ r ]
 |  |  \_
 |  | RET [ none ]
 |  \_
 |
 | RET [ none ]
 \_

@ABYSS coerce: [ @CodegenContext c | @ABYSS v | @ABYSS to ]
 | IF [ v == 0 || to == 0 ]
 |  | RET [ v ]
 |  \_
 |
 | @ABYSS from = (LLVMTypeOf)[ v ]
 | IF [ from == to ]
 |  | RET [ v ]
 |  \_
 |
 | I32 fk = (LLVMGetTypeKind)[ from ]
 | I32 tk = (LLVMGetTypeKind)[ to ]
 |
 | IF [ fk == LLVMIntegerTypeKind && tk == LLVMIntegerTypeKind ]
 |  | I32 fw = (LLVMGetIntTypeWidth)[ from ]
 |  | I32 tw = (LLVMGetIntTypeWidth)[ to ]
 |  | IF [ fw == tw ]
 |  |  | RET [ v ]
 |  |  \_
 |  | IF [ fw < tw ]
 |  |  | RET [ (LLVMBuildSExt)[ c.builder | v | to | "sext" ] ]
 |  |  \_
 |  | RET [ (LLVMBuildTrunc)[ c.builder | v | to | "trunc" ] ]
 |  \_
 |
 | IF [ fk == LLVMIntegerTypeKind && tk == LLVMPointerTypeKind ]
 |  | RET [ (LLVMBuildIntToPtr)[ c.builder | v | to | "itop" ] ]
 |  \_
 | IF [ fk == LLVMPointerTypeKind && tk == LLVMIntegerTypeKind ]
 |  | RET [ (LLVMBuildPtrToInt)[ c.builder | v | to | "ptoi" ] ]
 |  \_
 | IF [ fk == LLVMPointerTypeKind && tk == LLVMPointerTypeKind ]
 |  | RET [ v ]
 |  \_
 | IF [ fk == LLVMIntegerTypeKind && (tk == LLVMFloatTypeKind || tk == LLVMDoubleTypeKind) ]
 |  | RET [ (LLVMBuildSIToFP)[ c.builder | v | to | "sitofp" ] ]
 |  \_
 |
 | IF [ fk == LLVMStructTypeKind || tk == LLVMStructTypeKind ]
 |  | (cg_fatal)[ "cannot convert to or from an aggregate" ]
 |  \_
 | RET [ v ]
 \_

; --- string literals ------------------------------------------------------

@C1 unescape: [ @C1 lex | @U64 out_len ]
 | U64 n = (strlen)[ lex ]
 | @C1 p = lex
 | @C1 end = lex + n
 |
 | IF [ n >= 2 && (?(p) == '"' || ?(p) == '\'') ]
 |  | p = p + 1
 |  | end = end - 1
 |  \_
 |
 | @C1 buf = (malloc)[ n + 1 ] AS @C1
 | U64 k = 0
 |
 | WHILE [ p < end ]
 |  | IF [ ?(p) == '\\' && (p + 1) < end ]
 |  |  | p = p + 1
 |  |  | C1 e = ?(p)
 |  |  | IF [ e == 'n' ]
 |  |  |  | ?(buf + k) = 10 AS C1
 |  |  | ELIF [ e == 't' ]
 |  |  |  | ?(buf + k) = 9 AS C1
 |  |  | ELIF [ e == 'r' ]
 |  |  |  | ?(buf + k) = 13 AS C1
 |  |  | ELIF [ e == '0' ]
 |  |  |  | ?(buf + k) = 0 AS C1
 |  |  | ELIF [ e == 'x' ]
 |  |  |  | I32 val = 0
 |  |  |  | I32 cnt = 0
 |  |  |  | p = p + 1
 |  |  |  | WHILE [ cnt < 2 && p < end ]
 |  |  |  |  | C1 h = ?(p)
 |  |  |  |  | I32 d = -1
 |  |  |  |  | IF [ h >= '0' && h <= '9' ]
 |  |  |  |  |  | d = (h AS I32) - 48
 |  |  |  |  | ELIF [ h >= 'a' && h <= 'f' ]
 |  |  |  |  |  | d = (h AS I32) - 87
 |  |  |  |  | ELIF [ h >= 'A' && h <= 'F' ]
 |  |  |  |  |  | d = (h AS I32) - 55
 |  |  |  |  |  \_
 |  |  |  |  | IF [ d < 0 ]
 |  |  |  |  |  | BREAK
 |  |  |  |  |  \_
 |  |  |  |  | val = val * 16 + d
 |  |  |  |  | p = p + 1
 |  |  |  |  | cnt += 1
 |  |  |  |  \_
 |  |  |  | ?(buf + k) = val AS C1
 |  |  |  | k = k + 1
 |  |  |  | CONTINUE
 |  |  | ELSE
 |  |  |  | ?(buf + k) = e
 |  |  |  \_
 |  |  | k = k + 1
 |  |  | p = p + 1
 |  | ELSE
 |  |  | ?(buf + k) = ?(p)
 |  |  | k = k + 1
 |  |  | p = p + 1
 |  |  \_
 |  \_
 |
 | ?(buf + k) = '\0'
 | ?(out_len) = k
 | RET [ buf ]
 \_

@ABYSS str_global: [ @CodegenContext c | @C1 lex ]
 | U64 i = 0
 | WHILE [ i < (vec_size)[ @(c.strs) ] ]
 |  | @CGStr s = (vec_at)[ @(c.strs) | i ] AS @CGStr
 |  | IF [ (strcmp)[ s.text | lex ] == 0 ]
 |  |  | RET [ s.global ]
 |  |  \_
 |  | i = i + 1
 |  \_
 |
 | U64 len = 0
 | @C1 text = (unescape)[ lex | @len ]
 |
 | @ABYSS arr = (LLVMArrayType)[ (LLVMInt8TypeInContext)[ c.ctx ] | (len AS I32) + 1 ]
 | @C1 name = (malloc)[ 32 ] AS @C1
 | (snprintf)[ name | 32 | ".str.%d" | (vec_size)[ @(c.strs) ] AS I32 ]
 |
 | @ABYSS g = (LLVMAddGlobal)[ c.mod | arr | name ]
 | @ABYSS init = (LLVMConstStringInContext)[ c.ctx | text | len AS I32 | 0 ]
 | (LLVMSetInitializer)[ g | init ]
 | (LLVMSetGlobalConstant)[ g | 1 ]
 | (LLVMSetLinkage)[ g | LLVMPrivateLinkage ]
 | (LLVMSetUnnamedAddr)[ g | 1 ]
 | (free)[ text AS @ABYSS ]
 |
 | CGStr entry
 | entry.text = lex
 | entry.global = g
 | (vec_append)[ @(c.strs) | @entry AS @ABYSS ]
 | RET [ g ]
 \_

B1 gen_lvalue: [ @CodegenContext c | @ASTNode e | @LValue out ]
 | @ASTNode n = (strip)[ e ]
 | IF [ n == 0 ]
 |  | RET [ FALSE ]
 |  \_
 |
 | IF [ n.kind == NT_IDENT ]
 |  | @CGSym s = (scope_lookup)[ c | n.as.ident ]
 |  | IF [ s == 0 ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | out.ptr = s.value
 |  | out.type = s.type
 |  | RET [ TRUE ]
 |  \_
 |
 | ; ?p -- the address is whatever p holds
 | IF [ n.kind == NT_UNY_OP && n.as.uny_op.kind == UOT_DEREF ]
 |  | TypeInfo ti = (infer)[ c | n.as.uny_op.operand ]
 |  | @ABYSS pointee = 0
 |  | IF [ ti.node != 0 && ti.ptrs > 0 ]
 |  |  | TypeInfo inner
 |  |  | inner.node = ti.node
 |  |  | inner.ptrs = ti.ptrs - 1
 |  |  | pointee = (llvm_of)[ c | inner ]
 |  |  \_
 |  | IF [ pointee == 0 ]
 |  |  | pointee = (LLVMInt8TypeInContext)[ c.ctx ]
 |  |  \_
 |  | out.ptr = (gen_expr)[ c | n.as.uny_op.operand ]
 |  | out.type = pointee
 |  | RET [ out.ptr != 0 ]
 |  \_
 |
 | ; a.b -- GEP into a struct, or the same address for a union
 | IF [ n.kind == NT_BIN_OP && n.as.bin_op.kind == BOT_MEMBER ]
 |  | LValue base
 |  | @ABYSS sty = 0
 |  | @ABYSS sptr = 0
 |  |
 |  | IF [ (gen_lvalue)[ c | n.as.bin_op.left | @base ] ]
 |  |  | sty = base.type
 |  |  | sptr = base.ptr
 |  | ELSE
 |  |  | TypeInfo ti = (infer)[ c | n.as.bin_op.left ]
 |  |  | IF [ ti.node == 0 || ti.ptrs == 0 ]
 |  |  |  | RET [ FALSE ]
 |  |  |  \_
 |  |  | sptr = (gen_expr)[ c | n.as.bin_op.left ]
 |  |  | sty = (llvm_of)[ c | ti ]
 |  |  | IF [ sptr == 0 || sty == 0 ]
 |  |  |  | RET [ FALSE ]
 |  |  |  \_
 |  |  \_
 |  |
 |  | ; @Foo f ... f.x -- step through the pointer first
 |  | IF [ (LLVMGetTypeKind)[ sty ] == LLVMPointerTypeKind ]
 |  |  | TypeInfo ti = (infer)[ c | n.as.bin_op.left ]
 |  |  | IF [ ti.node == 0 || ti.ptrs == 0 ]
 |  |  |  | RET [ FALSE ]
 |  |  |  \_
 |  |  | TypeInfo inner
 |  |  | inner.node = ti.node
 |  |  | inner.ptrs = ti.ptrs - 1
 |  |  | @ABYSS pointee = (llvm_of)[ c | inner ]
 |  |  | IF [ pointee == 0 ]
 |  |  |  | RET [ FALSE ]
 |  |  |  \_
 |  |  | sptr = (LLVMBuildLoad2)[ c.builder | sty | sptr | "objptr" ]
 |  |  | sty = pointee
 |  |  \_
 |  |
 |  | IF [ (LLVMGetTypeKind)[ sty ] != LLVMStructTypeKind ]
 |  |  | (printf)[ "codegen: `.` applied to a non-aggregate at %d:%d\n" | n.loc.line | n.loc.col ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  |
 |  | @CGType ut = (type_of_struct)[ c | sty ]
 |  | IF [ ut == 0 || ut.record == 0 ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  |
 |  | @ASTNode fname = (strip)[ n.as.bin_op.right ]
 |  | IF [ fname == 0 || fname.kind != NT_IDENT ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  |
 |  | I32 idx = 0
 |  | @ASTNode ftype = 0
 |  | IF [ !(field_index)[ ut.record | fname.as.ident | @idx | @ftype AS @@ASTNode ] ]
 |  |  | (printf)[ "codegen: no field `%s` in `%s`\n" | fname.as.ident | ut.name ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  |
 |  | IF [ ut.is_union ]
 |  |  | ; every member starts at the union's own address
 |  |  | out.ptr = sptr
 |  |  | out.type = (map_type)[ c | ftype ]
 |  |  | RET [ TRUE ]
 |  |  \_
 |  |
 |  | out.ptr = (LLVMBuildStructGEP2)[ c.builder | sty | sptr | idx | "fld" ]
 |  | out.type = (map_type)[ c | ftype ]
 |  | RET [ TRUE ]
 |  \_
 |
 | RET [ FALSE ]
 \_

B1 is_unsigned_expr: [ @CodegenContext c | @ASTNode e ]
 | TypeInfo ti = (infer)[ c | e ]
 | IF [ ti.node == 0 || ti.ptrs > 0 ]
 |  | RET [ FALSE ]
 |  \_
 | IF [ ti.node.as.type.kind != TT_BASE_TYPE ]
 |  | RET [ FALSE ]
 |  \_
 | I32 bt = ti.node.as.type.type.as.base_type
 | RET [ bt == BT_B1 || bt == BT_U8 || bt == BT_U16 || bt == BT_U32 || bt == BT_U64 || bt == BT_USIZE ]
 \_

@ABYSS gen_call: [ @CodegenContext c | @ASTNode call ]
 | @C1 name = call.as.fn_call.ident.as.ident
 | @ABYSS callee = (LLVMGetNamedFunction)[ c.mod | name ]
 | IF [ callee == 0 ]
 |  | (printf)[ "codegen: call to undeclared function `%s`\n" | name ]
 |  | (exit)[ 1 ]
 |  \_
 |
 | @ABYSS fty = (LLVMGlobalGetValueType)[ callee ]
 | I32 nparams = (LLVMCountParamTypes)[ fty ]
 |
 | @@ABYSS ptypes = (malloc)[ 64 * 8 ] AS @@ABYSS
 | (LLVMGetParamTypes)[ fty | ptypes ]
 |
 | @@ABYSS args = (malloc)[ 64 * 8 ] AS @@ABYSS
 | I32 n = 0
 |
 | @ASTNode a = call.as.fn_call.args
 | WHILE [ a != 0 && n < 64 ]
 |  | @ABYSS v = (gen_expr)[ c | a.as.argument.argument ]
 |  | IF [ v == 0 ]
 |  |  | (printf)[ "codegen: could not evaluate argument %d to `%s`\n" | n + 1 | name ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  |
 |  | IF [ n < nparams ]
 |  |  | v = (coerce)[ c | v | ?(ptypes + n) ]
 |  | ELSE
 |  |  | ; C variadic default promotion, respecting signedness
 |  |  | @ABYSS vt = (LLVMTypeOf)[ v ]
 |  |  | IF [ (LLVMGetTypeKind)[ vt ] == LLVMIntegerTypeKind && (LLVMGetIntTypeWidth)[ vt ] < 32 ]
 |  |  |  | @ABYSS i32 = (LLVMInt32TypeInContext)[ c.ctx ]
 |  |  |  | B1 uns = (LLVMGetIntTypeWidth)[ vt ] == 1
 |  |  |  | IF [ !uns ]
 |  |  |  |  | uns = (is_unsigned_expr)[ c | a.as.argument.argument ]
 |  |  |  |  \_
 |  |  |  | IF [ uns ]
 |  |  |  |  | v = (LLVMBuildZExt)[ c.builder | v | i32 | "vapromo" ]
 |  |  |  | ELSE
 |  |  |  |  | v = (LLVMBuildSExt)[ c.builder | v | i32 | "vapromo" ]
 |  |  |  |  \_
 |  |  |  \_
 |  |  \_
 |  |
 |  | ?(args + n) = v
 |  | n = n + 1
 |  | a = a.as.argument.next_arg
 |  \_
 |
 | B1 is_void = (LLVMGetTypeKind)[ (LLVMGetReturnType)[ fty ] ] == LLVMVoidTypeKind
 | @C1 rname = "call"
 | IF [ is_void ]
 |  | rname = ""
 |  \_
 |
 | @ABYSS r = (LLVMBuildCall2)[ c.builder | fty | callee | args | n | rname ]
 | (free)[ args AS @ABYSS ]
 | (free)[ ptypes AS @ABYSS ]
 | RET [ r ]
 \_

@ABYSS gen_binop: [ @CodegenContext c | @ASTNode n ]
 | I32 k = n.as.bin_op.kind
 |
 | IF [ k == BOT_ASSIGN ]
 |  | LValue lv
 |  | IF [ !(gen_lvalue)[ c | n.as.bin_op.left | @lv ] ]
 |  |  | (printf)[ "codegen: left side of `=` is not assignable at %d:%d\n" | n.loc.line | n.loc.col ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  | @ABYSS v = (coerce)[ c | (gen_expr)[ c | n.as.bin_op.right ] | lv.type ]
 |  | IF [ v == 0 ]
 |  |  | (printf)[ "codegen: could not evaluate the right side of `=` at %d:%d\n" | n.loc.line | n.loc.col ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  | (LLVMBuildStore)[ c.builder | v | lv.ptr ]
 |  | RET [ v ]
 |  \_
 |
 | IF [ k == BOT_MEMBER ]
 |  | LValue lv
 |  | IF [ !(gen_lvalue)[ c | n | @lv ] ]
 |  |  | (printf)[ "codegen: cannot resolve member access at %d:%d\n" | n.loc.line | n.loc.col ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  | RET [ (LLVMBuildLoad2)[ c.builder | lv.type | lv.ptr | "fldval" ] ]
 |  \_
 |
 | ; && and || must not evaluate the right side unless they have to
 | IF [ k == BOT_AND || k == BOT_OR ]
 |  | @ABYSS i1 = (LLVMInt1TypeInContext)[ c.ctx ]
 |  |
 |  | @ABYSS lv = (coerce)[ c | (gen_expr)[ c | n.as.bin_op.left ] | i1 ]
 |  | @ABYSS lhs_end = (LLVMGetInsertBlock)[ c.builder ]
 |  |
 |  | @ABYSS rhs_bb = (LLVMAppendBasicBlockInContext)[ c.ctx | c.fn | "sc.rhs" ]
 |  | @ABYSS end_bb = (LLVMAppendBasicBlockInContext)[ c.ctx | c.fn | "sc.end" ]
 |  |
 |  | IF [ k == BOT_AND ]
 |  |  | (LLVMBuildCondBr)[ c.builder | lv | rhs_bb | end_bb ]
 |  | ELSE
 |  |  | (LLVMBuildCondBr)[ c.builder | lv | end_bb | rhs_bb ]
 |  |  \_
 |  |
 |  | (LLVMPositionBuilderAtEnd)[ c.builder | rhs_bb ]
 |  | @ABYSS rv = (coerce)[ c | (gen_expr)[ c | n.as.bin_op.right ] | i1 ]
 |  | @ABYSS rhs_end = (LLVMGetInsertBlock)[ c.builder ]
 |  | (LLVMBuildBr)[ c.builder | end_bb ]
 |  |
 |  | (LLVMPositionBuilderAtEnd)[ c.builder | end_bb ]
 |  | @ABYSS phi = (LLVMBuildPhi)[ c.builder | i1 | "sc" ]
 |  |
 |  | U64 shortval = 0
 |  | IF [ k == BOT_OR ]
 |  |  | shortval = 1
 |  |  \_
 |  |
 |  | @@ABYSS vals = (malloc)[ 2 * 8 ] AS @@ABYSS
 |  | @@ABYSS blks = (malloc)[ 2 * 8 ] AS @@ABYSS
 |  | ?(vals + 0) = (LLVMConstInt)[ i1 | shortval | 0 ]
 |  | ?(vals + 1) = rv
 |  | ?(blks + 0) = lhs_end
 |  | ?(blks + 1) = rhs_end
 |  | (LLVMAddIncoming)[ phi | vals | blks | 2 ]
 |  | (free)[ vals AS @ABYSS ]
 |  | (free)[ blks AS @ABYSS ]
 |  | RET [ phi ]
 |  \_
 |
 | @ABYSS l = (gen_expr)[ c | n.as.bin_op.left ]
 | @ABYSS r = (gen_expr)[ c | n.as.bin_op.right ]
 | IF [ l == 0 || r == 0 ]
 |  | RET [ 0 ]
 |  \_
 |
 | I32 lk = (LLVMGetTypeKind)[ (LLVMTypeOf)[ l ] ]
 | I32 rk = (LLVMGetTypeKind)[ (LLVMTypeOf)[ r ] ]
 |
 | ; pointer arithmetic, scaled by the pointee like C
 | IF [ (k == BOT_PLUS || k == BOT_MINUS) && lk == LLVMPointerTypeKind ]
 |  | TypeInfo ti = (infer)[ c | n.as.bin_op.left ]
 |  | @ABYSS elem = 0
 |  | IF [ ti.node != 0 && ti.ptrs > 0 ]
 |  |  | TypeInfo inner
 |  |  | inner.node = ti.node
 |  |  | inner.ptrs = ti.ptrs - 1
 |  |  | elem = (llvm_of)[ c | inner ]
 |  |  \_
 |  | IF [ elem == 0 ]
 |  |  | elem = (LLVMInt8TypeInContext)[ c.ctx ]
 |  |  \_
 |  |
 |  | @ABYSS off = (coerce)[ c | r | (LLVMInt64TypeInContext)[ c.ctx ] ]
 |  | IF [ k == BOT_MINUS ]
 |  |  | off = (LLVMBuildNeg)[ c.builder | off | "neg" ]
 |  |  \_
 |  | @@ABYSS idx = (malloc)[ 8 ] AS @@ABYSS
 |  | ?(idx) = off
 |  | @ABYSS res = (LLVMBuildGEP2)[ c.builder | elem | l | idx | 1 | "padd" ]
 |  | (free)[ idx AS @ABYSS ]
 |  | RET [ res ]
 |  \_
 |
 | IF [ lk == LLVMPointerTypeKind && rk == LLVMIntegerTypeKind ]
 |  | r = (LLVMBuildIntToPtr)[ c.builder | r | (LLVMTypeOf)[ l ] | "itop" ]
 | ELIF [ rk == LLVMPointerTypeKind && lk == LLVMIntegerTypeKind ]
 |  | l = (LLVMBuildIntToPtr)[ c.builder | l | (LLVMTypeOf)[ r ] | "itop" ]
 | ELSE
 |  | @ABYSS lt = (LLVMTypeOf)[ l ]
 |  | @ABYSS rt = (LLVMTypeOf)[ r ]
 |  | IF [ lt != rt && (LLVMGetTypeKind)[ lt ] == LLVMIntegerTypeKind && (LLVMGetTypeKind)[ rt ] == LLVMIntegerTypeKind ]
 |  |  | IF [ (LLVMGetIntTypeWidth)[ lt ] < (LLVMGetIntTypeWidth)[ rt ] ]
 |  |  |  | l = (coerce)[ c | l | rt ]
 |  |  | ELSE
 |  |  |  | r = (coerce)[ c | r | lt ]
 |  |  |  \_
 |  |  \_
 |  \_
 |
 | ; PLUM has unsigned types, so these cannot all be the signed form.
 | ; A djb2 hash in a U64 goes negative under SRem and indexes before the
 | ; bucket array -- which is exactly how this was found.
 | B1 uns = (is_unsigned_expr)[ c | n.as.bin_op.left ]
 | IF [ !uns ]
 |  | uns = (is_unsigned_expr)[ c | n.as.bin_op.right ]
 |  \_
 |
 | IF [ k == BOT_PLUS ]
 |  | RET [ (LLVMBuildAdd)[ c.builder | l | r | "add" ] ]
 |  \_
 | IF [ k == BOT_MINUS ]
 |  | RET [ (LLVMBuildSub)[ c.builder | l | r | "sub" ] ]
 |  \_
 | IF [ k == BOT_MULT ]
 |  | RET [ (LLVMBuildMul)[ c.builder | l | r | "mul" ] ]
 |  \_
 | IF [ k == BOT_DIV ]
 |  | IF [ uns ]
 |  |  | RET [ (LLVMBuildUDiv)[ c.builder | l | r | "div" ] ]
 |  |  \_
 |  | RET [ (LLVMBuildSDiv)[ c.builder | l | r | "div" ] ]
 |  \_
 | IF [ k == BOT_MOD ]
 |  | IF [ uns ]
 |  |  | RET [ (LLVMBuildURem)[ c.builder | l | r | "rem" ] ]
 |  |  \_
 |  | RET [ (LLVMBuildSRem)[ c.builder | l | r | "rem" ] ]
 |  \_
 | IF [ k == BOT_BAND ]
 |  | RET [ (LLVMBuildAnd)[ c.builder | l | r | "band" ] ]
 |  \_
 | IF [ k == BOT_BOR ]
 |  | RET [ (LLVMBuildOr)[ c.builder | l | r | "bor" ] ]
 |  \_
 | IF [ k == BOT_BXOR ]
 |  | RET [ (LLVMBuildXor)[ c.builder | l | r | "bxor" ] ]
 |  \_
 | IF [ k == BOT_SHL ]
 |  | RET [ (LLVMBuildShl)[ c.builder | l | r | "shl" ] ]
 |  \_
 | IF [ k == BOT_SHR ]
 |  | IF [ uns ]
 |  |  | RET [ (LLVMBuildLShr)[ c.builder | l | r | "shr" ] ]
 |  |  \_
 |  | RET [ (LLVMBuildAShr)[ c.builder | l | r | "shr" ] ]
 |  \_
 | IF [ k == BOT_EQUAL ]
 |  | RET [ (LLVMBuildICmp)[ c.builder | LLVMIntEQ | l | r | "eq" ] ]
 |  \_
 | IF [ k == BOT_NEQ ]
 |  | RET [ (LLVMBuildICmp)[ c.builder | LLVMIntNE | l | r | "ne" ] ]
 |  \_
 | IF [ k == BOT_LESS ]
 |  | I32 p = LLVMIntSLT
 |  | IF [ uns ]
 |  |  | p = LLVMIntULT
 |  |  \_
 |  | RET [ (LLVMBuildICmp)[ c.builder | p | l | r | "lt" ] ]
 |  \_
 | IF [ k == BOT_LEQ ]
 |  | I32 p = LLVMIntSLE
 |  | IF [ uns ]
 |  |  | p = LLVMIntULE
 |  |  \_
 |  | RET [ (LLVMBuildICmp)[ c.builder | p | l | r | "le" ] ]
 |  \_
 | IF [ k == BOT_GREAT ]
 |  | I32 p = LLVMIntSGT
 |  | IF [ uns ]
 |  |  | p = LLVMIntUGT
 |  |  \_
 |  | RET [ (LLVMBuildICmp)[ c.builder | p | l | r | "gt" ] ]
 |  \_
 | IF [ k == BOT_GEQ ]
 |  | I32 p = LLVMIntSGE
 |  | IF [ uns ]
 |  |  | p = LLVMIntUGE
 |  |  \_
 |  | RET [ (LLVMBuildICmp)[ c.builder | p | l | r | "ge" ] ]
 |  \_
 |
 | (cg_fatal)[ "unhandled binary operator" ]
 | RET [ 0 ]
 \_

@ABYSS gen_literal: [ @CodegenContext c | @ASTNode n ]
 | I32 k = n.as.literal.kind
 |
 | IF [ k == LT_INTEGER ]
 |  | RET [ (LLVMConstInt)[ (LLVMInt32TypeInContext)[ c.ctx ] | n.as.literal.as.int_lit AS U64 | 1 ] ]
 |  \_
 | IF [ k == LT_BOOLEAN ]
 |  | U64 b = 0
 |  | IF [ n.as.literal.as.bool_lit ]
 |  |  | b = 1
 |  |  \_
 |  | RET [ (LLVMConstInt)[ (LLVMInt1TypeInContext)[ c.ctx ] | b | 0 ] ]
 |  \_
 | IF [ k == LT_CHARACTER ]
 |  | RET [ (LLVMConstInt)[ (LLVMInt8TypeInContext)[ c.ctx ] | n.as.literal.as.char_lit AS U64 | 0 ] ]
 |  \_
 | IF [ k == LT_STRING ]
 |  | RET [ (str_global)[ c | n.as.literal.as.str_lit ] ]
 |  \_
 | IF [ k == LT_FLOAT ]
 |  | RET [ (LLVMConstReal)[ (LLVMDoubleTypeInContext)[ c.ctx ] | n.as.literal.as.float_lit AS F64 ] ]
 |  \_
 |
 | (cg_fatal)[ "unhandled literal kind" ]
 | RET [ 0 ]
 \_

@ABYSS size_of_name: [ @CodegenContext c | @C1 tname ]
 | @CGType ut = (type_lookup)[ c | tname ]
 | IF [ ut != 0 ]
 |  | RET [ ut.type ]
 |  \_
 | IF [ (strcmp)[ tname | "B1" ] == 0 ]
 |  | RET [ (LLVMInt1TypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ (strcmp)[ tname | "C1" ] == 0 || (strcmp)[ tname | "U8" ] == 0 || (strcmp)[ tname | "I8" ] == 0 ]
 |  | RET [ (LLVMInt8TypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ (strcmp)[ tname | "U16" ] == 0 || (strcmp)[ tname | "I16" ] == 0 ]
 |  | RET [ (LLVMInt16TypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ (strcmp)[ tname | "U32" ] == 0 || (strcmp)[ tname | "I32" ] == 0 ]
 |  | RET [ (LLVMInt32TypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ (strcmp)[ tname | "U64" ] == 0 || (strcmp)[ tname | "I64" ] == 0 ]
 |  | RET [ (LLVMInt64TypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ (strcmp)[ tname | "USIZE" ] == 0 || (strcmp)[ tname | "ISIZE" ] == 0 ]
 |  | RET [ (LLVMInt64TypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ (strcmp)[ tname | "F32" ] == 0 ]
 |  | RET [ (LLVMFloatTypeInContext)[ c.ctx ] ]
 |  \_
 | IF [ (strcmp)[ tname | "F64" ] == 0 ]
 |  | RET [ (LLVMDoubleTypeInContext)[ c.ctx ] ]
 |  \_
 | RET [ 0 ]
 \_

@ABYSS gen_expr: [ @CodegenContext c | @ASTNode e ]
 | @ASTNode n = (strip)[ e ]
 | IF [ n == 0 ]
 |  | RET [ 0 ]
 |  \_
 |
 | IF [ n.kind == NT_LITERAL ]
 |  | RET [ (gen_literal)[ c | n ] ]
 |  \_
 |
 | IF [ n.kind == NT_IDENT ]
 |  | @CGSym s = (scope_lookup)[ c | n.as.ident ]
 |  | IF [ s != 0 ]
 |  |  | RET [ (LLVMBuildLoad2)[ c.builder | s.type | s.value | n.as.ident ] ]
 |  |  \_
 |  | I64 ev = 0
 |  | IF [ (enum_const_get)[ c | n.as.ident | @ev ] ]
 |  |  | RET [ (LLVMConstInt)[ (LLVMInt32TypeInContext)[ c.ctx ] | ev AS U64 | 1 ] ]
 |  |  \_
 |  | (printf)[ "codegen: unknown identifier `%s` at %d:%d\n" | n.as.ident | n.loc.line | n.loc.col ]
 |  | (exit)[ 1 ]
 |  \_
 |
 | IF [ n.kind == NT_BIN_OP ]
 |  | RET [ (gen_binop)[ c | n ] ]
 |  \_
 |
 | IF [ n.kind == NT_UNY_OP ]
 |  | I32 uk = n.as.uny_op.kind
 |  |
 |  | IF [ uk == UOT_REF ]
 |  |  | LValue lv
 |  |  | IF [ !(gen_lvalue)[ c | n.as.uny_op.operand | @lv ] ]
 |  |  |  | (printf)[ "codegen: cannot take the address of this expression at %d:%d\n" | n.loc.line | n.loc.col ]
 |  |  |  | (exit)[ 1 ]
 |  |  |  \_
 |  |  | RET [ lv.ptr ]
 |  |  \_
 |  |
 |  | IF [ uk == UOT_DEREF ]
 |  |  | LValue lv
 |  |  | IF [ (gen_lvalue)[ c | e | @lv ] ]
 |  |  |  | RET [ (LLVMBuildLoad2)[ c.builder | lv.type | lv.ptr | "deref" ] ]
 |  |  |  \_
 |  |  | RET [ 0 ]
 |  |  \_
 |  |
 |  | @ABYSS v = (gen_expr)[ c | n.as.uny_op.operand ]
 |  | IF [ v == 0 ]
 |  |  | RET [ 0 ]
 |  |  \_
 |  |
 |  | IF [ uk == UOT_BNOT ]
 |  |  | RET [ (LLVMBuildNot)[ c.builder | v | "bnot" ] ]
 |  |  \_
 |  | IF [ uk == UOT_NOT ]
 |  |  | @ABYSS vt = (LLVMTypeOf)[ v ]
 |  |  | @ABYSS zero = 0
 |  |  | IF [ (LLVMGetTypeKind)[ vt ] == LLVMPointerTypeKind ]
 |  |  |  | zero = (LLVMConstPointerNull)[ vt ]
 |  |  | ELSE
 |  |  |  | zero = (LLVMConstInt)[ vt | 0 | 0 ]
 |  |  |  \_
 |  |  | RET [ (LLVMBuildICmp)[ c.builder | LLVMIntEQ | v | zero | "not" ] ]
 |  |  \_
 |  |
 |  | RET [ (LLVMBuildNeg)[ c.builder | v | "neg" ] ]
 |  \_
 |
 | IF [ n.kind == NT_FN_CALL ]
 |  | RET [ (gen_call)[ c | n ] ]
 |  \_
 |
 | IF [ n.kind == NT_CAST ]
 |  | @ABYSS v = (gen_expr)[ c | n.as.cast.expr ]
 |  | @ABYSS to = (map_type)[ c | n.as.cast.type ]
 |  | IF [ v == 0 || to == 0 ]
 |  |  | (cg_fatal)[ "bad cast" ]
 |  |  \_
 |  |
 |  | @ABYSS from = (LLVMTypeOf)[ v ]
 |  | IF [ from == to ]
 |  |  | RET [ v ]
 |  |  \_
 |  |
 |  | I32 fk = (LLVMGetTypeKind)[ from ]
 |  | I32 tk = (LLVMGetTypeKind)[ to ]
 |  |
 |  | IF [ fk == LLVMIntegerTypeKind && tk == LLVMIntegerTypeKind ]
 |  |  | RET [ (LLVMBuildIntCast2)[ c.builder | v | to | 1 | "cast" ] ]
 |  |  \_
 |  | IF [ fk == LLVMIntegerTypeKind && tk == LLVMPointerTypeKind ]
 |  |  | RET [ (LLVMBuildIntToPtr)[ c.builder | v | to | "cast" ] ]
 |  |  \_
 |  | IF [ fk == LLVMPointerTypeKind && tk == LLVMIntegerTypeKind ]
 |  |  | RET [ (LLVMBuildPtrToInt)[ c.builder | v | to | "cast" ] ]
 |  |  \_
 |  | IF [ fk == LLVMPointerTypeKind && tk == LLVMPointerTypeKind ]
 |  |  | RET [ v ]
 |  |  \_
 |  | IF [ fk == LLVMIntegerTypeKind && (tk == LLVMFloatTypeKind || tk == LLVMDoubleTypeKind) ]
 |  |  | RET [ (LLVMBuildSIToFP)[ c.builder | v | to | "cast" ] ]
 |  |  \_
 |  | IF [ (fk == LLVMFloatTypeKind || fk == LLVMDoubleTypeKind) && tk == LLVMIntegerTypeKind ]
 |  |  | RET [ (LLVMBuildFPToSI)[ c.builder | v | to | "cast" ] ]
 |  |  \_
 |  | IF [ (fk == LLVMFloatTypeKind || fk == LLVMDoubleTypeKind) && (tk == LLVMFloatTypeKind || tk == LLVMDoubleTypeKind) ]
 |  |  | RET [ (LLVMBuildFPCast)[ c.builder | v | to | "cast" ] ]
 |  |  \_
 |  |
 |  | (cg_fatal)[ "cannot cast" ]
 |  | RET [ 0 ]
 |  \_
 |
 | IF [ n.kind == NT_BUILTIN ]
 |  | @C1 tname = n.as.builtin.size.as.ident
 |  | @ABYSS t = (size_of_name)[ c | tname ]
 |  | IF [ t == 0 ]
 |  |  | (printf)[ "codegen: SIZE of unknown type `%s`\n" | tname ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  | @ABYSS i64 = (LLVMInt64TypeInContext)[ c.ctx ]
 |  | RET [ (LLVMBuildIntCast2)[ c.builder | (LLVMSizeOf)[ t ] | i64 | 0 | "size" ] ]
 |  \_
 |
 | (printf)[ "codegen: unhandled expression node %d at %d:%d\n" | n.kind | n.loc.line | n.loc.col ]
 | (exit)[ 1 ]
 | RET [ 0 ]
 \_

; Every alloca belongs in the entry block. Emitting one at the current
; insertion point means a variable declared inside a loop allocates a
; fresh slot per iteration and the stack grows without bound.
@ABYSS entry_alloca: [ @CodegenContext c | @ABYSS ty | @C1 name ]
 | @ABYSS entry = (LLVMGetEntryBasicBlock)[ c.fn ]
 | @ABYSS first = (LLVMGetFirstInstruction)[ entry ]
 |
 | @ABYSS tmp = (LLVMCreateBuilderInContext)[ c.ctx ]
 | IF [ first != 0 ]
 |  | (LLVMPositionBuilderBefore)[ tmp | first ]
 | ELSE
 |  | (LLVMPositionBuilderAtEnd)[ tmp | entry ]
 |  \_
 |
 | @ABYSS slot = (LLVMBuildAlloca)[ tmp | ty | name ]
 | (LLVMDisposeBuilder)[ tmp ]
 | RET [ slot ]
 \_

B1 block_open: [ @CodegenContext c ]
 | @ABYSS bb = (LLVMGetInsertBlock)[ c.builder ]
 | IF [ bb == 0 ]
 |  | RET [ FALSE ]
 |  \_
 | RET [ (LLVMGetBasicBlockTerminator)[ bb ] == 0 ]
 \_

ABYSS gen_cond: [ @CodegenContext c | @ASTNode cond ]
 | @ABYSS i1 = (LLVMInt1TypeInContext)[ c.ctx ]
 | @ABYSS merge = (LLVMAppendBasicBlockInContext)[ c.ctx | c.fn | "if.end" ]
 |
 | @ASTNode ifp = cond.as.cond.if_part
 | @ABYSS v = (coerce)[ c | (gen_expr)[ c | ifp.as.if_cond.expr ] | i1 ]
 |
 | @ABYSS then_bb = (LLVMAppendBasicBlockInContext)[ c.ctx | c.fn | "if.then" ]
 | @ABYSS next_bb = (LLVMAppendBasicBlockInContext)[ c.ctx | c.fn | "if.else" ]
 | (LLVMBuildCondBr)[ c.builder | v | then_bb | next_bb ]
 |
 | (LLVMPositionBuilderAtEnd)[ c.builder | then_bb ]
 | (gen_block)[ c | ifp.as.if_cond.block ]
 | IF [ (block_open)[ c ] ]
 |  | (LLVMBuildBr)[ c.builder | merge ]
 |  \_
 |
 | @ASTNode el = cond.as.cond.elif_part
 | WHILE [ el != 0 ]
 |  | (LLVMPositionBuilderAtEnd)[ c.builder | next_bb ]
 |  |
 |  | @ABYSS ev = (coerce)[ c | (gen_expr)[ c | el.as.elif_cond.expr ] | i1 ]
 |  | @ABYSS ethen = (LLVMAppendBasicBlockInContext)[ c.ctx | c.fn | "elif.then" ]
 |  | @ABYSS enext = (LLVMAppendBasicBlockInContext)[ c.ctx | c.fn | "elif.else" ]
 |  | (LLVMBuildCondBr)[ c.builder | ev | ethen | enext ]
 |  |
 |  | (LLVMPositionBuilderAtEnd)[ c.builder | ethen ]
 |  | (gen_block)[ c | el.as.elif_cond.block ]
 |  | IF [ (block_open)[ c ] ]
 |  |  | (LLVMBuildBr)[ c.builder | merge ]
 |  |  \_
 |  |
 |  | next_bb = enext
 |  | el = el.as.elif_cond.next_elif
 |  \_
 |
 | (LLVMPositionBuilderAtEnd)[ c.builder | next_bb ]
 | IF [ cond.as.cond.else_part != 0 ]
 |  | (gen_block)[ c | cond.as.cond.else_part.as.else_cond.block ]
 |  \_
 | IF [ (block_open)[ c ] ]
 |  | (LLVMBuildBr)[ c.builder | merge ]
 |  \_
 |
 | (LLVMPositionBuilderAtEnd)[ c.builder | merge ]
 | RET
 \_

ABYSS gen_loop: [ @CodegenContext c | @ASTNode loop ]
 | @ABYSS body = (LLVMAppendBasicBlockInContext)[ c.ctx | c.fn | "loop.body" ]
 | @ABYSS contn = (LLVMAppendBasicBlockInContext)[ c.ctx | c.fn | "loop.cont" ]
 | @ABYSS brk = (LLVMAppendBasicBlockInContext)[ c.ctx | c.fn | "loop.end" ]
 |
 | @ABYSS save_b = c.loop_break
 | @ABYSS save_c = c.loop_continue
 | c.loop_break = brk
 | c.loop_continue = contn
 |
 | (LLVMBuildBr)[ c.builder | body ]
 | (LLVMPositionBuilderAtEnd)[ c.builder | body ]
 |
 | ; WHILE [ cond ] is a LOOP that tests before each pass
 | IF [ loop.as.loop.expr != 0 ]
 |  | @ABYSS i1 = (LLVMInt1TypeInContext)[ c.ctx ]
 |  | @ABYSS cv = (coerce)[ c | (gen_expr)[ c | loop.as.loop.expr ] | i1 ]
 |  | @ABYSS inner = (LLVMAppendBasicBlockInContext)[ c.ctx | c.fn | "while.body" ]
 |  | (LLVMBuildCondBr)[ c.builder | cv | inner | brk ]
 |  | (LLVMPositionBuilderAtEnd)[ c.builder | inner ]
 |  \_
 |
 | (gen_block)[ c | loop.as.loop.block ]
 | IF [ (block_open)[ c ] ]
 |  | (LLVMBuildBr)[ c.builder | contn ]
 |  \_
 |
 | (LLVMPositionBuilderAtEnd)[ c.builder | contn ]
 | (LLVMBuildBr)[ c.builder | body ]
 |
 | c.loop_break = save_b
 | c.loop_continue = save_c
 |
 | (LLVMPositionBuilderAtEnd)[ c.builder | brk ]
 | RET
 \_

ABYSS gen_stmt: [ @CodegenContext c | @ASTNode st ]
 | IF [ !(block_open)[ c ] ]
 |  | RET
 |  \_
 |
 | I32 k = st.as.stmt.kind
 |
 | IF [ k == ST_VAR_DECL ]
 |  | @ASTNode d = st.as.stmt.stmt
 |  | @ABYSS ty = (map_type)[ c | d.as.var_decl.type ]
 |  | @C1 nm = d.as.var_decl.ident.as.ident
 |  |
 |  | @ABYSS slot = (entry_alloca)[ c | ty | nm ]
 |  | (scope_define)[ c | nm | slot | ty | d.as.var_decl.type ]
 |  |
 |  | IF [ d.as.var_decl.init != 0 ]
 |  |  | @ABYSS v = (coerce)[ c | (gen_expr)[ c | d.as.var_decl.init ] | ty ]
 |  |  | IF [ v == 0 ]
 |  |  |  | (printf)[ "codegen: could not evaluate the initialiser of `%s` at %d:%d\n" | nm | d.loc.line | d.loc.col ]
 |  |  |  | (exit)[ 1 ]
 |  |  |  \_
 |  |  | (LLVMBuildStore)[ c.builder | v | slot ]
 |  |  \_
 |  | RET
 |  \_
 |
 | IF [ k == ST_RET ]
 |  | @ASTNode r = st.as.stmt.stmt
 |  | B1 has_val = r.as.ret.expr != 0
 |  | IF [ has_val && (LLVMGetTypeKind)[ c.ret_type ] != LLVMVoidTypeKind ]
 |  |  | @ABYSS v = (coerce)[ c | (gen_expr)[ c | r.as.ret.expr ] | c.ret_type ]
 |  |  | (LLVMBuildRet)[ c.builder | v ]
 |  | ELSE
 |  |  | (LLVMBuildRetVoid)[ c.builder ]
 |  |  \_
 |  | RET
 |  \_
 |
 | IF [ k == ST_BREAK ]
 |  | IF [ c.loop_break == 0 ]
 |  |  | (printf)[ "codegen: BREAK outside of a loop at %d:%d\n" | st.loc.line | st.loc.col ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  | (LLVMBuildBr)[ c.builder | c.loop_break ]
 |  | RET
 |  \_
 |
 | IF [ k == ST_CONTINUE ]
 |  | IF [ c.loop_continue == 0 ]
 |  |  | (printf)[ "codegen: CONTINUE outside of a loop at %d:%d\n" | st.loc.line | st.loc.col ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  | (LLVMBuildBr)[ c.builder | c.loop_continue ]
 |  | RET
 |  \_
 |
 | IF [ k == ST_COND ]
 |  | (gen_cond)[ c | st.as.stmt.stmt ]
 |  | RET
 |  \_
 |
 | IF [ k == ST_LOOP ]
 |  | (gen_loop)[ c | st.as.stmt.stmt ]
 |  | RET
 |  \_
 |
 | IF [ k == ST_EXPR ]
 |  | (gen_expr)[ c | st.as.stmt.stmt ]
 |  | RET
 |  \_
 |
 | (cg_fatal)[ "unhandled statement kind" ]
 | RET
 \_

ABYSS gen_block: [ @CodegenContext c | @ASTNode blk ]
 | IF [ blk == 0 ]
 |  | RET
 |  \_
 | (scope_push)[ c ]
 | @ASTNode s = blk.as.block.stmts
 | WHILE [ s != 0 ]
 |  | (gen_stmt)[ c | s ]
 |  | s = s.as.stmt.next_stmt
 |  \_
 | (scope_pop)[ c ]
 | RET
 \_

@ABYSS gen_fn_proto: [ @CodegenContext c | @ASTNode decl ]
 | @C1 name = decl.as.fn_decl.ident.as.ident
 |
 | @ABYSS existing = (LLVMGetNamedFunction)[ c.mod | name ]
 | IF [ existing != 0 ]
 |  | RET [ existing ]
 |  \_
 |
 | @@ABYSS ptypes = (malloc)[ 64 * 8 ] AS @@ABYSS
 | I32 n = 0
 | I32 va = 0
 |
 | @ASTNode p = decl.as.fn_decl.params
 | WHILE [ p != 0 && n < 64 ]
 |  | IF [ p.as.parametre.vaarg ]
 |  |  | va = 1
 |  | ELSE
 |  |  | ?(ptypes + n) = (map_type)[ c | p.as.parametre.type ]
 |  |  | n = n + 1
 |  |  \_
 |  | p = p.as.parametre.next_param
 |  \_
 |
 | @ABYSS ret = (map_type)[ c | decl.as.fn_decl.type ]
 | @ABYSS fty = (LLVMFunctionType)[ ret | ptypes | n | va ]
 | (free)[ ptypes AS @ABYSS ]
 |
 | RET [ (LLVMAddFunction)[ c.mod | name | fty ] ]
 \_

ABYSS gen_fn_def: [ @CodegenContext c | @ASTNode def ]
 | @ASTNode decl = def.as.fn_def.decl
 | @ABYSS fn = (gen_fn_proto)[ c | decl ]
 |
 | c.fn = fn
 | c.ret_type = (map_type)[ c | decl.as.fn_decl.type ]
 |
 | @ABYSS entry = (LLVMAppendBasicBlockInContext)[ c.ctx | fn | "entry" ]
 | (LLVMPositionBuilderAtEnd)[ c.builder | entry ]
 |
 | (scope_push)[ c ]
 |
 | ; Parameters get their own stack slot so they can be assigned and have
 | ; their address taken, like any other local.
 | I32 i = 0
 | @ASTNode p = decl.as.fn_decl.params
 | WHILE [ p != 0 ]
 |  | IF [ !(p.as.parametre.vaarg) ]
 |  |  | @C1 pn = p.as.parametre.ident.as.ident
 |  |  | @ABYSS pt = (map_type)[ c | p.as.parametre.type ]
 |  |  | @ABYSS slot = (LLVMBuildAlloca)[ c.builder | pt | pn ]
 |  |  | (LLVMBuildStore)[ c.builder | (LLVMGetParam)[ fn | i ] | slot ]
 |  |  | (scope_define)[ c | pn | slot | pt | p.as.parametre.type ]
 |  |  | i = i + 1
 |  |  \_
 |  | p = p.as.parametre.next_param
 |  \_
 |
 | (gen_block)[ c | def.as.fn_def.block ]
 |
 | ; exactly one terminator, and only if the body left the block open
 | IF [ (block_open)[ c ] ]
 |  | IF [ (LLVMGetTypeKind)[ c.ret_type ] == LLVMVoidTypeKind ]
 |  |  | (LLVMBuildRetVoid)[ c.builder ]
 |  | ELSE
 |  |  | (LLVMBuildRet)[ c.builder | (LLVMConstNull)[ c.ret_type ] ]
 |  |  \_
 |  \_
 |
 | (scope_pop)[ c ]
 | c.fn = 0
 | RET
 \_

; Pass 1: create the named struct shells, so a record may point at a type
; declared later -- what a self-referential AST needs.
ABYSS gen_type_decl: [ @CodegenContext c | @ASTNode td ]
 | IF [ td.as.type_def.kind != TD_RECORD ]
 |  | RET
 |  \_
 | @C1 name = td.as.type_def.ident.as.ident
 | IF [ (type_lookup)[ c | name ] != 0 ]
 |  | RET
 |  \_
 | @CGType ut = (type_add)[ c | name ]
 | ut.record = td.as.type_def.tdef
 | ut.is_union = td.as.type_def.tdef.as.record.kind == TDRT_UNION
 | ut.type = (LLVMStructCreateNamed)[ c.ctx | name ]
 | RET
 \_

ABYSS gen_type_def: [ @CodegenContext c | @ASTNode td ]
 | @C1 name = td.as.type_def.ident.as.ident
 |
 | IF [ td.as.type_def.kind == TD_ENUM ]
 |  | IF [ (type_lookup)[ c | name ] != 0 ]
 |  |  | RET
 |  |  \_
 |  | @CGType ut = (type_add)[ c | name ]
 |  | ut.type = (LLVMInt32TypeInContext)[ c.ctx ]
 |  |
 |  | I64 v = 0
 |  | @ASTNode f = td.as.type_def.tdef.as.enumeration.fields
 |  | WHILE [ f != 0 ]
 |  |  | I64 seen = 0
 |  |  | @C1 cn = f.as.enum_flds.ident.as.ident
 |  |  | IF [ !(enum_const_get)[ c | cn | @seen ] ]
 |  |  |  | (enum_const_add)[ c | cn | v ]
 |  |  |  \_
 |  |  | v = v + 1
 |  |  | f = f.as.enum_flds.next_field
 |  |  \_
 |  | RET
 |  \_
 |
 | IF [ td.as.type_def.kind == TD_RECORD ]
 |  | @ASTNode rec = td.as.type_def.tdef
 |  | @CGType ut = (type_lookup)[ c | name ]
 |  | IF [ ut == 0 ]
 |  |  | (cg_fatal)[ "type was never declared" ]
 |  |  \_
 |  | IF [ ut.body_set ]
 |  |  | RET
 |  |  \_
 |  | ut.body_set = TRUE
 |  |
 |  | @@ABYSS ftypes = (malloc)[ 64 * 8 ] AS @@ABYSS
 |  | I32 n = 0
 |  |
 |  | IF [ ut.is_union ]
 |  |  | ; LLVM has no union: reserve the largest member and let member
 |  |  | ; access reinterpret the same address.
 |  |  | @ABYSS td_layout = (LLVMGetModuleDataLayout)[ c.mod ]
 |  |  | U64 biggest = 0
 |  |  | @ABYSS widest = (LLVMInt8TypeInContext)[ c.ctx ]
 |  |  |
 |  |  | @ASTNode f = rec.as.record.fields
 |  |  | WHILE [ f != 0 ]
 |  |  |  | @ABYSS ft = (map_type)[ c | f.as.rcrd_flds.type ]
 |  |  |  | U64 sz = (LLVMABISizeOfType)[ td_layout | ft ]
 |  |  |  | IF [ sz > biggest ]
 |  |  |  |  | biggest = sz
 |  |  |  |  | widest = ft
 |  |  |  |  \_
 |  |  |  | f = f.as.rcrd_flds.next_field
 |  |  |  \_
 |  |  | ?(ftypes) = widest
 |  |  | n = 1
 |  | ELSE
 |  |  | @ASTNode f = rec.as.record.fields
 |  |  | WHILE [ f != 0 && n < 64 ]
 |  |  |  | ?(ftypes + n) = (map_type)[ c | f.as.rcrd_flds.type ]
 |  |  |  | n = n + 1
 |  |  |  | f = f.as.rcrd_flds.next_field
 |  |  |  \_
 |  |  \_
 |  |
 |  | (LLVMStructSetBody)[ ut.type | ftypes | n | 0 ]
 |  | (free)[ ftypes AS @ABYSS ]
 |  | RET
 |  \_
 |
 | ; TD_ALIAS
 | IF [ (type_lookup)[ c | name ] != 0 ]
 |  | RET
 |  \_
 | @CGType ut = (type_add)[ c | name ]
 | ut.type = (map_type)[ c | td.as.type_def.tdef ]
 | RET
 \_

ABYSS gen_global: [ @CodegenContext c | @ASTNode d ]
 | @C1 nm = d.as.var_decl.ident.as.ident
 | @ABYSS ty = (map_type)[ c | d.as.var_decl.type ]
 | @ABYSS g = (LLVMAddGlobal)[ c.mod | ty | nm ]
 |
 | @ABYSS init = (LLVMConstNull)[ ty ]
 | IF [ d.as.var_decl.init != 0 ]
 |  | @ASTNode lit = (strip)[ d.as.var_decl.init ]
 |  | IF [ lit != 0 && lit.kind == NT_LITERAL ]
 |  |  | init = (gen_literal)[ c | lit ]
 |  |  | ; a constant initialiser may still need narrowing
 |  |  | IF [ (LLVMGetTypeKind)[ (LLVMTypeOf)[ init ] ] == LLVMIntegerTypeKind && (LLVMGetTypeKind)[ ty ] == LLVMIntegerTypeKind ]
 |  |  |  | IF [ (LLVMTypeOf)[ init ] != ty ]
 |  |  |  |  | init = (LLVMConstInt)[ ty | lit.as.literal.as.int_lit AS U64 | 1 ]
 |  |  |  |  \_
 |  |  |  \_
 |  | ELSE
 |  |  | (printf)[ "codegen: global `%s` needs a constant initialiser at %d:%d\n" | nm | d.loc.line | d.loc.col ]
 |  |  | (exit)[ 1 ]
 |  |  \_
 |  \_
 |
 | (LLVMSetInitializer)[ g | init ]
 | (scope_define)[ c | nm | g | ty | d.as.var_decl.type ]
 | RET
 \_

ABYSS codegen_init: [ @CodegenContext c | @C1 module_name | @Meta meta ]
 | c.ctx = (LLVMContextCreate)[]
 | c.mod = (LLVMModuleCreateWithNameInContext)[ module_name | c.ctx ]
 | c.builder = (LLVMCreateBuilderInContext)[ c.ctx ]
 | c.meta = meta
 | c.scope = 0
 | c.fn = 0
 | c.ret_type = 0
 | c.loop_break = 0
 | c.loop_continue = 0
 |
 | (vec_init)[ @(c.types) | SIZE [ CGType ] | 16 ]
 | (vec_init)[ @(c.consts) | SIZE [ CGEnumConst ] | 16 ]
 | (vec_init)[ @(c.strs) | SIZE [ CGStr ] | 16 ]
 |
 | ; Without a data layout every ABI size query is meaningless, which is
 | ; what union layout and SIZE [ T ] are built on.
 | (LLVMInitializeX86TargetInfo)[]
 | (LLVMInitializeX86Target)[]
 | (LLVMInitializeX86TargetMC)[]
 | (LLVMInitializeX86AsmPrinter)[]
 |
 | @C1 triple = (LLVMGetDefaultTargetTriple)[]
 | (LLVMSetTarget)[ c.mod | triple ]
 |
 | @ABYSS target = 0
 | @C1 terr = 0
 | IF [ (LLVMGetTargetFromTriple)[ triple | @target AS @@ABYSS | @terr AS @@C1 ] == 0 ]
 |  | @ABYSS tm = (LLVMCreateTargetMachine)[ target | triple | "generic" | "" | LLVMCodeGenLevelDefault | LLVMRelocDefault | LLVMCodeModelDefault ]
 |  | @ABYSS tdl = (LLVMCreateTargetDataLayout)[ tm ]
 |  | @C1 dl = (LLVMCopyStringRepOfTargetData)[ tdl ]
 |  | (LLVMSetDataLayout)[ c.mod | dl ]
 |  | (LLVMDisposeMessage)[ dl ]
 |  | (LLVMDisposeTargetData)[ tdl ]
 |  | (LLVMDisposeTargetMachine)[ tm ]
 |  \_
 | (LLVMDisposeMessage)[ triple ]
 | RET
 \_

ABYSS codegen_generate: [ @ASTNode root | @CodegenContext c ]
 | ; types first, then every prototype, then the bodies
 | @ASTNode ts = root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | IF [ ts.as.tu_stmt.kind == TUST_TYPE_DEF ]
 |  |  | (gen_type_decl)[ c | ts.as.tu_stmt.tu_stmt ]
 |  |  \_
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 |
 | ts = root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | IF [ ts.as.tu_stmt.kind == TUST_TYPE_DEF ]
 |  |  | (gen_type_def)[ c | ts.as.tu_stmt.tu_stmt ]
 |  |  \_
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 |
 | ts = root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | I32 k = ts.as.tu_stmt.kind
 |  | IF [ k == TUST_FN_DECL ]
 |  |  | (gen_fn_proto)[ c | ts.as.tu_stmt.tu_stmt ]
 |  | ELIF [ k == TUST_FN_DEF ]
 |  |  | (gen_fn_proto)[ c | ts.as.tu_stmt.tu_stmt.as.fn_def.decl ]
 |  |  \_
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 |
 | (scope_push)[ c ]
 |
 | ts = root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | IF [ ts.as.tu_stmt.kind == TUST_VAR_DECL ]
 |  |  | (gen_global)[ c | ts.as.tu_stmt.tu_stmt ]
 |  |  \_
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 |
 | ts = root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | IF [ ts.as.tu_stmt.kind == TUST_FN_DEF ]
 |  |  | (gen_fn_def)[ c | ts.as.tu_stmt.tu_stmt ]
 |  |  \_
 |  | ts = ts.as.tu_stmt.next_tu_stmt
 |  \_
 |
 | (scope_pop)[ c ]
 | RET
 \_

ABYSS codegen_deinit: [ @CodegenContext c | @C1 filename ]
 | @C1 err = 0
 | IF [ (LLVMVerifyModule)[ c.mod | LLVMReturnStatusAction | @err AS @@C1 ] != 0 ]
 |  | IF [ err != 0 ]
 |  |  | (printf)[ "LLVM verify: %s\n" | err ]
 |  |  \_
 |  \_
 |
 | err = 0
 | IF [ (LLVMPrintModuleToFile)[ c.mod | filename | @err AS @@C1 ] != 0 ]
 |  | (printf)[ "failed to write %s\n" | filename ]
 |  \_
 |
 | WHILE [ c.scope != 0 ]
 |  | (scope_pop)[ c ]
 |  \_
 |
 | (vec_deinit)[ @(c.types) ]
 | (vec_deinit)[ @(c.consts) ]
 | (vec_deinit)[ @(c.strs) ]
 |
 | (LLVMDisposeBuilder)[ c.builder ]
 | (LLVMDisposeModule)[ c.mod ]
 | (LLVMContextDispose)[ c.ctx ]
 | RET
 \_
