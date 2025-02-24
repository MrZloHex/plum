#include "ast.h"
#include "ir.h"
#include "parser.h"

Node *root = NULL;


int
main()
{
    yyparse();
    //node_dump_programme(root, 0);

    generateIR(root);

    return 0;
}
