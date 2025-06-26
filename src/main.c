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



#include <assert.h>
#include <unistd.h>
#include <linux/limits.h>

#include "trace.h"

#include "parser.h"

#define DYNSTR_IMPL
#include "dynstr.h"


int
main(int argc, char *argv[])
{
    tracer_init(TRC_DEBUG, TP_ALL);

    char cwd[PATH_MAX];
    if (getcwd(cwd, sizeof(cwd)) != NULL)
    { printf("Current working dir: %s\n", cwd); }

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
    { fout = stdout; }

    if (!fout)
    {
        fprintf(stderr, "failed to open output file: %s\n", opts.output_file);
        exit(EXIT_FAILURE);
    }

    char *source_file = realpath(argv[opts.file_start_index], NULL);

    FILE *src_f = fopen(source_file, "r");
    if (!src_f)
    {
        fprintf(stderr, "Failed to open source file: %s\n", source_file);
        free(source_file);
        exit(EXIT_FAILURE);
    }

    DynString src;
    dynstr_init(&src, src_f);
    fclose(src_f);
    free(source_file);

    AST ast;
    ast_init(&ast);
    parse_unit(&ast, &src);
    //dummy_dump(&ast);
    DynString ast_str = ast_dump(&ast);

    ast_deinit(&ast);
    dynstr_deinit(&src);

    return 0;
}
