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
!USES <diag.pl>
!USES <parser.pl>
!USES <../extern/llvm.pl>
!USES <../lib/vector.pl>
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
 | Vector<CGSym> syms
 | @CGScope      parent
 \_

TYPE CGType: STRUCT
 | @C1      name
 | @ABYSS   type
 | @ASTNode record
 | B1       is_union
 | B1       body_set
 | B1       packed      ; + PACKED: its fields need not be aligned
 \_

TYPE CGEnumConst: STRUCT
 | @C1 name
 | I64 value
 \_

TYPE CGStr: STRUCT
 | @C1    text
 | @ABYSS global
 \_

; What the driver asked for. The triple is 0 for the machine plc runs on;
; the CPU 0 for the triple's generic one.
@C1 cg_triple
@C1 cg_cpu
I32 cg_opt             ; -O0 .. -O3
I32 cg_emit            ; CG_IR, CG_ASM or CG_OBJ
B1  cg_data_sections   ; every global in a section of its own, .data.<name>

TYPE CgEmit: ENUM
 | CG_IR
 | CG_ASM
 | CG_OBJ
 \_

TYPE CodegenContext: STRUCT
 | @ABYSS   ctx
 | @ABYSS   mod
 | @ABYSS   builder
 | @Meta    meta
 | @CGScope scope
 | Vector<CGType>      types
 | Vector<CGEnumConst> consts
 | Vector<CGStr>       strs
 | @ABYSS   fn
 | @ABYSS   ret_type
 | @ABYSS   loop_break
 | @ABYSS   loop_continue
 | @ABYSS   tm          ; the target machine: layout, passes, machine code
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
 | B1     vol       ; VOLATILE: every load and store of it stays, in order
 | B1     unal      ; inside a PACKED struct: accessed a byte at a time's alignment
 \_

ABYSS cg_fatal: [ @C1 msg ]
 | (diag_internal)[ "codegen: %s" | msg ]
 | RET
 \_

; --- scopes ---------------------------------------------------------------

ABYSS scope_push: [ @CodegenContext c ]
 | @CGScope s = (malloc)[ SIZE [ CGScope ] ] AS @CGScope
 | (s.syms.init)[ 16 ]
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
 | (s.syms.deinit)[]
 | (free)[ s AS @ABYSS ]
 | RET
 \_

ABYSS scope_define: [ @CodegenContext c | @C1 name | @ABYSS v | @ABYSS t | @ASTNode ntype ]
 | CGSym sym
 | sym.name  = name
 | sym.value = v
 | sym.type  = t
 | sym.ntype = ntype
 | (c.scope.syms.push)[ sym ]
 | RET
 \_

@CGSym scope_lookup: [ @CodegenContext c | @C1 name ]
 | @CGScope s = c.scope
 | WHILE [ s != 0 ]
 |  | U64 n = (s.syms.size)[]
 |  | U64 i = n
 |  | WHILE [ i > 0 ]
 |  |  | i = i - 1
 |  |  | @CGSym sym = (s.syms.at)[ i ]
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
 | WHILE [ i < (c.types.size)[] ]
 |  | @CGType t = (c.types.at)[ i ]
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
 | (c.types.push)[ t ]
 | RET [ (c.types.last)[] ]
 \_

@CGType type_of_struct: [ @CodegenContext c | @ABYSS ty ]
 | U64 i = 0
 | WHILE [ i < (c.types.size)[] ]
 |  | @CGType t = (c.types.at)[ i ]
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
 | (c.consts.push)[ e ]
 | RET
 \_

B1 enum_const_get: [ @CodegenContext c | @C1 name | @I64 out ]
 | U64 i = 0
 | WHILE [ i < (c.consts.size)[] ]
 |  | @CGEnumConst e = (c.consts.at)[ i ]
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
 | ELIF [ tn.as.type.kind == TT_FN_TYPE ]
 |  | base = (LLVMPointerType)[ (LLVMInt8TypeInContext)[ c.ctx ] | 0 ]
 | ELSE
 |  | @CGType ut = (type_lookup)[ c | tn.as.type.type.as.ident ]
 |  | IF [ ut == 0 ]
 |  |  | (diag_fatal)[ tn.loc | "unknown type `%s`%s" | tn.as.type.type.as.ident | "" ]
 |  |  \_
 |  | base = ut.type
 |  \_
 |
 | U64 i = 0
 | WHILE [ i < tn.as.type.ptrs ]
 |  | base = (LLVMPointerType)[ base | 0 ]
 |  | i = i + 1
 |  \_
 | IF [ tn.as.type.arr > 0 ]
 |  | base = (LLVMArrayType)[ base | tn.as.type.arr AS I32 ]
 |  \_
 | RET [ base ]
 \_

; What a declared variable or field reads as. An array is used as a
; pointer to its first element, so it carries one more pointer level.
TypeInfo decl_info: [ @ASTNode tn ]
 | TypeInfo r
 | r.node = tn
 | r.ptrs = tn.as.type.ptrs
 | IF [ tn.as.type.arr > 0 ]
 |  | r.ptrs = r.ptrs + 1
 |  \_
 | RET [ r ]
 \_

; Is the object a TypeInfo describes VOLATILE? Its level in the declared
; type is how many pointers the declaration has, less those still left;
; an array and its elements are one object, level 0.
B1 ti_volatile: [ TypeInfo ti ]
 | IF [ ti.node == 0 ]
 |  | RET [ FALSE ]
 |  \_
 | I64 level = (ti.node.as.type.ptrs AS I64) - (ti.ptrs AS I64)
 | IF [ level < 0 && ti.node.as.type.arr > 0 ]
 |  | level = 0
 |  \_
 | IF [ level < 0 ]
 |  | RET [ FALSE ]
 |  \_
 | RET [ ((quals_at)[ ti.node.as.type.quals | level AS U32 ] & QUAL_VOLATILE) != 0 ]
 \_

; A load or store, volatile when the place is, and claiming no more than
; byte alignment inside a PACKED struct: a Cortex-M0 faults on anything
; misaligned, and LLVM would otherwise assume the type's alignment.
@ABYSS vload: [ @CodegenContext c | @ABYSS ty | @ABYSS ptr | B1 vol | B1 unal | @C1 name ]
 | @ABYSS v = (LLVMBuildLoad2)[ c.builder | ty | ptr | name ]
 | IF [ vol ]
 |  | (LLVMSetVolatile)[ v | 1 ]
 |  \_
 | IF [ unal ]
 |  | (LLVMSetAlignment)[ v | 1 ]
 |  \_
 | RET [ v ]
 \_

@ABYSS vstore: [ @CodegenContext c | @ABYSS v | @ABYSS ptr | B1 vol | B1 unal ]
 | @ABYSS st = (LLVMBuildStore)[ c.builder | v | ptr ]
 | IF [ vol ]
 |  | (LLVMSetVolatile)[ st | 1 ]
 |  \_
 | IF [ unal ]
 |  | (LLVMSetAlignment)[ st | 1 ]
 |  \_
 | RET [ st ]
 \_

; Does the place e name lie inside a PACKED struct? A field of one, or of
; a struct or array held in one; a pointer's target counts as aligned.
B1 in_packed: [ @CodegenContext c | @ASTNode e ]
 | @ASTNode n = (strip)[ e ]
 | IF [ n == 0 || n.kind != NT_BIN_OP ]
 |  | RET [ FALSE ]
 |  \_
 | TypeInfo ti = (infer)[ c | n.as.bin_op.left ]
 | IF [ ti.node == 0 ]
 |  | RET [ FALSE ]
 |  \_
 | IF [ n.as.bin_op.kind == BOT_MEMBER ]
 |  | TypeInfo flat
 |  | flat.node = ti.node
 |  | flat.ptrs = 0
 |  | @ABYSS sty = (llvm_of)[ c | flat ]
 |  | IF [ sty != 0 ]
 |  |  | @CGType ut = (type_of_struct)[ c | sty ]
 |  |  | IF [ ut != 0 && ut.packed ]
 |  |  |  | RET [ TRUE ]
 |  |  |  \_
 |  |  \_
 |  | RET [ ti.ptrs == 0 && (in_packed)[ c | n.as.bin_op.left ] ]
 |  \_
 | IF [ n.as.bin_op.kind == BOT_INDEX ]
 |  | ; the elements of an array field lie where the field does
 |  | B1 is_array = ti.node.as.type.arr > 0 && ti.ptrs == ti.node.as.type.ptrs + 1
 |  | RET [ is_array && (in_packed)[ c | n.as.bin_op.left ] ]
 |  \_
 | RET [ FALSE ]
 \_

; A declared type's own level, the thing declared, is VOLATILE.
B1 tn_volatile: [ @ASTNode tn ]
 | RET [ tn != 0 && ((quals_at)[ tn.as.type.quals | 0 ] & QUAL_VOLATILE) != 0 ]
 \_

B1 is_float_ty: [ @ABYSS ty ]
 | I32 k = (LLVMGetTypeKind)[ ty ]
 | RET [ k == LLVMFloatTypeKind || k == LLVMDoubleTypeKind ]
 \_

@ABYSS llvm_of: [ @CodegenContext c | TypeInfo ti ]
 | IF [ ti.node == 0 ]
 |  | RET [ 0 ]
 |  \_
 |
 | @ABYSS base = 0
 | IF [ ti.node.as.type.kind == TT_BASE_TYPE ]
 |  | base = (map_base_type)[ c | ti.node.as.type.type.as.base_type ]
 | ELIF [ ti.node.as.type.kind == TT_FN_TYPE ]
 |  | base = (LLVMPointerType)[ (LLVMInt8TypeInContext)[ c.ctx ] | 0 ]
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
 |  | RET [ (decl_info)[ s.ntype ] ]
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
 |  |  | ; @a of an array is the address it already reads as
 |  |  | IF [ i.node.as.type.arr > 0 && i.ptrs == i.node.as.type.ptrs + 1 ]
 |  |  |  | RET [ i ]
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
 |  |  | RET [ (decl_info)[ ftype ] ]
 |  |  \_
 |  | IF [ n.as.bin_op.kind == BOT_INDEX ]
 |  |  | TypeInfo base = (infer)[ c | n.as.bin_op.left ]
 |  |  | IF [ base.node == 0 || base.ptrs == 0 ]
 |  |  |  | RET [ none ]
 |  |  |  \_
 |  |  | base.ptrs = base.ptrs - 1
 |  |  | RET [ base ]
 |  |  \_
 |  | RET [ (infer)[ c | n.as.bin_op.left ] ]
 |  \_
 |
 | IF [ n.kind == NT_FN_CALL ]
 |  | @ASTNode sig = (callee_sig)[ c | n ]
 |  | IF [ sig == 0 ]
 |  |  | RET [ none ]
 |  |  \_
 |  | RET [ (decl_info)[ (sig_ret)[ sig ] ] ]
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
 |  | ; a truth value is `!= 0`, not the low bit
 |  | IF [ tw == 1 ]
 |  |  | RET [ (LLVMBuildICmp)[ c.builder | LLVMIntNE | v | (LLVMConstInt)[ from | 0 | 0 ] | "tobool" ] ]
 |  |  \_
 |  | ; TRUE widens to 1, not -1
 |  | IF [ fw == 1 ]
 |  |  | RET [ (LLVMBuildZExt)[ c.builder | v | to | "zext" ] ]
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
 |  | IF [ (LLVMGetIntTypeWidth)[ to ] == 1 ]
 |  |  | RET [ (LLVMBuildICmp)[ c.builder | LLVMIntNE | v | (LLVMConstPointerNull)[ from ] | "tobool" ] ]
 |  |  \_
 |  | RET [ (LLVMBuildPtrToInt)[ c.builder | v | to | "ptoi" ] ]
 |  \_
 | IF [ fk == LLVMPointerTypeKind && tk == LLVMPointerTypeKind ]
 |  | RET [ v ]
 |  \_
 | IF [ fk == LLVMIntegerTypeKind && (tk == LLVMFloatTypeKind || tk == LLVMDoubleTypeKind) ]
 |  | RET [ (LLVMBuildSIToFP)[ c.builder | v | to | "sitofp" ] ]
 |  \_
 | IF [ (is_float_ty)[ from ] && (is_float_ty)[ to ] ]
 |  | IF [ fk == LLVMFloatTypeKind ]
 |  |  | RET [ (LLVMBuildFPExt)[ c.builder | v | to | "fpext" ] ]
 |  |  \_
 |  | RET [ (LLVMBuildFPTrunc)[ c.builder | v | to | "fptrunc" ] ]
 |  \_
 | IF [ (is_float_ty)[ from ] && tk == LLVMIntegerTypeKind ]
 |  | ; a truth value is `!= 0`, not the low bit
 |  | IF [ (LLVMGetIntTypeWidth)[ to ] == 1 ]
 |  |  | RET [ (LLVMBuildFCmp)[ c.builder | LLVMRealUNE | v | (LLVMConstReal)[ from | 0 ] | "tobool" ] ]
 |  |  \_
 |  | RET [ (LLVMBuildFPToSI)[ c.builder | v | to | "fptosi" ] ]
 |  \_
 |
 | IF [ fk == LLVMStructTypeKind || tk == LLVMStructTypeKind ]
 |  | (cg_fatal)[ "cannot convert to or from an aggregate" ]
 |  \_
 | RET [ v ]
 \_

; coerce, knowing the expression v came from: an unsigned integer widens
; with zeros rather than copies of its top bit.
@ABYSS coerce_e: [ @CodegenContext c | @ABYSS v | @ABYSS to | @ASTNode e ]
 | IF [ v == 0 || to == 0 ]
 |  | RET [ v ]
 |  \_
 | @ABYSS from = (LLVMTypeOf)[ v ]
 | IF [ (LLVMGetTypeKind)[ from ] == LLVMIntegerTypeKind && (LLVMGetTypeKind)[ to ] == LLVMIntegerTypeKind ]
 |  | I32 fw = (LLVMGetIntTypeWidth)[ from ]
 |  | IF [ fw > 1 && fw < (LLVMGetIntTypeWidth)[ to ] && (is_unsigned_expr)[ c | e ] ]
 |  |  | RET [ (LLVMBuildZExt)[ c.builder | v | to | "zext" ] ]
 |  |  \_
 |  \_
 | IF [ (LLVMGetTypeKind)[ from ] == LLVMIntegerTypeKind && (is_float_ty)[ to ] ]
 |  | RET [ (to_float)[ c | v | e | to ] ]
 |  \_
 | RET [ (coerce)[ c | v | to ] ]
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
 | WHILE [ i < (c.strs.size)[] ]
 |  | @CGStr s = (c.strs.at)[ i ]
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
 | (snprintf)[ name | 32 | ".str.%d" | (c.strs.size)[] AS I32 ]
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
 | (c.strs.push)[ entry ]
 | RET [ g ]
 \_

B1 gen_lvalue: [ @CodegenContext c | @ASTNode e | @LValue out ]
 | out.vol = FALSE
 | out.unal = FALSE
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
 |  | out.vol = (tn_volatile)[ s.ntype ]
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
 |  |  | out.vol = (ti_volatile)[ inner ]
 |  |  \_
 |  | IF [ pointee == 0 ]
 |  |  | pointee = (LLVMInt8TypeInContext)[ c.ctx ]
 |  |  \_
 |  | out.ptr = (gen_expr)[ c | n.as.uny_op.operand ]
 |  | out.type = pointee
 |  | RET [ out.ptr != 0 ]
 |  \_
 |
 | ; x{i} -- the element i places past what x points at
 | IF [ n.kind == NT_BIN_OP && n.as.bin_op.kind == BOT_INDEX ]
 |  | TypeInfo ti = (infer)[ c | n.as.bin_op.left ]
 |  | IF [ ti.node == 0 || ti.ptrs == 0 ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | TypeInfo inner
 |  | inner.node = ti.node
 |  | inner.ptrs = ti.ptrs - 1
 |  | @ABYSS elem = (llvm_of)[ c | inner ]
 |  | @ABYSS base = (gen_expr)[ c | n.as.bin_op.left ]
 |  | IF [ elem == 0 || base == 0 ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  |
 |  | @ABYSS iv = (gen_expr)[ c | n.as.bin_op.right ]
 |  | @ABYSS i64 = (LLVMInt64TypeInContext)[ c.ctx ]
 |  | IF [ (LLVMTypeOf)[ iv ] != i64 ]
 |  |  | IF [ (is_unsigned_expr)[ c | n.as.bin_op.right ] ]
 |  |  |  | iv = (LLVMBuildZExt)[ c.builder | iv | i64 | "idx" ]
 |  |  | ELSE
 |  |  |  | iv = (coerce)[ c | iv | i64 ]
 |  |  |  \_
 |  |  \_
 |  | @@ABYSS idx = (malloc)[ 8 ] AS @@ABYSS
 |  | ?(idx) = iv
 |  | out.ptr = (LLVMBuildGEP2)[ c.builder | elem | base | idx | 1 | "elem" ]
 |  | out.type = elem
 |  | out.vol = (ti_volatile)[ inner ]
 |  | out.unal = (in_packed)[ c | n ]
 |  | (free)[ idx AS @ABYSS ]
 |  | RET [ TRUE ]
 |  \_
 |
 | ; a.b -- GEP into a struct, or the same address for a union
 | IF [ n.kind == NT_BIN_OP && n.as.bin_op.kind == BOT_MEMBER ]
 |  | LValue base
 |  | @ABYSS sty = 0
 |  | @ABYSS sptr = 0
 |  | B1 ovol = FALSE
 |  |
 |  | IF [ (gen_lvalue)[ c | n.as.bin_op.left | @base ] ]
 |  |  | sty = base.type
 |  |  | sptr = base.ptr
 |  |  | ovol = base.vol
 |  | ELSE
 |  |  | ; not a variable: a call's result, say. A pointer already is the
 |  |  | ; object's address; a struct by value goes through a temporary.
 |  |  | TypeInfo ti = (infer)[ c | n.as.bin_op.left ]
 |  |  | IF [ ti.node == 0 ]
 |  |  |  | RET [ FALSE ]
 |  |  |  \_
 |  |  | @ABYSS v = (gen_expr)[ c | n.as.bin_op.left ]
 |  |  | IF [ v == 0 ]
 |  |  |  | RET [ FALSE ]
 |  |  |  \_
 |  |  | IF [ ti.ptrs == 0 ]
 |  |  |  | sty = (LLVMTypeOf)[ v ]
 |  |  |  | sptr = (entry_alloca)[ c | sty | "tmp" ]
 |  |  |  | (LLVMBuildStore)[ c.builder | v | sptr ]
 |  |  | ELSE
 |  |  |  | TypeInfo inner
 |  |  |  | inner.node = ti.node
 |  |  |  | inner.ptrs = ti.ptrs - 1
 |  |  |  | sptr = v
 |  |  |  | sty = (llvm_of)[ c | inner ]
 |  |  |  | ovol = (ti_volatile)[ inner ]
 |  |  |  \_
 |  |  | IF [ sty == 0 ]
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
 |  |  | ; the pointer is loaded as it is declared; the object is what it
 |  |  | ; points at, volatile or not
 |  |  | sptr = (vload)[ c | sty | sptr | ovol | base.unal | "objptr" ]
 |  |  | sty = pointee
 |  |  | ovol = (ti_volatile)[ inner ]
 |  |  \_
 |  |
 |  | IF [ (LLVMGetTypeKind)[ sty ] != LLVMStructTypeKind ]
 |  |  | (diag_fatal)[ n.loc | "`.` applied to a non-aggregate%s%s" | "" | "" ]
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
 |  |  | (diag_fatal)[ n.loc | "no field `%s` in `%s`" | fname.as.ident | ut.name ]
 |  |  \_
 |  |
 |  | ; a field of a volatile object is volatile, and so is a VOLATILE field
 |  | out.vol = ovol || (tn_volatile)[ ftype ]
 |  | out.unal = (in_packed)[ c | n ]
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

; (obj.method)[ ... ] lands in "<obj's type>.method". The type comes from
; the LLVM struct, so an alias of a class finds the class's methods too.
; `ptrs` gets how many pointers obj itself carries.
@C1 method_fn: [ @CodegenContext c | @ASTNode call | @U64 ptrs ]
 | TypeInfo ti = (infer)[ c | call.as.fn_call.recv ]
 | IF [ ti.node == 0 ]
 |  | RET [ 0 ]
 |  \_
 | TypeInfo flat
 | flat.node = ti.node
 | flat.ptrs = 0
 | @ABYSS sty = (llvm_of)[ c | flat ]
 | IF [ sty == 0 ]
 |  | RET [ 0 ]
 |  \_
 | @CGType ut = (type_of_struct)[ c | sty ]
 | IF [ ut == 0 ]
 |  | RET [ 0 ]
 |  \_
 | ?(ptrs) = ti.ptrs
 | RET [ (method_name)[ ut.name | call.as.fn_call.ident.as.ident ] ]
 \_

; A type written through aliases -- TYPE BinOp: FN I32 [ I32 ] -- as the
; type they name. Only a bare alias is followed; @BinOp is a pointer.
@ASTNode unalias: [ @CodegenContext c | @ASTNode tn ]
 | I32 hops = 0
 | WHILE [ tn != 0 && tn.as.type.kind == TT_USER_TYPE && tn.as.type.ptrs == 0 && hops < 16 ]
 |  | @ABYSS d = 0
 |  | IF [ (map_get)[ @(c.meta.types) | tn.as.type.type.as.ident | @d AS @@ABYSS ] != 1 ]
 |  |  | RET [ tn ]
 |  |  \_
 |  | @ASTNode td = d AS @ASTNode
 |  | IF [ td.as.type_def.kind != TD_ALIAS ]
 |  |  | RET [ tn ]
 |  |  \_
 |  | tn = td.as.type_def.tdef
 |  | hops += 1
 |  \_
 | RET [ tn ]
 \_

; The FN type an expression holds when it can be called, or 0. What
; counts is the pointer depth left after any `?`: ?pp of an @FN is callable.
@ASTNode fn_type_of: [ @CodegenContext c | @ASTNode e ]
 | TypeInfo ti = (infer)[ c | e ]
 | IF [ ti.node == 0 || ti.ptrs != 0 ]
 |  | RET [ 0 ]
 |  \_
 | @ASTNode t = ti.node
 | IF [ t.as.type.kind == TT_USER_TYPE ]
 |  | ; the name's definition, whatever pointers were written around it
 |  | I32 hops = 0
 |  | @ABYSS d = 0
 |  | WHILE [ t.as.type.kind == TT_USER_TYPE && hops < 16 && (map_get)[ @(c.meta.types) | t.as.type.type.as.ident | @d AS @@ABYSS ] == 1 ]
 |  |  | @ASTNode td = d AS @ASTNode
 |  |  | IF [ td.as.type_def.kind != TD_ALIAS ]
 |  |  |  | RET [ 0 ]
 |  |  |  \_
 |  |  | t = td.as.type_def.tdef
 |  |  | hops += 1
 |  |  \_
 |  \_
 | IF [ t.as.type.kind != TT_FN_TYPE ]
 |  | RET [ 0 ]
 |  \_
 | RET [ t ]
 \_

; A variable declared with an FN type, callable by its bare name.
@CGSym fn_var: [ @CodegenContext c | @C1 name ]
 | @CGSym s = (scope_lookup)[ c | name ]
 | IF [ s == 0 || s.ntype == 0 ]
 |  | RET [ 0 ]
 |  \_
 | IF [ s.ntype.as.type.arr != 0 ]
 |  | RET [ 0 ]
 |  \_
 | @ASTNode t = (unalias)[ c | s.ntype ]
 | IF [ t.as.type.kind != TT_FN_TYPE || t.as.type.ptrs != 0 ]
 |  | RET [ 0 ]
 |  \_
 | RET [ s ]
 \_

; The class an ANONYMOUS call names, as check.pl finds it: a type written
; in the expression, or a name that is no variable but a TYPE. 0 for an
; object.
@C1 static_owner: [ @CodegenContext c | @ASTNode recv ]
 | IF [ recv == 0 ]
 |  | RET [ NULL ]
 |  \_
 | @ASTNode r = (strip)[ recv ]
 | IF [ r.kind == NT_TYPE && r.as.type.kind == TT_USER_TYPE && r.as.type.ptrs == 0 ]
 |  | RET [ r.as.type.type.as.ident ]
 |  \_
 | @ABYSS d = 0
 | IF [ r.kind == NT_IDENT && (scope_lookup)[ c | r.as.ident ] == 0 && (map_get)[ @(c.meta.types) | r.as.ident | @d AS @@ABYSS ] == 1 ]
 |  | RET [ r.as.ident ]
 |  \_
 | RET [ NULL ]
 \_

; The signature a call goes through, as check.pl resolves it: a variable
; holding a function pointer before a function of that name, and a method
; before a pointer field of that name.
@ASTNode callee_sig: [ @CodegenContext c | @ASTNode n ]
 | IF [ n.as.fn_call.ident == 0 ]
 |  | RET [ (fn_type_of)[ c | n.as.fn_call.target ] ]
 |  \_
 | @ABYSS d = 0
 | @C1 cls = (static_owner)[ c | n.as.fn_call.recv ]
 | IF [ cls != NULL ]
 |  | IF [ (map_get)[ @(c.meta.func_decls) | (method_name)[ cls | n.as.fn_call.ident.as.ident ] | @d AS @@ABYSS ] == 1 ]
 |  |  | RET [ d AS @ASTNode ]
 |  |  \_
 |  | RET [ 0 ]
 |  \_
 | IF [ n.as.fn_call.recv != 0 ]
 |  | U64 rp = 0
 |  | @C1 mname = (method_fn)[ c | n | @rp ]
 |  | IF [ mname != 0 && (map_get)[ @(c.meta.func_decls) | mname | @d AS @@ABYSS ] == 1 ]
 |  |  | RET [ d AS @ASTNode ]
 |  |  \_
 |  | RET [ (fn_type_of)[ c | n.as.fn_call.target ] ]
 |  \_
 | @CGSym s = (fn_var)[ c | n.as.fn_call.ident.as.ident ]
 | IF [ s != 0 ]
 |  | RET [ (unalias)[ c | s.ntype ] ]
 |  \_
 | IF [ (map_get)[ @(c.meta.func_decls) | n.as.fn_call.ident.as.ident | @d AS @@ABYSS ] == 1 ]
 |  | RET [ d AS @ASTNode ]
 |  \_
 | RET [ 0 ]
 \_

; The LLVM function type behind an FN type.
@ABYSS fn_llvm_type: [ @CodegenContext c | @ASTNode sig ]
 | @@ABYSS ptypes = (malloc)[ 64 * 8 ] AS @@ABYSS
 | I32 n = 0
 | I32 va = 0
 | @ASTNode p = (sig_params)[ sig ]
 | WHILE [ p != 0 && n < 64 ]
 |  | IF [ (sig_is_va)[ p ] ]
 |  |  | va = 1
 |  | ELSE
 |  |  | ?(ptypes + n) = (map_type)[ c | (sig_ptype)[ p ] ]
 |  |  | n = n + 1
 |  |  \_
 |  | p = (sig_next)[ p ]
 |  \_
 | @ABYSS fty = (LLVMFunctionType)[ (map_type)[ c | (sig_ret)[ sig ] ] | ptypes | n | va ]
 | (free)[ ptypes AS @ABYSS ]
 | RET [ fty ]
 \_

@ABYSS gen_call: [ @CodegenContext c | @ASTNode call ]
 | @C1 name = "a function pointer"
 | U64 rptrs = 0
 | B1 is_method = FALSE
 | @ABYSS callee = 0
 | @ASTNode ftn = 0
 |
 | IF [ call.as.fn_call.ident == 0 ]
 |  | ; (expr)[ ... ]
 |  | ftn = (fn_type_of)[ c | call.as.fn_call.target ]
 |  | IF [ ftn != 0 ]
 |  |  | callee = (gen_expr)[ c | call.as.fn_call.target ]
 |  |  \_
 | ELIF [ (static_owner)[ c | call.as.fn_call.recv ] != NULL ]
 |  | ; (Type.name)[ ... ]: an ANONYMOUS method, called like a function
 |  | name = (method_name)[ (static_owner)[ c | call.as.fn_call.recv ] | call.as.fn_call.ident.as.ident ]
 |  | callee = (LLVMGetNamedFunction)[ c.mod | name ]
 | ELIF [ call.as.fn_call.recv != 0 ]
 |  | ; (obj.name)[ ... ]: a method, else a function pointer in a field
 |  | name = call.as.fn_call.ident.as.ident
 |  | @C1 mname = (method_fn)[ c | call | @rptrs ]
 |  | IF [ mname != 0 ]
 |  |  | callee = (LLVMGetNamedFunction)[ c.mod | mname ]
 |  |  \_
 |  | IF [ callee != 0 ]
 |  |  | is_method = TRUE
 |  |  | name = mname
 |  | ELSE
 |  |  | ftn = (fn_type_of)[ c | call.as.fn_call.target ]
 |  |  | IF [ ftn != 0 ]
 |  |  |  | callee = (gen_expr)[ c | call.as.fn_call.target ]
 |  |  |  \_
 |  |  \_
 |  | IF [ callee == 0 ]
 |  |  | (diag_fatal)[ call.loc | "cannot tell what `%s` calls%s" | name | "" ]
 |  |  \_
 | ELSE
 |  | ; (name)[ ... ]: a variable holding a function pointer, else a function
 |  | name = call.as.fn_call.ident.as.ident
 |  | @CGSym s = (fn_var)[ c | name ]
 |  | IF [ s != 0 ]
 |  |  | ftn = (unalias)[ c | s.ntype ]
 |  |  | callee = (LLVMBuildLoad2)[ c.builder | s.type | s.value | name ]
 |  |  | name = "a function pointer"
 |  | ELSE
 |  |  | callee = (LLVMGetNamedFunction)[ c.mod | name ]
 |  |  \_
 |  \_
 | IF [ callee == 0 ]
 |  | (diag_fatal)[ call.loc | "call to undeclared function `%s`%s" | name | "" ]
 |  \_
 |
 | @ABYSS fty = 0
 | IF [ ftn != 0 ]
 |  | fty = (fn_llvm_type)[ c | ftn ]
 | ELSE
 |  | fty = (LLVMGlobalGetValueType)[ callee ]
 |  \_
 | I32 nparams = (LLVMCountParamTypes)[ fty ]
 |
 | @@ABYSS ptypes = (malloc)[ 64 * 8 ] AS @@ABYSS
 | (LLVMGetParamTypes)[ fty | ptypes ]
 |
 | @@ABYSS args = (malloc)[ 64 * 8 ] AS @@ABYSS
 | I32 n = 0
 |
 | ; a method's first argument is the address of its object
 | IF [ is_method ]
 |  | @ASTNode recv = call.as.fn_call.recv
 |  | @ABYSS self = 0
 |  | IF [ rptrs > 0 ]
 |  |  | self = (gen_expr)[ c | recv ]
 |  | ELSE
 |  |  | LValue lv
 |  |  | IF [ (gen_lvalue)[ c | recv | @lv ] ]
 |  |  |  | self = lv.ptr
 |  |  | ELSE
 |  |  |  | ; a temporary, such as a struct returned by value
 |  |  |  | @ABYSS v = (gen_expr)[ c | recv ]
 |  |  |  | self = (entry_alloca)[ c | (LLVMTypeOf)[ v ] | "recv" ]
 |  |  |  | (LLVMBuildStore)[ c.builder | v | self ]
 |  |  |  \_
 |  |  \_
 |  | ?(args) = self
 |  | n = 1
 |  \_
 |
 | @ASTNode a = call.as.fn_call.args
 | WHILE [ a != 0 && n < 64 ]
 |  | @ABYSS v = (gen_expr)[ c | a.as.argument.argument ]
 |  | IF [ v == 0 ]
 |  |  | (diag_fatal)[ a.loc | "could not evaluate argument %s to `%s`" | (itoa)[ n + 1 ] | name ]
 |  |  \_
 |  |
 |  | IF [ n < nparams ]
 |  |  | v = (coerce_e)[ c | v | ?(ptypes + n) | a.as.argument.argument ]
 |  | ELSE
 |  |  | ; C variadic default promotion, respecting signedness
 |  |  | @ABYSS vt = (LLVMTypeOf)[ v ]
 |  |  | IF [ (LLVMGetTypeKind)[ vt ] == LLVMFloatTypeKind ]
 |  |  |  | v = (LLVMBuildFPExt)[ c.builder | v | (LLVMDoubleTypeInContext)[ c.ctx ] | "vapromo" ]
 |  |  |  \_
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

; An integer becomes the float `to` -- unsigned ones as unsigned -- and a
; float is widened or narrowed to it.
@ABYSS to_float: [ @CodegenContext c | @ABYSS v | @ASTNode e | @ABYSS to ]
 | @ABYSS from = (LLVMTypeOf)[ v ]
 | IF [ from == to ]
 |  | RET [ v ]
 |  \_
 | IF [ (LLVMGetTypeKind)[ from ] == LLVMIntegerTypeKind ]
 |  | IF [ (LLVMGetIntTypeWidth)[ from ] == 1 || (is_unsigned_expr)[ c | e ] ]
 |  |  | RET [ (LLVMBuildUIToFP)[ c.builder | v | to | "uitofp" ] ]
 |  |  \_
 |  | RET [ (LLVMBuildSIToFP)[ c.builder | v | to | "sitofp" ] ]
 |  \_
 | RET [ (coerce)[ c | v | to ] ]
 \_

; Either side is a float: both become the wider float type.
@ABYSS gen_float_binop: [ @CodegenContext c | @ASTNode n | @ABYSS l | @ABYSS r ]
 | I32 k = n.as.bin_op.kind
 | @ABYSS ft = (LLVMFloatTypeInContext)[ c.ctx ]
 | IF [ (LLVMGetTypeKind)[ (LLVMTypeOf)[ l ] ] == LLVMDoubleTypeKind || (LLVMGetTypeKind)[ (LLVMTypeOf)[ r ] ] == LLVMDoubleTypeKind ]
 |  | ft = (LLVMDoubleTypeInContext)[ c.ctx ]
 |  \_
 | l = (to_float)[ c | l | n.as.bin_op.left | ft ]
 | r = (to_float)[ c | r | n.as.bin_op.right | ft ]
 |
 | IF [ k == BOT_PLUS ]
 |  | RET [ (LLVMBuildFAdd)[ c.builder | l | r | "fadd" ] ]
 |  \_
 | IF [ k == BOT_MINUS ]
 |  | RET [ (LLVMBuildFSub)[ c.builder | l | r | "fsub" ] ]
 |  \_
 | IF [ k == BOT_MULT ]
 |  | RET [ (LLVMBuildFMul)[ c.builder | l | r | "fmul" ] ]
 |  \_
 | IF [ k == BOT_DIV ]
 |  | RET [ (LLVMBuildFDiv)[ c.builder | l | r | "fdiv" ] ]
 |  \_
 | IF [ k == BOT_MOD ]
 |  | RET [ (LLVMBuildFRem)[ c.builder | l | r | "frem" ] ]
 |  \_
 |
 | ; ordered comparisons are false on NaN; != is the unordered one, so
 | ; NaN != NaN holds, as in C
 | I32 p = -1
 | IF [ k == BOT_EQUAL ]
 |  | p = LLVMRealOEQ
 | ELIF [ k == BOT_NEQ ]
 |  | p = LLVMRealUNE
 | ELIF [ k == BOT_LESS ]
 |  | p = LLVMRealOLT
 | ELIF [ k == BOT_LEQ ]
 |  | p = LLVMRealOLE
 | ELIF [ k == BOT_GREAT ]
 |  | p = LLVMRealOGT
 | ELIF [ k == BOT_GEQ ]
 |  | p = LLVMRealOGE
 |  \_
 | IF [ p < 0 ]
 |  | (diag_fatal)[ n.loc | "operator not defined on floats%s%s" | "" | "" ]
 |  \_
 | RET [ (LLVMBuildFCmp)[ c.builder | p | l | r | "fcmp" ] ]
 \_

@ABYSS gen_binop: [ @CodegenContext c | @ASTNode n ]
 | I32 k = n.as.bin_op.kind
 |
 | IF [ k == BOT_ASSIGN ]
 |  | LValue lv
 |  | IF [ !(gen_lvalue)[ c | n.as.bin_op.left | @lv ] ]
 |  |  | (diag_fatal)[ n.loc | "left side of `=` is not assignable%s%s" | "" | "" ]
 |  |  \_
 |  | @ABYSS v = (coerce_e)[ c | (gen_expr)[ c | n.as.bin_op.right ] | lv.type | n.as.bin_op.right ]
 |  | IF [ v == 0 ]
 |  |  | (diag_fatal)[ n.loc | "could not evaluate the right side of `=`%s%s" | "" | "" ]
 |  |  \_
 |  | (vstore)[ c | v | lv.ptr | lv.vol | lv.unal ]
 |  | RET [ v ]
 |  \_
 |
 | IF [ k == BOT_MEMBER ]
 |  | LValue lv
 |  | IF [ !(gen_lvalue)[ c | n | @lv ] ]
 |  |  | (diag_fatal)[ n.loc | "cannot resolve member access%s%s" | "" | "" ]
 |  |  \_
 |  | ; an array field reads as the address of its first element
 |  | IF [ (LLVMGetTypeKind)[ lv.type ] == LLVMArrayTypeKind ]
 |  |  | RET [ lv.ptr ]
 |  |  \_
 |  | RET [ (vload)[ c | lv.type | lv.ptr | lv.vol | lv.unal | "fldval" ] ]
 |  \_
 |
 | IF [ k == BOT_INDEX ]
 |  | LValue lv
 |  | IF [ !(gen_lvalue)[ c | n | @lv ] ]
 |  |  | (diag_fatal)[ n.loc | "cannot index this%s%s" | "" | "" ]
 |  |  \_
 |  | RET [ (vload)[ c | lv.type | lv.ptr | lv.vol | lv.unal | "elemval" ] ]
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
 | IF [ (is_float_ty)[ (LLVMTypeOf)[ l ] ] || (is_float_ty)[ (LLVMTypeOf)[ r ] ] ]
 |  | RET [ (gen_float_binop)[ c | n | l | r ] ]
 |  \_
 |
 | I32 lk = (LLVMGetTypeKind)[ (LLVMTypeOf)[ l ] ]
 | I32 rk = (LLVMGetTypeKind)[ (LLVMTypeOf)[ r ] ]
 |
 | ; pointer arithmetic, scaled by the pointee like C. n + p is p + n.
 | @ASTNode pe = n.as.bin_op.left
 | @ASTNode ie = n.as.bin_op.right
 | IF [ k == BOT_PLUS && rk == LLVMPointerTypeKind && lk == LLVMIntegerTypeKind ]
 |  | @ABYSS tmp = l
 |  | l = r
 |  | r = tmp
 |  | pe = n.as.bin_op.right
 |  | ie = n.as.bin_op.left
 |  | lk = LLVMPointerTypeKind
 |  | rk = LLVMIntegerTypeKind
 |  \_
 | IF [ (k == BOT_PLUS || k == BOT_MINUS) && lk == LLVMPointerTypeKind ]
 |  | TypeInfo ti = (infer)[ c | pe ]
 |  | @ABYSS elem = 0
 |  | IF [ ti.node != 0 && ti.ptrs > 0 ]
 |  |  | TypeInfo inner
 |  |  | inner.node = ti.node
 |  |  | inner.ptrs = ti.ptrs - 1
 |  |  | elem = (llvm_of)[ c | inner ]
 |  |  \_
 |  | ; @ABYSS moves in bytes, as with GNU C's void *
 |  | IF [ elem == 0 || (LLVMGetTypeKind)[ elem ] == LLVMVoidTypeKind ]
 |  |  | elem = (LLVMInt8TypeInContext)[ c.ctx ]
 |  |  \_
 |  | @ABYSS i64 = (LLVMInt64TypeInContext)[ c.ctx ]
 |  |
 |  | ; p - q: how many elements apart they are
 |  | IF [ k == BOT_MINUS && rk == LLVMPointerTypeKind ]
 |  |  | @ABYSS li = (LLVMBuildPtrToInt)[ c.builder | l | i64 | "pl" ]
 |  |  | @ABYSS ri = (LLVMBuildPtrToInt)[ c.builder | r | i64 | "pr" ]
 |  |  | @ABYSS bytes = (LLVMBuildSub)[ c.builder | li | ri | "pdiff" ]
 |  |  | U64 esz = (LLVMABISizeOfType)[ (LLVMGetModuleDataLayout)[ c.mod ] | elem ]
 |  |  | RET [ (LLVMBuildSDiv)[ c.builder | bytes | (LLVMConstInt)[ i64 | esz | 0 ] | "pcount" ] ]
 |  |  \_
 |  |
 |  | @ABYSS off = (coerce_e)[ c | r | i64 | ie ]
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
 |  |  |  | l = (coerce_e)[ c | l | rt | n.as.bin_op.left ]
 |  |  | ELSE
 |  |  |  | r = (coerce_e)[ c | r | lt | n.as.bin_op.right ]
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
 |  | ; an I32 when it fits, as it always was; otherwise all 64 bits
 |  | I64 v = n.as.literal.as.int_lit
 |  | IF [ v < -2147483648 || v > 2147483647 ]
 |  |  | RET [ (LLVMConstInt)[ (LLVMInt64TypeInContext)[ c.ctx ] | v AS U64 | 1 ] ]
 |  |  \_
 |  | RET [ (LLVMConstInt)[ (LLVMInt32TypeInContext)[ c.ctx ] | v AS U64 | 1 ] ]
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
 |  |  | IF [ (LLVMGetTypeKind)[ s.type ] == LLVMArrayTypeKind ]
 |  |  |  | RET [ s.value ]
 |  |  |  \_
 |  |  | RET [ (vload)[ c | s.type | s.value | (tn_volatile)[ s.ntype ] | FALSE | n.as.ident ] ]
 |  |  \_
 |  | I64 ev = 0
 |  | IF [ (enum_const_get)[ c | n.as.ident | @ev ] ]
 |  |  | RET [ (LLVMConstInt)[ (LLVMInt32TypeInContext)[ c.ctx ] | ev AS U64 | 1 ] ]
 |  |  \_
 |  | ; a function's name is its address
 |  | @ABYSS fn = (LLVMGetNamedFunction)[ c.mod | n.as.ident ]
 |  | IF [ fn != 0 ]
 |  |  | RET [ fn ]
 |  |  \_
 |  | (diag_fatal)[ n.loc | "unknown identifier `%s`%s" | n.as.ident | "" ]
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
 |  |  |  | (diag_fatal)[ n.loc | "cannot take the address of this expression%s%s" | "" | "" ]
 |  |  |  \_
 |  |  | RET [ lv.ptr ]
 |  |  \_
 |  |
 |  | IF [ uk == UOT_DEREF ]
 |  |  | LValue lv
 |  |  | IF [ (gen_lvalue)[ c | e | @lv ] ]
 |  |  |  | RET [ (vload)[ c | lv.type | lv.ptr | lv.vol | lv.unal | "deref" ] ]
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
 |  |  | ELIF [ (is_float_ty)[ vt ] ]
 |  |  |  | RET [ (LLVMBuildFCmp)[ c.builder | LLVMRealOEQ | v | (LLVMConstReal)[ vt | 0 ] | "not" ] ]
 |  |  | ELSE
 |  |  |  | zero = (LLVMConstInt)[ vt | 0 | 0 ]
 |  |  |  \_
 |  |  | RET [ (LLVMBuildICmp)[ c.builder | LLVMIntEQ | v | zero | "not" ] ]
 |  |  \_
 |  |
 |  | IF [ (is_float_ty)[ (LLVMTypeOf)[ v ] ] ]
 |  |  | RET [ (LLVMBuildFNeg)[ c.builder | v | "fneg" ] ]
 |  |  \_
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
 |  |  | ; widening: an unsigned value with zeros, a signed one with its sign
 |  |  | I32 signed = 1
 |  |  | IF [ (is_unsigned_expr)[ c | n.as.cast.expr ] ]
 |  |  |  | signed = 0
 |  |  |  \_
 |  |  | RET [ (LLVMBuildIntCast2)[ c.builder | v | to | signed | "cast" ] ]
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
 |  |  | RET [ (to_float)[ c | v | n.as.cast.expr | to ] ]
 |  |  \_
 |  | IF [ (fk == LLVMFloatTypeKind || fk == LLVMDoubleTypeKind) && tk == LLVMIntegerTypeKind ]
 |  |  | ; to an unsigned type, the whole unsigned range is reachable
 |  |  | @ASTNode ct = n.as.cast.type
 |  |  | IF [ ct.as.type.kind == TT_BASE_TYPE && ct.as.type.ptrs == 0 ]
 |  |  |  | I32 bt = ct.as.type.type.as.base_type
 |  |  |  | IF [ bt == BT_U8 || bt == BT_U16 || bt == BT_U32 || bt == BT_U64 || bt == BT_USIZE ]
 |  |  |  |  | RET [ (LLVMBuildFPToUI)[ c.builder | v | to | "cast" ] ]
 |  |  |  |  \_
 |  |  |  \_
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
 | IF [ n.kind == NT_BUILTIN && n.as.builtin.kind == BI_OFFSET ]
 |  | ; the sum of each step's offset in the struct before it, from the
 |  | ; data layout; a union's members all start at 0
 |  | @ABYSS layout = (LLVMGetModuleDataLayout)[ c.mod ]
 |  | @ABYSS sty = (map_type)[ c | n.as.builtin.size ]
 |  | U64 off = 0
 |  | @ASTNode step = n.as.builtin.path
 |  | WHILE [ step != 0 ]
 |  |  | @CGType ut = (type_of_struct)[ c | sty ]
 |  |  | IF [ ut == 0 || ut.record == 0 ]
 |  |  |  | (cg_fatal)[ "OFFSET through something that is not a struct" ]
 |  |  |  \_
 |  |  | I32 idx = 0
 |  |  | @ASTNode ftype = 0
 |  |  | IF [ !(field_index)[ ut.record | step.as.list.item.as.ident | @idx | @ftype AS @@ASTNode ] ]
 |  |  |  | (cg_fatal)[ "OFFSET of an unknown field" ]
 |  |  |  \_
 |  |  | IF [ !(ut.is_union) ]
 |  |  |  | off = off + (LLVMOffsetOfElement)[ layout | sty | idx AS U32 ]
 |  |  |  \_
 |  |  | sty = (map_type)[ c | ftype ]
 |  |  | step = step.as.list.next
 |  |  \_
 |  | RET [ (LLVMConstInt)[ (LLVMInt64TypeInContext)[ c.ctx ] | off | 0 ] ]
 |  \_
 |
 | IF [ n.kind == NT_BUILTIN ]
 |  | ; a plain number from the data layout, so it folds anywhere
 |  | @ABYSS t = (map_type)[ c | n.as.builtin.size ]
 |  | U64 sz = (LLVMABISizeOfType)[ (LLVMGetModuleDataLayout)[ c.mod ] | t ]
 |  | RET [ (LLVMConstInt)[ (LLVMInt64TypeInContext)[ c.ctx ] | sz | 0 ] ]
 |  \_
 |
 | (diag_fatal)[ n.loc | "unhandled expression node %s%s" | (itoa)[ n.kind ] | "" ]
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
 |  |  | @ABYSS v = (coerce_e)[ c | (gen_expr)[ c | d.as.var_decl.init ] | ty | d.as.var_decl.init ]
 |  |  | IF [ v == 0 ]
 |  |  |  | (diag_fatal)[ d.loc | "could not evaluate the initialiser of `%s`%s" | nm | "" ]
 |  |  |  \_
 |  |  | (vstore)[ c | v | slot | (tn_volatile)[ d.as.var_decl.type ] | FALSE ]
 |  |  \_
 |  | RET
 |  \_
 |
 | IF [ k == ST_RET ]
 |  | @ASTNode r = st.as.stmt.stmt
 |  | B1 has_val = r.as.ret.expr != 0
 |  | IF [ has_val && (LLVMGetTypeKind)[ c.ret_type ] != LLVMVoidTypeKind ]
 |  |  | @ABYSS v = (coerce_e)[ c | (gen_expr)[ c | r.as.ret.expr ] | c.ret_type | r.as.ret.expr ]
 |  |  | (LLVMBuildRet)[ c.builder | v ]
 |  | ELSE
 |  |  | (LLVMBuildRetVoid)[ c.builder ]
 |  |  \_
 |  | RET
 |  \_
 |
 | IF [ k == ST_BREAK ]
 |  | IF [ c.loop_break == 0 ]
 |  |  | (diag_fatal)[ st.loc | "BREAK outside of a loop%s%s" | "" | "" ]
 |  |  \_
 |  | (LLVMBuildBr)[ c.builder | c.loop_break ]
 |  | RET
 |  \_
 |
 | IF [ k == ST_CONTINUE ]
 |  | IF [ c.loop_continue == 0 ]
 |  |  | (diag_fatal)[ st.loc | "CONTINUE outside of a loop%s%s" | "" | "" ]
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
 | ut.packed = td.as.type_def.tdef.as.record.packed
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
 |  | ; + ALIGN N: an empty array of an N-byte vector at the end raises the
 |  | ; struct's alignment to N, and its size to a multiple of N, without
 |  | ; moving a field. Every target but one checked aligns such a vector to
 |  | ; its size; the result is verified below.
 |  | U32 want = rec.as.record.align
 |  | IF [ want > 1 && rec.as.record.packed ]
 |  |  | (diag_fatal)[ td.loc | "`%s`: PACKED and ALIGN together are not supported yet%s" | name | "" ]
 |  |  \_
 |  | IF [ want > 1 && n < 64 ]
 |  |  | @ABYSS lane = (LLVMVectorType)[ (LLVMInt8TypeInContext)[ c.ctx ] | want ]
 |  |  | ?(ftypes + n) = (LLVMArrayType)[ lane | 0 ]
 |  |  | n = n + 1
 |  |  \_
 |  | I32 packed = 0
 |  | IF [ rec.as.record.packed ]
 |  |  | packed = 1
 |  |  \_
 |  | (LLVMStructSetBody)[ ut.type | ftypes | n | packed ]
 |  | (free)[ ftypes AS @ABYSS ]
 |  |
 |  | IF [ want > 1 ]
 |  |  | U32 got = (LLVMABIAlignmentOfType)[ (LLVMGetModuleDataLayout)[ c.mod ] | ut.type ]
 |  |  | IF [ got < want ]
 |  |  |  | C1 wbuf{16}
 |  |  |  | C1 gbuf{16}
 |  |  |  | (snprintf)[ wbuf | 16 | "%u" | want ]
 |  |  |  | (snprintf)[ gbuf | 16 | "%u" | got ]
 |  |  |  | (diag_fatal)[ td.loc | "ALIGN %s cannot be given on this target yet: its data layout stops at %s here" | wbuf | gbuf ]
 |  |  |  \_
 |  |  \_
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

; Built only from literals, enum constants, function names, SIZE and
; arithmetic on those -- what a global may be initialised with.
B1 is_const_expr: [ @CodegenContext c | @ASTNode e ]
 | @ASTNode n = (strip)[ e ]
 | IF [ n == 0 ]
 |  | RET [ FALSE ]
 |  \_
 | I32 k = n.kind
 | IF [ k == NT_LITERAL || k == NT_BUILTIN ]
 |  | RET [ TRUE ]
 |  \_
 | IF [ k == NT_IDENT ]
 |  | I64 ev = 0
 |  | RET [ (enum_const_get)[ c | n.as.ident | @ev ] || (LLVMGetNamedFunction)[ c.mod | n.as.ident ] != 0 ]
 |  \_
 | IF [ k == NT_CAST ]
 |  | RET [ (is_const_expr)[ c | n.as.cast.expr ] ]
 |  \_
 | IF [ k == NT_UNY_OP ]
 |  | I32 uk = n.as.uny_op.kind
 |  | IF [ uk == UOT_NEG || uk == UOT_BNOT || uk == UOT_NOT ]
 |  |  | RET [ (is_const_expr)[ c | n.as.uny_op.operand ] ]
 |  |  \_
 |  | RET [ FALSE ]
 |  \_
 | IF [ k == NT_BIN_OP ]
 |  | I32 bk = n.as.bin_op.kind
 |  | ; && and || branch; the others build no control flow
 |  | IF [ bk == BOT_ASSIGN || bk == BOT_MEMBER || bk == BOT_INDEX || bk == BOT_AND || bk == BOT_OR ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | RET [ (is_const_expr)[ c | n.as.bin_op.left ] && (is_const_expr)[ c | n.as.bin_op.right ] ]
 |  \_
 | RET [ FALSE ]
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
 |  |  | ; NULL, or any integer, into a pointer global
 |  |  | IF [ (LLVMGetTypeKind)[ ty ] == LLVMPointerTypeKind && (LLVMGetTypeKind)[ (LLVMTypeOf)[ init ] ] == LLVMIntegerTypeKind ]
 |  |  |  | init = (coerce)[ c | init | ty ]
 |  |  |  \_
 |  |  | IF [ (is_float_ty)[ ty ] && lit.as.literal.kind == LT_FLOAT ]
 |  |  |  | init = (LLVMConstReal)[ ty | lit.as.literal.as.float_lit ]
 |  |  | ELIF [ (is_float_ty)[ ty ] && lit.as.literal.kind == LT_INTEGER ]
 |  |  |  | init = (LLVMConstReal)[ ty | lit.as.literal.as.int_lit AS F64 ]
 |  |  |  \_
 |  |  | ; a constant initialiser may still need narrowing
 |  |  | IF [ (LLVMGetTypeKind)[ (LLVMTypeOf)[ init ] ] == LLVMIntegerTypeKind && (LLVMGetTypeKind)[ ty ] == LLVMIntegerTypeKind ]
 |  |  |  | IF [ (LLVMTypeOf)[ init ] != ty ]
 |  |  |  |  | init = (LLVMConstInt)[ ty | lit.as.literal.as.int_lit AS U64 | 1 ]
 |  |  |  |  \_
 |  |  |  \_
 |  | ELIF [ (is_const_expr)[ c | d.as.var_decl.init ] ]
 |  |  | ; no function is open, so the builder folds all of it to a constant
 |  |  | init = (coerce_e)[ c | (gen_expr)[ c | d.as.var_decl.init ] | ty | d.as.var_decl.init ]
 |  |  | IF [ (LLVMIsConstant)[ init ] == 0 ]
 |  |  |  | (diag_fatal)[ d.loc | "global `%s` needs a constant initialiser%s" | nm | "" ]
 |  |  |  \_
 |  | ELSE
 |  |  | (diag_fatal)[ d.loc | "global `%s` needs a constant initialiser%s" | nm | "" ]
 |  |  \_
 |  \_
 |
 | (LLVMSetInitializer)[ g | init ]
 |
 | ; CONST: read-only memory -- .rodata, or flash on a microcontroller
 | IF [ ((quals_at)[ d.as.var_decl.type.as.type.quals | 0 ] & QUAL_CONST) != 0 ]
 |  | (LLVMSetGlobalConstant)[ g | 1 ]
 |  \_
 |
 | ; what C compilers call -fdata-sections: the linker can then place or
 | ; drop each global by name, as the STM32 vector table needs
 | IF [ cg_data_sections ]
 |  | U64 sn = (strlen)[ nm ] + 10
 |  | @C1 sec = (malloc)[ sn ] AS @C1
 |  | IF [ ((quals_at)[ d.as.var_decl.type.as.type.quals | 0 ] & QUAL_CONST) != 0 ]
 |  |  | (snprintf)[ sec | sn | ".rodata.%s" | nm ]
 |  | ELIF [ (LLVMIsNull)[ init ] != 0 ]
 |  |  | (snprintf)[ sec | sn | ".bss.%s" | nm ]
 |  | ELSE
 |  |  | (snprintf)[ sec | sn | ".data.%s" | nm ]
 |  |  \_
 |  | (LLVMSetSection)[ g | sec ]
 |  | (free)[ sec AS @ABYSS ]
 |  \_
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
 | c.tm = 0
 |
 | (c.types.init)[ 16 ]
 | (c.consts.init)[ 16 ]
 | (c.strs.init)[ 16 ]
 |
 | ; Without a data layout every ABI size query is meaningless, which is
 | ; what union layout and SIZE [ T ] are built on. Microcontrollers too:
 | ; ARM for STM32, RISC-V for the newer ESP32s, AVR for Arduino.
 | (LLVMInitializeX86TargetInfo)[]
 | (LLVMInitializeX86Target)[]
 | (LLVMInitializeX86TargetMC)[]
 | (LLVMInitializeX86AsmPrinter)[]
 | (LLVMInitializeARMTargetInfo)[]
 | (LLVMInitializeARMTarget)[]
 | (LLVMInitializeARMTargetMC)[]
 | (LLVMInitializeRISCVTargetInfo)[]
 | (LLVMInitializeRISCVTarget)[]
 | (LLVMInitializeRISCVTargetMC)[]
 | (LLVMInitializeAVRTargetInfo)[]
 | (LLVMInitializeAVRTarget)[]
 | (LLVMInitializeAVRTargetMC)[]
 | (LLVMInitializeARMAsmPrinter)[]
 | (LLVMInitializeRISCVAsmPrinter)[]
 | (LLVMInitializeAVRAsmPrinter)[]
 |
 | @C1 triple = cg_triple
 | IF [ triple == NULL ]
 |  | triple = (LLVMGetDefaultTargetTriple)[]
 |  \_
 | (LLVMSetTarget)[ c.mod | triple ]
 |
 | @ABYSS target = 0
 | @C1 terr = 0
 | IF [ (LLVMGetTargetFromTriple)[ triple | @target AS @@ABYSS | @terr AS @@C1 ] != 0 ]
 |  | Location none
 |  | none.file = NULL
 |  | none.line = 0
 |  | none.col = 0
 |  | (diag_fatal)[ none | "plc cannot generate code for `%s`: %s" | triple | terr ]
 | ELSE
 |  | @C1 cpu = cg_cpu
 |  | IF [ cpu == NULL ]
 |  |  | cpu = "generic"
 |  |  \_
 |  | ; a hosted program is linked as a position-independent executable;
 |  | ; bare metal (-none-, and AVR) puts code at fixed addresses
 |  | I32 reloc = LLVMRelocPIC
 |  | IF [ (strstr)[ triple | "-none" ] != NULL || (strncmp)[ triple | "avr" | 3 ] == 0 ]
 |  |  | reloc = LLVMRelocDefault
 |  |  \_
 |  | ; the -O levels and LLVMCodeGenOptLevel number alike: None .. Aggressive
 |  | c.tm = (LLVMCreateTargetMachine)[ target | triple | cpu | "" | cg_opt | reloc | LLVMCodeModelDefault ]
 |  | @ABYSS tdl = (LLVMCreateTargetDataLayout)[ c.tm ]
 |  | @C1 dl = (LLVMCopyStringRepOfTargetData)[ tdl ]
 |  | (LLVMSetDataLayout)[ c.mod | dl ]
 |  | (LLVMDisposeMessage)[ dl ]
 |  | (LLVMDisposeTargetData)[ tdl ]
 |  \_
 | IF [ cg_triple == NULL ]
 |  | (LLVMDisposeMessage)[ triple ]
 |  \_
 | RET
 \_

; The value of a STATIC_ASSERT's condition, worked out now. && || and !
; are taken apart here, since as code they branch; the rest folds.
B1 const_value: [ @CodegenContext c | @ASTNode e | @U64 out ]
 | @ASTNode n = (strip)[ e ]
 | IF [ n == 0 ]
 |  | RET [ FALSE ]
 |  \_
 | U64 a = 0
 | U64 b = 0
 | IF [ n.kind == NT_BIN_OP && (n.as.bin_op.kind == BOT_AND || n.as.bin_op.kind == BOT_OR) ]
 |  | IF [ !(const_value)[ c | n.as.bin_op.left | @a ] || !(const_value)[ c | n.as.bin_op.right | @b ] ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | IF [ n.as.bin_op.kind == BOT_AND ]
 |  |  | ?(out) = (a != 0 && b != 0) AS U64
 |  |  | RET [ TRUE ]
 |  |  \_
 |  | ?(out) = (a != 0 || b != 0) AS U64
 |  | RET [ TRUE ]
 |  \_
 | IF [ n.kind == NT_UNY_OP && n.as.uny_op.kind == UOT_NOT ]
 |  | IF [ !(const_value)[ c | n.as.uny_op.operand | @a ] ]
 |  |  | RET [ FALSE ]
 |  |  \_
 |  | ?(out) = (a == 0) AS U64
 |  | RET [ TRUE ]
 |  \_
 | IF [ !(is_const_expr)[ c | n ] ]
 |  | RET [ FALSE ]
 |  \_
 | @ABYSS v = (gen_expr)[ c | n ]
 | IF [ v == 0 || (LLVMIsAConstantInt)[ v ] == NULL ]
 |  | RET [ FALSE ]
 |  \_
 | ?(out) = (LLVMConstIntGetZExtValue)[ v ]
 | RET [ TRUE ]
 \_

ABYSS gen_static_assert: [ @CodegenContext c | @ASTNode sa ]
 | U64 v = 0
 | IF [ !(const_value)[ c | sa.as.assert.cond | @v ] ]
 |  | (diag_fatal)[ sa.as.assert.cond.loc | "STATIC_ASSERT needs what the compiler can work out: literals, enum constants, SIZE, OFFSET, and operators on them%s%s" | "" | "" ]
 |  \_
 | IF [ v == 0 ]
 |  | IF [ sa.as.assert.msg != 0 ]
 |  |  | (diag_fatal)[ sa.loc | "STATIC_ASSERT does not hold: %s%s" | sa.as.assert.msg.as.literal.as.str_lit | "" ]
 |  |  \_
 |  | (diag_fatal)[ sa.loc | "this STATIC_ASSERT does not hold%s%s" | "" | "" ]
 |  \_
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
 | ; before any body: the builder is in no function, so these fold
 | ts = root.as.tu.tu_stmt
 | WHILE [ ts != 0 ]
 |  | IF [ ts.as.tu_stmt.kind == TUST_STATIC_ASSERT ]
 |  |  | (gen_static_assert)[ c | ts.as.tu_stmt.tu_stmt ]
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

; Writes the module and tears everything down. FALSE if the module is
; invalid -- a compiler bug, since the checker passed it -- or could not be
; written. Invalid IR is still written, to be looked at.
B1 codegen_deinit: [ @CodegenContext c | @C1 filename ]
 | B1 ok = TRUE
 | @C1 err = 0
 | IF [ (LLVMVerifyModule)[ c.mod | LLVMReturnStatusAction | @err AS @@C1 ] != 0 ]
 |  | (dprintf)[ 2 | "internal compiler error: plc produced invalid LLVM IR; please report it\n" ]
 |  | IF [ err != 0 ]
 |  |  | (dprintf)[ 2 | "%s\n" | err ]
 |  |  \_
 |  | ok = FALSE
 |  \_
 |
 | ; LLVM's standard pipeline, the one clang -O2 runs
 | IF [ ok && cg_opt > 0 ]
 |  | C1 pipeline{16}
 |  | (snprintf)[ pipeline | 16 | "default<O%d>" | cg_opt ]
 |  | @ABYSS opts = (LLVMCreatePassBuilderOptions)[]
 |  | @ABYSS perr = (LLVMRunPasses)[ c.mod | pipeline | c.tm | opts ]
 |  | (LLVMDisposePassBuilderOptions)[ opts ]
 |  | IF [ perr != NULL ]
 |  |  | @C1 pm = (LLVMGetErrorMessage)[ perr ]
 |  |  | (dprintf)[ 2 | "internal compiler error: the optimiser failed: %s\n" | pm ]
 |  |  | (LLVMDisposeErrorMessage)[ pm ]
 |  |  | ok = FALSE
 |  |  \_
 |  \_
 |
 | err = 0
 | ; invalid IR is still written: it is what a compiler bug is debugged from
 | IF [ cg_emit == CG_IR ]
 |  | IF [ (LLVMPrintModuleToFile)[ c.mod | filename | @err AS @@C1 ] != 0 ]
 |  |  | (dprintf)[ 2 | "error: cannot write `%s`\n" | filename ]
 |  |  | ok = FALSE
 |  |  \_
 | ELIF [ ok ]
 |  | I32 kind = LLVMObjectFile
 |  | IF [ cg_emit == CG_ASM ]
 |  |  | kind = LLVMAssemblyFile
 |  |  \_
 |  | IF [ (LLVMTargetMachineEmitToFile)[ c.tm | c.mod | filename | kind | @err AS @@C1 ] != 0 ]
 |  |  | (dprintf)[ 2 | "error: cannot write `%s`: %s\n" | filename | err ]
 |  |  | ok = FALSE
 |  |  \_
 |  \_
 |
 | WHILE [ c.scope != 0 ]
 |  | (scope_pop)[ c ]
 |  \_
 |
 | (c.types.deinit)[]
 | (c.consts.deinit)[]
 | (c.strs.deinit)[]
 |
 | (LLVMDisposeBuilder)[ c.builder ]
 | IF [ c.tm != NULL ]
 |  | (LLVMDisposeTargetMachine)[ c.tm ]
 |  \_
 | (LLVMDisposeModule)[ c.mod ]
 | (LLVMContextDispose)[ c.ctx ]
 | RET [ ok ]
 \_
