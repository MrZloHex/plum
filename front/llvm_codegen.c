#include "llvm_codegen.h"
#include <llvm-c/Core.h>
#include <llvm-c/Analysis.h>
#include <llvm-c/BitWriter.h>
#include <llvm-c/Support.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

LLVMContextRef context;
LLVMModuleRef module;
LLVMBuilderRef builder;

// Convert our AST type node to an LLVM type.
LLVMTypeRef getLLVMType(ASTNode* typeNode) {
    if (!typeNode || !typeNode->value) return LLVMVoidType();
    if (strcmp(typeNode->value, "I32") == 0) {
        return LLVMInt32Type();
    } else if (strcmp(typeNode->value, "U32") == 0) {
        return LLVMInt32Type();  // For simplicity, treat U32 as i32
    } else if (strcmp(typeNode->value, "F32") == 0) {
        return LLVMFloatType();
    }
    // Extend for other types as needed.
    return LLVMVoidType();
}

// Generate LLVM IR for an expression.
// This function handles literal integer values and the plus operator.
LLVMValueRef generateExpression(ASTNode* exprNode) {
    if (!exprNode) {
        // Return 0 if no expression is present.
        return LLVMConstInt(LLVMInt32Type(), 0, 0);
    }
    // If it's a leaf node (no children), assume it's a literal.
    if (exprNode->left == NULL && exprNode->right == NULL) {
        return LLVMConstInt(LLVMInt32Type(), atoi(exprNode->value), 0);
    }
    // If it represents an addition.
    if (exprNode->type == AST_EXPRESSION && strcmp(exprNode->value, "+") == 0) {
        LLVMValueRef lhs = generateExpression(exprNode->left);
        LLVMValueRef rhs = generateExpression(exprNode->right);
        if (!lhs || !rhs) {
            fprintf(stderr, "Error: One of the operands in addition is NULL.\n");
            return LLVMConstInt(LLVMInt32Type(), 0, 0);
        }
        return LLVMBuildAdd(builder, lhs, rhs, "addtmp");
    }
    // Fallback: treat it as a literal.
    return LLVMConstInt(LLVMInt32Type(), atoi(exprNode->value), 0);
}

// Generate LLVM IR for a return statement.
void generateReturn(ASTNode* returnNode, LLVMValueRef function) {
    if (!returnNode) {
        LLVMBuildRetVoid(builder);
        return;
    }
    // Assume returnNode->left is the expression to return.
    ASTNode* returnExprNode = returnNode->left;
    LLVMValueRef retVal = generateExpression(returnExprNode);
    if (!retVal) {
        retVal = LLVMConstInt(LLVMInt32Type(), 0, 0);
    }
    LLVMBuildRet(builder, retVal);
}

// Generate LLVM IR for a variable declaration.
void generateVarDecl(ASTNode* varDeclNode, LLVMValueRef function) {
    if (!varDeclNode) return;
    ASTNode* typeNode = varDeclNode->left;
    ASTNode* varNameNode = varDeclNode->right;  // Assume this holds the variable name.
    if (!typeNode || !varNameNode || !varNameNode->value) return;

    LLVMTypeRef varType = getLLVMType(typeNode);
    LLVMValueRef allocaInst = LLVMBuildAlloca(builder, varType, varNameNode->value);

    // If there's an initializer (assume it's stored in varNameNode->right).
    if (varNameNode->right) {
        LLVMValueRef initVal = generateExpression(varNameNode->right);
        LLVMBuildStore(builder, initVal, allocaInst);
    }
}

// Generate LLVM IR for a function declaration.
// Our AST for a function is assumed to have two parts:
//   - Left child: a "header" List node, where header->left is the return type
//     and header->right is a node with the function name.
//   - Right sibling chain: the function body statements.
LLVMValueRef generateFunction(ASTNode* funcDeclNode) {
    if (!funcDeclNode) return NULL;
    // Extract the header.
    ASTNode* header = funcDeclNode->left;
    if (!header) return NULL;
    ASTNode* returnTypeNode = header->left;
    ASTNode* nameNode = header->right;
    if (!nameNode || !nameNode->value) return NULL;
    const char* funcName = nameNode->value;

    LLVMTypeRef retType = getLLVMType(returnTypeNode);
    // For simplicity, assume no parameters.
    LLVMTypeRef funcType = LLVMFunctionType(retType, NULL, 0, 0);
    LLVMValueRef function = LLVMAddFunction(module, funcName, funcType);

    // Create the entry basic block.
    LLVMBasicBlockRef entry = LLVMAppendBasicBlock(function, "entry");
    LLVMPositionBuilderAtEnd(builder, entry);

    // Process the function body: iterate through the sibling chain.
    ASTNode* stmt = funcDeclNode->right;
    while (stmt) {
        if (stmt->type == AST_VAR_DECL) {
            generateVarDecl(stmt, function);
        } else if (stmt->type == AST_RETURN) {
            generateReturn(stmt, function);
        }
        // Extend: handle expressions, function calls, etc.
        stmt = stmt->right;
    }
    return function;
}

// Traverse the AST and generate LLVM IR.
void generateLLVMIR(ASTNode* root) {
    // Initialize LLVM objects.
    context = LLVMContextCreate();
    module = LLVMModuleCreateWithNameInContext("my_module", context);
    builder = LLVMCreateBuilderInContext(context);

    // Traverse top-level AST nodes.
    ASTNode* cur = root;
    while (cur) {
        // If the node is a List labeled "functions", iterate its children.
        if (cur->type == AST_LIST && cur->value && strcmp(cur->value, "functions") == 0) {
            ASTNode* funcNode = cur->left;
            while (funcNode) {
                if (funcNode->type == AST_FUNCTION_DECL) {
                    generateFunction(funcNode);
                }
                funcNode = funcNode->right;
            }
        } else if (cur->type == AST_FUNCTION_DECL) {
            generateFunction(cur);
        }
        cur = cur->right;
    }

    // Dump the generated LLVM IR to standard output.
    LLVMDumpModule(module);

    char* error = NULL;
    if (LLVMPrintModuleToFile(module, "output.ll", &error) != 0) {
        fprintf(stderr, "Error writing module: %s\n", error);
        LLVMDisposeMessage(error);
    }
    // Cleanup: In a full implementation, free LLVM objects when done.
}

