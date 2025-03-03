#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <unistd.h>

typedef struct
{
    char *output_file;
    char *emit_type;
    int file_start_index;
} Options;

void
usage(FILE *file, const char *progname)
{
    fprintf(file, "Usage: %s [--emit=<AST|IR>] [-o output] file1 [file2 ...]\n", progname);
    fprintf(file, "  --emit=<AST|IR>   Specify the output type to emit (AST or IR)\n");
    fprintf(file, "  -o output        Specify the output filename\n");
    fprintf(file, "  file1 ...        One or more source files to compile\n");
}

Options
parse_cli_options(int argc, char *argv[])
{
    Options opts = {NULL, NULL, 0};
    int opt;
    int option_index = 0;

    // Define long options including "emit" and "help".
    struct option long_options[] =
    {
        {"emit", required_argument, 0, 0},
        {"help", no_argument, 0, 'h'},
        {0, 0, 0, 0}
    };

    while ((opt = getopt_long(argc, argv, "ho:", long_options, &option_index)) != -1)
    {
        if (opt == 0)
        {
            if (strcmp(long_options[option_index].name, "emit") == 0)
            {
                if (strcmp(optarg, "AST") == 0 || strcmp(optarg, "IR") == 0)
                {
                    opts.emit_type = optarg;
                }
                else
                {
                    fprintf(stderr, "Error: Invalid value for --emit: %s. Allowed values are AST or IR.\n", optarg);
                    usage(stderr, argv[0]);
                    exit(EXIT_FAILURE);
                }
            }
        }
        else
        {
            switch (opt)
            {
                case 'o':
                    opts.output_file = optarg;
                    break;
                case 'h':
                    usage(stdout, argv[0]);
                    exit(EXIT_SUCCESS);
                default:
                    usage(stderr, argv[0]);
                    exit(EXIT_FAILURE);
            }
        }
    }

    opts.file_start_index = optind;
    return opts;
}


#include "ast.h"
#include "parser.h"
#include "ir.h"
#include "meta_ir.h"
#include "dynstr.h"

#include <assert.h>

extern FILE *yyin;
Node *root = NULL;

#include "unistd.h"
#include "linux/limits.h"

int
main(int argc, char *argv[])
{
    char cwd[PATH_MAX];
    if (getcwd(cwd, sizeof(cwd)) != NULL)
    {
         printf("Current working dir: %s\n", cwd);
    }

    Options opts = parse_cli_options(argc, argv);
    if (opts.file_start_index >= argc)
    {
        fprintf(stderr, "Error: No input files provided.\n");
        usage(stderr, argv[0]);
        exit(EXIT_FAILURE);
    }

    FILE *fout = NULL;
    if (opts.output_file)
    {
        fout = fopen(opts.output_file, "w");
        if (!fout)
        {
            fprintf(stderr, "Failed to open output file: %s\n", opts.output_file);
            exit(EXIT_FAILURE);
        }
    }
    else
    {
        fout = stdout;
    }

    if (!fout)
    {
        fprintf(stderr, "failed to open output file: %s\n", opts.output_file);
        exit(EXIT_FAILURE);
    }

    char *source_file = argv[opts.file_start_index];

    FILE *src_f = fopen(source_file, "r");
    if (!src_f)
    {
        fprintf(stderr, "Failed to open source file: %s\n", source_file);
        exit(EXIT_FAILURE);
    }
    DynString src;
    dynstr_init(&src, src_f);

    // TODO: preprocess

    yyin = fmemopen(src.data, src.size, "r");
    if (!yyin) {
        fprintf(stderr, "Failed to open virtual preprocessed file\n");
        free(yyin);
        exit(EXIT_FAILURE);
    }

    if (yyparse() != 0)
    {
        fprintf(stderr, "Failed to parse source code: %s\n", source_file);
        exit(EXIT_FAILURE);
    }

    { node_dump_programme(root, 0); }
    AST ast;
    ast_init(&ast, root);

    Meta meta;
    meta_init(&meta);
    meta_collect(&meta, &ast);
    printf("\n\n===========META==============\n");
    meta_dump(&meta);
    printf("===========META==============\n");

    IR ir;
    ast_reinit(&ast);
    ir_init(&ir, &meta, &ast);
    ir_generate(&ir);

    if (opts.emit_type)
    {
        if (strcmp(opts.emit_type, "AST") == 0)
        { node_dump_programme(root, 0); }
        else if (strcmp(opts.emit_type, "IR") == 0)
        { fprintf(fout, "%s\n", ir.ir.data); }
    }

    dynstr_deinit(&src);
    free(yyin);

    return 0;
}
