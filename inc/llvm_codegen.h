#ifndef LLVM_CODEGEN_H
#define LLVM_CODEGEN_H

#include "ast.h"
#include <llvm-c/Core.h>

LLVMValueRef generateExpression(ASTNode* exprNode);
void generateReturn(ASTNode* returnNode, LLVMValueRef function);
LLVMValueRef generateFunction(ASTNode* funcDeclNode);
void generateLLVMIR(ASTNode* root);

#endif

