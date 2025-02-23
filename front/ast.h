#ifndef AST_H
#define AST_H

typedef enum {
    AST_FUNCTION_DECL,
    AST_PARAMETER,
    AST_VAR_DECL,
    AST_EXPRESSION,
    AST_TYPE,
    AST_LIST,      // For lists (e.g. parameters, block lines, argument lists)
    AST_EMPTY,     // For an empty statement (e.g. comment-only lines)
    AST_RETURN,    // For return statements
    AST_FUNC_CALL  // For function call expressions
} ASTNodeType;

typedef struct ASTNode {
    ASTNodeType type;
    char *value;               // e.g., identifier name, literal value, operator symbol, or type string
    struct ASTNode *left;      // first child
    struct ASTNode *right;     // next sibling
} ASTNode;

/* Creates a new AST node */
ASTNode* create_node(ASTNodeType type, const char* value, ASTNode* left, ASTNode* right);

/* Frees an AST */
void free_ast(ASTNode* node);

/* Prints the AST in a tree-like form */
void print_ast(ASTNode* node, int indent);

#endif

