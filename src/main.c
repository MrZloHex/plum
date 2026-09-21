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
#include "preproc.h"
#include "meta.h"
#include "codegen.h"

#define DYNSTR_IMPL
#include "dynstr.h"


/* Basename without directory or extension; used to name the LLVM module. */
static const char *
module_name_of(const char *path)
{
    static char buf[256];

    const char *slash = strrchr(path, '/');
    const char *base  = slash ? slash + 1 : path;

    snprintf(buf, sizeof(buf), "%s", base);
    char *dot = strrchr(buf, '.');
    if (dot)
    { *dot = '\0'; }

    return buf;
}

int
main(int argc, char *argv[])
{
    tracer_init(TRC_DEBUG, TP_FUNC | TP_LINE);

    Options opts = parse_cli_options(argc, argv);
    if (opts.file_start_index >= argc)
    {
        fprintf(stderr, "Error: No input files provided.\n");
        usage(stderr, argv[0]);
        exit(EXIT_FAILURE);
    }

    if (argc - opts.file_start_index > 1)
    {
        fprintf(stderr, "Warning: only `%s' is compiled; %d further input file(s) ignored.\n",
                argv[opts.file_start_index], argc - opts.file_start_index - 1);
    }

    /* IR is the default; the AST dump is a debugging aid. */
    bool emit_ir = !(opts.emit_type && strcmp(opts.emit_type, "AST") == 0);

    char *source_file = realpath(argv[opts.file_start_index], NULL);
    if (!source_file)
    {
        fprintf(stderr, "Failed to resolve source file: %s\n", argv[opts.file_start_index]);
        exit(EXIT_FAILURE);
    }

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

    /* !USES expansion. Paths resolve against the CWD, not the including
       file, which is why build.sh runs plc from inside the test directory. */
    if (preprocess(&src) != 0)
    {
        fprintf(stderr, "Preprocessing failed: %s\n", source_file);
        dynstr_deinit(&src);
        free(source_file);
        exit(EXIT_FAILURE);
    }

    AST ast;
    ast_init(&ast);
    parse_unit(&ast, &src);

    Meta meta;
    meta_init(&meta);
    meta_pass(&meta, &ast);

    if (emit_ir)
    {
        CodegenContext cg;
        codegen_init(&cg, module_name_of(source_file), &meta);
        codegen_generate(ast.root, &cg);
        codegen_deinit(&cg, opts.output_file ? opts.output_file : "/dev/stdout");
    }
    else
    {
        FILE *fout = stdout;
        if (opts.output_file)
        {
            fout = fopen(opts.output_file, "w");
            if (!fout)
            {
                fprintf(stderr, "Failed to open output file: %s\n", opts.output_file);
                exit(EXIT_FAILURE);
            }
        }

        ast_dump(&ast, fout);
        meta_dump(&meta, fout);

        if (fout != stdout)
        { fclose(fout); }
    }

    ast_deinit(&ast);
    meta_deinit(&meta);
    dynstr_deinit(&src);
    free(source_file);

    return 0;
}
