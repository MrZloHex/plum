#include "ast.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

ASTNode* create_node(ASTNodeType type, const char* value, ASTNode* left, ASTNode* right) {
    ASTNode* node = malloc(sizeof(ASTNode));
    if (!node) {
        fprintf(stderr, "Out of memory!\n");
        exit(1);
    }
    node->type = type;
    node->value = value ? strdup(value) : NULL;
    node->left = left;
    node->right = right;
    return node;
}

void free_ast(ASTNode* node) {
    if (!node)
        return;
    free_ast(node->left);
    free_ast(node->right);
    if (node->value)
        free(node->value);
    free(node);
}

static const char* ast_type_to_string(ASTNodeType type) {
    switch(type) {
        case AST_FUNCTION_DECL: return "FunctionDecl";
        case AST_PARAMETER:     return "Parameter";
        case AST_VAR_DECL:      return "VarDecl";
        case AST_EXPRESSION:    return "Expression";
        case AST_TYPE:          return "Type";
        case AST_LIST:          return "List";
        case AST_EMPTY:         return "Empty";
        case AST_RETURN:        return "Return";
        case AST_FUNC_CALL:     return "FuncCall";
        default:                return "Unknown";
    }
}

/*
 * print_ast prints the AST in a tree-like structure.
 * 'indent' indicates the current indentation level.
 * The convention is: node->left is the first child, node->right is the next sibling.
 */
void print_ast(ASTNode* node, int indent) {
    if (!node)
        return;
    for (int i = 0; i < indent; i++)
        printf("    ");  // 4 spaces per indent level
    printf("|-- %s", ast_type_to_string(node->type));
    if (node->value)
        printf(" (%s)", node->value);
    printf("\n");
    // First, print children (with increased indent)
    print_ast(node->left, indent + 1);
    // Then, print siblings (same indent level)
    print_ast(node->right, indent);
}

