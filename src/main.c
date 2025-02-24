#include "ast.h"
#include "parser.h"

Node *root = NULL;

int
main()
{
    yyparse();
    node_dump_programme(root, 0);
    //generateLLVMIR(root);
    return 0;
}
