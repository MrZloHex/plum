%{
#include "parser.tab.h"
#include <string.h>
#include <stdlib.h>
%}

%option noyywrap

%%
"ABYSS"                     { yylval.str = strdup(yytext); return TYPE; }
F(32|64)                  { yylval.str = strdup(yytext); return TYPE; }
"B1"                        { yylval.str = strdup(yytext); return TYPE; }
C(1|2|4)                    { yylval.str = strdup(yytext); return TYPE; }
[IU](8|16|32|64|SIZE)        { yylval.str = strdup(yytext); return TYPE; }

"@"                         { return PTR; }
"="                         { return EQUAL; }
"\\_"                       { return BLOCK_END; }
[0-9]+                      { yylval.str = strdup(yytext); return NUMBER; }
[a-zA-Z_][a-zA-Z0-9_]*       { yylval.str = strdup(yytext); return IDENT; }

":"                         { return COLON; }
"["                         { return LBRACKET; }
"]"                         { return RBRACKET; }
"|"                         { return VBAR; }
";".*                       { /* skip comments */ }
[ \t\n]+                    { /* skip whitespace */ }
.                           { /* ignore any other character */ }
%%

