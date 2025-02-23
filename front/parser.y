%code requires {
  #include "ast.h"
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"

void yyerror(const char *s);
int yylex(void);

/* Global AST root (could be a list of functions) */
ASTNode* root = NULL;
%}

%union {
    char* str;
    ASTNode* ast;
}

/* Token declarations with their semantic types */
%token <str> TYPE IDENT NUMBER
%token COLON LBRACKET RBRACKET VBAR PTR BLOCK_END EQUAL

/* Declare nonterminals that will carry AST nodes */
%type <ast> program function_decl param_list_opt param_list parameter block_opt block block_line_list block_line opt_stmt stmt var_decl expression type

%%
program:
      /* empty */
    | program function_decl { root = $2; }
    ;

function_decl:
      type IDENT COLON LBRACKET param_list_opt RBRACKET block_opt
        {
            /* $1: return type (ASTNode)
               $2: function name (string)
               $5: parameter list (ASTNode, maybe NULL)
               $7: block (ASTNode, maybe NULL)
            */
            ASTNode *header = create_node(AST_LIST, NULL, $1,
                                create_node(AST_LIST, $2, $5, NULL));
            $$ = create_node(AST_FUNCTION_DECL, NULL, header, $7);
        }
    ;

param_list_opt:
      /* empty */ { $$ = NULL; }
    | param_list     { $$ = $1; }
    ;

param_list:
      parameter { $$ = $1; }
    | param_list VBAR parameter
        {
            ASTNode* p = $1;
            while(p->right)
                p = p->right;
            p->right = $3;
            $$ = $1;
        }
    ;

parameter:
      type IDENT
        {
            $$ = create_node(AST_PARAMETER, $2, $1, NULL);
        }
    ;

block_opt:
      /* empty */ { $$ = NULL; }
    | block       { $$ = $1; }
    ;

block:
      block_line_list BLOCK_END { $$ = $1; }
    ;

block_line_list:
      block_line { $$ = $1; }
    | block_line_list block_line
        {
            ASTNode* p = $1;
            while(p->right)
                p = p->right;
            p->right = $2;
            $$ = $1;
        }
    ;

/* Modify block_line to always produce a non-null node */
block_line:
      VBAR opt_stmt {
          if ($2 == NULL) {
              $$ = create_node(AST_EMPTY, "", NULL, NULL);
          } else {
              $$ = $2;
          }
      }
    ;

opt_stmt:
      /* empty */ { $$ = NULL; }
    | stmt       { $$ = $1; }
    ;

stmt:
      var_decl { $$ = $1; }
    ;

var_decl:
      type IDENT
        {
            $$ = create_node(AST_VAR_DECL, $2, $1, NULL);
        }
    | type IDENT EQUAL expression
        {
            $$ = create_node(AST_VAR_DECL, $2, $1, $4);
        }
    ;

expression:
      NUMBER { $$ = create_node(AST_EXPRESSION, $1, NULL, NULL); }
    | IDENT  { $$ = create_node(AST_EXPRESSION, $1, NULL, NULL); }
    ;

type:
      TYPE { $$ = create_node(AST_TYPE, $1, NULL, NULL); }
    | PTR type
        {
            char* newType = malloc(strlen($2->value) + 2);
            sprintf(newType, "@%s", $2->value);
            $$ = create_node(AST_TYPE, newType, NULL, NULL);
            free(newType);
        }
    ;
%%

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
}

int main(void) {
    if (yyparse() == 0) {
        printf("Parsing completed successfully!\n");
        if (root) {
            printf("\n--- AST ---\n");
            print_ast(root, 0);
        }
    }
    // Optionally free your AST: free_ast(root);
    return 0;
}

