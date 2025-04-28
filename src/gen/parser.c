/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison implementation for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2021 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* C LALR(1) parser skeleton written by Richard Stallman, by
   simplifying the original so-called "semantic" parser.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

/* All symbols defined below should begin with yy or YY, to avoid
   infringing on user name space.  This should be done even for local
   variables, as they might otherwise be expanded by user macros.
   There are some unavoidable exceptions within include files to
   define necessary library symbols; they are noted "INFRINGES ON
   USER NAME SPACE" below.  */

/* Identify Bison output, and Bison version.  */
#define YYBISON 30802

/* Bison version string.  */
#define YYBISON_VERSION "3.8.2"

/* Skeleton name.  */
#define YYSKELETON_NAME "yacc.c"

/* Pure parsers.  */
#define YYPURE 0

/* Push parsers.  */
#define YYPUSH 0

/* Pull parsers.  */
#define YYPULL 1




/* First part of user prologue.  */
#line 15 "src/parser.y"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "ast.h"

void yyerror(const char *s);
int yylex(void);

extern Node *root;


#line 85 "src/gen/parser.c"

# ifndef YY_CAST
#  ifdef __cplusplus
#   define YY_CAST(Type, Val) static_cast<Type> (Val)
#   define YY_REINTERPRET_CAST(Type, Val) reinterpret_cast<Type> (Val)
#  else
#   define YY_CAST(Type, Val) ((Type) (Val))
#   define YY_REINTERPRET_CAST(Type, Val) ((Type) (Val))
#  endif
# endif
# ifndef YY_NULLPTR
#  if defined __cplusplus
#   if 201103L <= __cplusplus
#    define YY_NULLPTR nullptr
#   else
#    define YY_NULLPTR 0
#   endif
#  else
#   define YY_NULLPTR ((void*)0)
#  endif
# endif

#include "parser.h"
/* Symbol kind.  */
enum yysymbol_kind_t
{
  YYSYMBOL_YYEMPTY = -2,
  YYSYMBOL_YYEOF = 0,                      /* "end of file"  */
  YYSYMBOL_YYerror = 1,                    /* error  */
  YYSYMBOL_YYUNDEF = 2,                    /* "invalid token"  */
  YYSYMBOL_TYPE = 3,                       /* TYPE  */
  YYSYMBOL_IDENT = 4,                      /* IDENT  */
  YYSYMBOL_NUM_LITERAL = 5,                /* NUM_LITERAL  */
  YYSYMBOL_CHR_LITERAL = 6,                /* CHR_LITERAL  */
  YYSYMBOL_STR_LITERAL = 7,                /* STR_LITERAL  */
  YYSYMBOL_VBAR = 8,                       /* VBAR  */
  YYSYMBOL_BLOCK_END = 9,                  /* BLOCK_END  */
  YYSYMBOL_BLOCK_CONTINUE = 10,            /* BLOCK_CONTINUE  */
  YYSYMBOL_COLON = 11,                     /* COLON  */
  YYSYMBOL_LBRACKET = 12,                  /* LBRACKET  */
  YYSYMBOL_RBRACKET = 13,                  /* RBRACKET  */
  YYSYMBOL_PTR = 14,                       /* PTR  */
  YYSYMBOL_EQUAL = 15,                     /* EQUAL  */
  YYSYMBOL_LPAREN = 16,                    /* LPAREN  */
  YYSYMBOL_RPAREN = 17,                    /* RPAREN  */
  YYSYMBOL_RET = 18,                       /* RET  */
  YYSYMBOL_PLUS = 19,                      /* PLUS  */
  YYSYMBOL_MINUS = 20,                     /* MINUS  */
  YYSYMBOL_STAR = 21,                      /* STAR  */
  YYSYMBOL_SLASH = 22,                     /* SLASH  */
  YYSYMBOL_MODULA = 23,                    /* MODULA  */
  YYSYMBOL_DOUBLE_EQUAL = 24,              /* DOUBLE_EQUAL  */
  YYSYMBOL_NOT_EQUAL = 25,                 /* NOT_EQUAL  */
  YYSYMBOL_LESS = 26,                      /* LESS  */
  YYSYMBOL_LEQ = 27,                       /* LEQ  */
  YYSYMBOL_GREAT = 28,                     /* GREAT  */
  YYSYMBOL_GEQ = 29,                       /* GEQ  */
  YYSYMBOL_IF = 30,                        /* IF  */
  YYSYMBOL_ELIF = 31,                      /* ELIF  */
  YYSYMBOL_ELSE = 32,                      /* ELSE  */
  YYSYMBOL_LOOP = 33,                      /* LOOP  */
  YYSYMBOL_BREAK = 34,                     /* BREAK  */
  YYSYMBOL_B1_FALSE = 35,                  /* B1_FALSE  */
  YYSYMBOL_B1_TRUE = 36,                   /* B1_TRUE  */
  YYSYMBOL_ELLIPSIS = 37,                  /* ELLIPSIS  */
  YYSYMBOL_TYPEDEF = 38,                   /* TYPEDEF  */
  YYSYMBOL_INDENT = 39,                    /* INDENT  */
  YYSYMBOL_YYACCEPT = 40,                  /* $accept  */
  YYSYMBOL_program = 41,                   /* program  */
  YYSYMBOL_prg_stmt = 42,                  /* prg_stmt  */
  YYSYMBOL_fn_def = 43,                    /* fn_def  */
  YYSYMBOL_fn_decl = 44,                   /* fn_decl  */
  YYSYMBOL_type_def = 45,                  /* type_def  */
  YYSYMBOL_param_list_opt = 46,            /* param_list_opt  */
  YYSYMBOL_param_list = 47,                /* param_list  */
  YYSYMBOL_parametre = 48,                 /* parametre  */
  YYSYMBOL_block_with_continue = 49,       /* block_with_continue  */
  YYSYMBOL_block_with_end = 50,            /* block_with_end  */
  YYSYMBOL_block_line_list = 51,           /* block_line_list  */
  YYSYMBOL_block_line = 52,                /* block_line  */
  YYSYMBOL_indent_seq = 53,                /* indent_seq  */
  YYSYMBOL_stmt = 54,                      /* stmt  */
  YYSYMBOL_loop_stmt = 55,                 /* loop_stmt  */
  YYSYMBOL_cond_stmt = 56,                 /* cond_stmt  */
  YYSYMBOL_cond_if = 57,                   /* cond_if  */
  YYSYMBOL_cond_if_else = 58,              /* cond_if_else  */
  YYSYMBOL_cond_else = 59,                 /* cond_else  */
  YYSYMBOL_var_decl = 60,                  /* var_decl  */
  YYSYMBOL_ret_stmt = 61,                  /* ret_stmt  */
  YYSYMBOL_expression = 62,                /* expression  */
  YYSYMBOL_function_call = 63,             /* function_call  */
  YYSYMBOL_arg_list_opt = 64,              /* arg_list_opt  */
  YYSYMBOL_arg_list = 65,                  /* arg_list  */
  YYSYMBOL_type = 66                       /* type  */
};
typedef enum yysymbol_kind_t yysymbol_kind_t;




#ifdef short
# undef short
#endif

/* On compilers that do not define __PTRDIFF_MAX__ etc., make sure
   <limits.h> and (if available) <stdint.h> are included
   so that the code can choose integer types of a good width.  */

#ifndef __PTRDIFF_MAX__
# include <limits.h> /* INFRINGES ON USER NAME SPACE */
# if defined __STDC_VERSION__ && 199901 <= __STDC_VERSION__
#  include <stdint.h> /* INFRINGES ON USER NAME SPACE */
#  define YY_STDINT_H
# endif
#endif

/* Narrow types that promote to a signed type and that can represent a
   signed or unsigned integer of at least N bits.  In tables they can
   save space and decrease cache pressure.  Promoting to a signed type
   helps avoid bugs in integer arithmetic.  */

#ifdef __INT_LEAST8_MAX__
typedef __INT_LEAST8_TYPE__ yytype_int8;
#elif defined YY_STDINT_H
typedef int_least8_t yytype_int8;
#else
typedef signed char yytype_int8;
#endif

#ifdef __INT_LEAST16_MAX__
typedef __INT_LEAST16_TYPE__ yytype_int16;
#elif defined YY_STDINT_H
typedef int_least16_t yytype_int16;
#else
typedef short yytype_int16;
#endif

/* Work around bug in HP-UX 11.23, which defines these macros
   incorrectly for preprocessor constants.  This workaround can likely
   be removed in 2023, as HPE has promised support for HP-UX 11.23
   (aka HP-UX 11i v2) only through the end of 2022; see Table 2 of
   <https://h20195.www2.hpe.com/V2/getpdf.aspx/4AA4-7673ENW.pdf>.  */
#ifdef __hpux
# undef UINT_LEAST8_MAX
# undef UINT_LEAST16_MAX
# define UINT_LEAST8_MAX 255
# define UINT_LEAST16_MAX 65535
#endif

#if defined __UINT_LEAST8_MAX__ && __UINT_LEAST8_MAX__ <= __INT_MAX__
typedef __UINT_LEAST8_TYPE__ yytype_uint8;
#elif (!defined __UINT_LEAST8_MAX__ && defined YY_STDINT_H \
       && UINT_LEAST8_MAX <= INT_MAX)
typedef uint_least8_t yytype_uint8;
#elif !defined __UINT_LEAST8_MAX__ && UCHAR_MAX <= INT_MAX
typedef unsigned char yytype_uint8;
#else
typedef short yytype_uint8;
#endif

#if defined __UINT_LEAST16_MAX__ && __UINT_LEAST16_MAX__ <= __INT_MAX__
typedef __UINT_LEAST16_TYPE__ yytype_uint16;
#elif (!defined __UINT_LEAST16_MAX__ && defined YY_STDINT_H \
       && UINT_LEAST16_MAX <= INT_MAX)
typedef uint_least16_t yytype_uint16;
#elif !defined __UINT_LEAST16_MAX__ && USHRT_MAX <= INT_MAX
typedef unsigned short yytype_uint16;
#else
typedef int yytype_uint16;
#endif

#ifndef YYPTRDIFF_T
# if defined __PTRDIFF_TYPE__ && defined __PTRDIFF_MAX__
#  define YYPTRDIFF_T __PTRDIFF_TYPE__
#  define YYPTRDIFF_MAXIMUM __PTRDIFF_MAX__
# elif defined PTRDIFF_MAX
#  ifndef ptrdiff_t
#   include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  endif
#  define YYPTRDIFF_T ptrdiff_t
#  define YYPTRDIFF_MAXIMUM PTRDIFF_MAX
# else
#  define YYPTRDIFF_T long
#  define YYPTRDIFF_MAXIMUM LONG_MAX
# endif
#endif

#ifndef YYSIZE_T
# ifdef __SIZE_TYPE__
#  define YYSIZE_T __SIZE_TYPE__
# elif defined size_t
#  define YYSIZE_T size_t
# elif defined __STDC_VERSION__ && 199901 <= __STDC_VERSION__
#  include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  define YYSIZE_T size_t
# else
#  define YYSIZE_T unsigned
# endif
#endif

#define YYSIZE_MAXIMUM                                  \
  YY_CAST (YYPTRDIFF_T,                                 \
           (YYPTRDIFF_MAXIMUM < YY_CAST (YYSIZE_T, -1)  \
            ? YYPTRDIFF_MAXIMUM                         \
            : YY_CAST (YYSIZE_T, -1)))

#define YYSIZEOF(X) YY_CAST (YYPTRDIFF_T, sizeof (X))


/* Stored state numbers (used for stacks). */
typedef yytype_int8 yy_state_t;

/* State numbers in computations.  */
typedef int yy_state_fast_t;

#ifndef YY_
# if defined YYENABLE_NLS && YYENABLE_NLS
#  if ENABLE_NLS
#   include <libintl.h> /* INFRINGES ON USER NAME SPACE */
#   define YY_(Msgid) dgettext ("bison-runtime", Msgid)
#  endif
# endif
# ifndef YY_
#  define YY_(Msgid) Msgid
# endif
#endif


#ifndef YY_ATTRIBUTE_PURE
# if defined __GNUC__ && 2 < __GNUC__ + (96 <= __GNUC_MINOR__)
#  define YY_ATTRIBUTE_PURE __attribute__ ((__pure__))
# else
#  define YY_ATTRIBUTE_PURE
# endif
#endif

#ifndef YY_ATTRIBUTE_UNUSED
# if defined __GNUC__ && 2 < __GNUC__ + (7 <= __GNUC_MINOR__)
#  define YY_ATTRIBUTE_UNUSED __attribute__ ((__unused__))
# else
#  define YY_ATTRIBUTE_UNUSED
# endif
#endif

/* Suppress unused-variable warnings by "using" E.  */
#if ! defined lint || defined __GNUC__
# define YY_USE(E) ((void) (E))
#else
# define YY_USE(E) /* empty */
#endif

/* Suppress an incorrect diagnostic about yylval being uninitialized.  */
#if defined __GNUC__ && ! defined __ICC && 406 <= __GNUC__ * 100 + __GNUC_MINOR__
# if __GNUC__ * 100 + __GNUC_MINOR__ < 407
#  define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN                           \
    _Pragma ("GCC diagnostic push")                                     \
    _Pragma ("GCC diagnostic ignored \"-Wuninitialized\"")
# else
#  define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN                           \
    _Pragma ("GCC diagnostic push")                                     \
    _Pragma ("GCC diagnostic ignored \"-Wuninitialized\"")              \
    _Pragma ("GCC diagnostic ignored \"-Wmaybe-uninitialized\"")
# endif
# define YY_IGNORE_MAYBE_UNINITIALIZED_END      \
    _Pragma ("GCC diagnostic pop")
#else
# define YY_INITIAL_VALUE(Value) Value
#endif
#ifndef YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
# define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
# define YY_IGNORE_MAYBE_UNINITIALIZED_END
#endif
#ifndef YY_INITIAL_VALUE
# define YY_INITIAL_VALUE(Value) /* Nothing. */
#endif

#if defined __cplusplus && defined __GNUC__ && ! defined __ICC && 6 <= __GNUC__
# define YY_IGNORE_USELESS_CAST_BEGIN                          \
    _Pragma ("GCC diagnostic push")                            \
    _Pragma ("GCC diagnostic ignored \"-Wuseless-cast\"")
# define YY_IGNORE_USELESS_CAST_END            \
    _Pragma ("GCC diagnostic pop")
#endif
#ifndef YY_IGNORE_USELESS_CAST_BEGIN
# define YY_IGNORE_USELESS_CAST_BEGIN
# define YY_IGNORE_USELESS_CAST_END
#endif


#define YY_ASSERT(E) ((void) (0 && (E)))

#if 1

/* The parser invokes alloca or malloc; define the necessary symbols.  */

# ifdef YYSTACK_USE_ALLOCA
#  if YYSTACK_USE_ALLOCA
#   ifdef __GNUC__
#    define YYSTACK_ALLOC __builtin_alloca
#   elif defined __BUILTIN_VA_ARG_INCR
#    include <alloca.h> /* INFRINGES ON USER NAME SPACE */
#   elif defined _AIX
#    define YYSTACK_ALLOC __alloca
#   elif defined _MSC_VER
#    include <malloc.h> /* INFRINGES ON USER NAME SPACE */
#    define alloca _alloca
#   else
#    define YYSTACK_ALLOC alloca
#    if ! defined _ALLOCA_H && ! defined EXIT_SUCCESS
#     include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
      /* Use EXIT_SUCCESS as a witness for stdlib.h.  */
#     ifndef EXIT_SUCCESS
#      define EXIT_SUCCESS 0
#     endif
#    endif
#   endif
#  endif
# endif

# ifdef YYSTACK_ALLOC
   /* Pacify GCC's 'empty if-body' warning.  */
#  define YYSTACK_FREE(Ptr) do { /* empty */; } while (0)
#  ifndef YYSTACK_ALLOC_MAXIMUM
    /* The OS might guarantee only one guard page at the bottom of the stack,
       and a page size can be as small as 4096 bytes.  So we cannot safely
       invoke alloca (N) if N exceeds 4096.  Use a slightly smaller number
       to allow for a few compiler-allocated temporary stack slots.  */
#   define YYSTACK_ALLOC_MAXIMUM 4032 /* reasonable circa 2006 */
#  endif
# else
#  define YYSTACK_ALLOC YYMALLOC
#  define YYSTACK_FREE YYFREE
#  ifndef YYSTACK_ALLOC_MAXIMUM
#   define YYSTACK_ALLOC_MAXIMUM YYSIZE_MAXIMUM
#  endif
#  if (defined __cplusplus && ! defined EXIT_SUCCESS \
       && ! ((defined YYMALLOC || defined malloc) \
             && (defined YYFREE || defined free)))
#   include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
#   ifndef EXIT_SUCCESS
#    define EXIT_SUCCESS 0
#   endif
#  endif
#  ifndef YYMALLOC
#   define YYMALLOC malloc
#   if ! defined malloc && ! defined EXIT_SUCCESS
void *malloc (YYSIZE_T); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
#  ifndef YYFREE
#   define YYFREE free
#   if ! defined free && ! defined EXIT_SUCCESS
void free (void *); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
# endif
#endif /* 1 */

#if (! defined yyoverflow \
     && (! defined __cplusplus \
         || (defined YYLTYPE_IS_TRIVIAL && YYLTYPE_IS_TRIVIAL \
             && defined YYSTYPE_IS_TRIVIAL && YYSTYPE_IS_TRIVIAL)))

/* A type that is properly aligned for any stack member.  */
union yyalloc
{
  yy_state_t yyss_alloc;
  YYSTYPE yyvs_alloc;
  YYLTYPE yyls_alloc;
};

/* The size of the maximum gap between one aligned stack and the next.  */
# define YYSTACK_GAP_MAXIMUM (YYSIZEOF (union yyalloc) - 1)

/* The size of an array large to enough to hold all stacks, each with
   N elements.  */
# define YYSTACK_BYTES(N) \
     ((N) * (YYSIZEOF (yy_state_t) + YYSIZEOF (YYSTYPE) \
             + YYSIZEOF (YYLTYPE)) \
      + 2 * YYSTACK_GAP_MAXIMUM)

# define YYCOPY_NEEDED 1

/* Relocate STACK from its old location to the new one.  The
   local variables YYSIZE and YYSTACKSIZE give the old and new number of
   elements in the stack, and YYPTR gives the new location of the
   stack.  Advance YYPTR to a properly aligned location for the next
   stack.  */
# define YYSTACK_RELOCATE(Stack_alloc, Stack)                           \
    do                                                                  \
      {                                                                 \
        YYPTRDIFF_T yynewbytes;                                         \
        YYCOPY (&yyptr->Stack_alloc, Stack, yysize);                    \
        Stack = &yyptr->Stack_alloc;                                    \
        yynewbytes = yystacksize * YYSIZEOF (*Stack) + YYSTACK_GAP_MAXIMUM; \
        yyptr += yynewbytes / YYSIZEOF (*yyptr);                        \
      }                                                                 \
    while (0)

#endif

#if defined YYCOPY_NEEDED && YYCOPY_NEEDED
/* Copy COUNT objects from SRC to DST.  The source and destination do
   not overlap.  */
# ifndef YYCOPY
#  if defined __GNUC__ && 1 < __GNUC__
#   define YYCOPY(Dst, Src, Count) \
      __builtin_memcpy (Dst, Src, YY_CAST (YYSIZE_T, (Count)) * sizeof (*(Src)))
#  else
#   define YYCOPY(Dst, Src, Count)              \
      do                                        \
        {                                       \
          YYPTRDIFF_T yyi;                      \
          for (yyi = 0; yyi < (Count); yyi++)   \
            (Dst)[yyi] = (Src)[yyi];            \
        }                                       \
      while (0)
#  endif
# endif
#endif /* !YYCOPY_NEEDED */

/* YYFINAL -- State number of the termination state.  */
#define YYFINAL  13
/* YYLAST -- Last index in YYTABLE.  */
#define YYLAST   236

/* YYNTOKENS -- Number of terminals.  */
#define YYNTOKENS  40
/* YYNNTS -- Number of nonterminals.  */
#define YYNNTS  27
/* YYNRULES -- Number of rules.  */
#define YYNRULES  68
/* YYNSTATES -- Number of states.  */
#define YYNSTATES  116

/* YYMAXUTOK -- Last valid token kind.  */
#define YYMAXUTOK   294


/* YYTRANSLATE(TOKEN-NUM) -- Symbol number corresponding to TOKEN-NUM
   as returned by yylex, with out-of-bounds checking.  */
#define YYTRANSLATE(YYX)                                \
  (0 <= (YYX) && (YYX) <= YYMAXUTOK                     \
   ? YY_CAST (yysymbol_kind_t, yytranslate[YYX])        \
   : YYSYMBOL_YYUNDEF)

/* YYTRANSLATE[TOKEN-NUM] -- Symbol number corresponding to TOKEN-NUM
   as returned by yylex.  */
static const yytype_int8 yytranslate[] =
{
       0,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     1,     2,     3,     4,
       5,     6,     7,     8,     9,    10,    11,    12,    13,    14,
      15,    16,    17,    18,    19,    20,    21,    22,    23,    24,
      25,    26,    27,    28,    29,    30,    31,    32,    33,    34,
      35,    36,    37,    38,    39
};

#if YYDEBUG
/* YYRLINE[YYN] -- Source line where rule number YYN was defined.  */
static const yytype_int16 yyrline[] =
{
       0,    76,    76,    81,    92,    94,    96,   100,   105,   113,
     121,   123,   128,   130,   141,   146,   153,   158,   163,   165,
     176,   181,   183,   188,   190,   192,   194,   196,   198,   200,
     205,   210,   212,   217,   222,   227,   233,   238,   246,   250,
     255,   257,   262,   267,   272,   277,   282,   287,   292,   297,
     302,   307,   312,   317,   322,   324,   329,   334,   339,   344,
     349,   357,   365,   367,   372,   374,   385,   387,   389
};
#endif

/** Accessing symbol of state STATE.  */
#define YY_ACCESSING_SYMBOL(State) YY_CAST (yysymbol_kind_t, yystos[State])

#if 1
/* The user-facing name of the symbol whose (internal) number is
   YYSYMBOL.  No bounds checking.  */
static const char *yysymbol_name (yysymbol_kind_t yysymbol) YY_ATTRIBUTE_UNUSED;

/* YYTNAME[SYMBOL-NUM] -- String name of the symbol SYMBOL-NUM.
   First, the terminals, then, starting at YYNTOKENS, nonterminals.  */
static const char *const yytname[] =
{
  "\"end of file\"", "error", "\"invalid token\"", "TYPE", "IDENT",
  "NUM_LITERAL", "CHR_LITERAL", "STR_LITERAL", "VBAR", "BLOCK_END",
  "BLOCK_CONTINUE", "COLON", "LBRACKET", "RBRACKET", "PTR", "EQUAL",
  "LPAREN", "RPAREN", "RET", "PLUS", "MINUS", "STAR", "SLASH", "MODULA",
  "DOUBLE_EQUAL", "NOT_EQUAL", "LESS", "LEQ", "GREAT", "GEQ", "IF", "ELIF",
  "ELSE", "LOOP", "BREAK", "B1_FALSE", "B1_TRUE", "ELLIPSIS", "TYPEDEF",
  "INDENT", "$accept", "program", "prg_stmt", "fn_def", "fn_decl",
  "type_def", "param_list_opt", "param_list", "parametre",
  "block_with_continue", "block_with_end", "block_line_list", "block_line",
  "indent_seq", "stmt", "loop_stmt", "cond_stmt", "cond_if",
  "cond_if_else", "cond_else", "var_decl", "ret_stmt", "expression",
  "function_call", "arg_list_opt", "arg_list", "type", YY_NULLPTR
};

static const char *
yysymbol_name (yysymbol_kind_t yysymbol)
{
  return yytname[yysymbol];
}
#endif

#define YYPACT_NINF (-29)

#define yypact_value_is_default(Yyn) \
  ((Yyn) == YYPACT_NINF)

#define YYTABLE_NINF (-68)

#define yytable_value_is_error(Yyn) \
  0

/* YYPACT[STATE-NUM] -- Index in YYTABLE of the portion describing
   STATE-NUM.  */
static const yytype_int16 yypact[] =
{
      17,   -29,   -29,     3,     1,    15,   -29,   -29,     5,   -29,
       7,   -29,    21,   -29,   -29,     5,   -29,    16,   -29,    58,
      23,     5,   -29,   -29,   -29,    24,   -29,   -29,   -29,    98,
     115,    25,    26,     5,   -29,   -29,   -29,   -29,   -29,   -29,
     -29,     5,   -29,   -29,   187,   -29,    35,    40,   -29,   -29,
      10,   138,   172,   102,   138,   -29,    22,   -29,   138,   138,
     138,   138,   138,   138,   138,   138,   138,   138,   138,   138,
      42,    19,    46,   -29,   -29,   -29,   140,   157,     5,   198,
     207,   207,    57,    57,    57,    97,    97,   -29,   -29,   -29,
     -29,   138,   -29,    47,    59,   -29,    62,   138,   -29,     5,
     -29,   187,   -29,    19,   -29,   187,    56,    63,   -29,   -29,
       0,   -29,   -29,   138,   -29,   187
};

/* YYDEFACT[STATE-NUM] -- Default reduction number in state STATE-NUM.
   Performed when YYTABLE does not specify something else to do.  Zero
   means the default is an error.  */
static const yytype_int8 yydefact[] =
{
       0,    66,    67,     0,     0,     0,     2,     4,     5,     6,
       0,    68,     0,     1,     3,    21,     7,     0,    18,    23,
       0,     0,    22,    17,    19,    58,    57,    56,    55,     0,
       0,     0,     0,     0,    29,    60,    59,    20,    28,    27,
      31,     0,    25,    26,    24,    54,     0,     0,     9,    53,
      58,     0,     0,     0,     0,    30,     0,    32,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
      37,    10,     0,    58,    40,    39,     0,     0,     0,    41,
      42,    43,    44,    45,    46,    47,    48,    49,    50,    51,
      52,     0,    15,     0,    11,    12,     0,    62,    38,     0,
      35,    36,     8,     0,    14,    64,     0,    63,    34,    33,
       0,    13,    61,     0,    16,    65
};

/* YYPGOTO[NTERM-NUM].  */
static const yytype_int8 yypgoto[] =
{
     -29,   -29,    65,   -29,   -29,   -29,   -29,   -29,   -28,   -29,
     -19,   -22,   -14,   -11,   -29,   -29,   -29,   -29,   -29,   -29,
     -29,   -29,   -18,   -29,   -29,   -29,    -3
};

/* YYDEFGOTO[NTERM-NUM].  */
static const yytype_int8 yydefgoto[] =
{
       0,     5,     6,     7,     8,     9,    93,    94,    95,   108,
      16,    17,    18,    19,    37,    38,    39,    40,    41,    57,
      42,    43,    49,    45,   106,   107,    10
};

/* YYTABLE[YYPACT[STATE-NUM]] -- What to do in state STATE-NUM.  If
   positive, shift that token.  If negative, reduce the rule whose
   number is the opposite.  If YYTABLE_NINF, syntax error.  */
static const yytype_int8 yytable[] =
{
      11,    44,    48,    24,    22,    12,     1,     2,    15,    23,
     114,    20,    52,    15,    55,    13,    46,     3,     1,     2,
       1,     2,     1,     2,    15,    23,    11,    72,   -67,     3,
      56,     3,    21,     3,    47,    76,    77,    53,    54,    70,
      79,    80,    81,    82,    83,    84,    85,    86,    87,    88,
      89,    90,    71,     4,    78,     4,    92,    91,    97,   100,
     102,     1,    25,    26,    27,    28,   104,   103,    96,   112,
      14,   113,    29,   101,    30,   111,    31,   110,     0,   105,
     109,    64,    65,    66,    67,    68,    69,     0,    32,     0,
       0,    33,    34,    35,    36,   115,    24,     0,     0,     0,
      96,     1,    25,    26,    27,    28,    73,    26,    27,    28,
       0,     0,    29,     0,    30,    75,    51,     0,    30,    50,
      26,    27,    28,    66,    67,    68,    69,     0,     0,    51,
       0,    30,     0,    35,    36,     0,     0,    35,    36,     0,
       0,     0,    73,    26,    27,    28,     0,     0,     0,     0,
      35,    36,    51,    98,    30,    58,     0,     0,     0,    59,
      60,    61,    62,    63,    64,    65,    66,    67,    68,    69,
      99,     0,    58,    35,    36,     0,    59,    60,    61,    62,
      63,    64,    65,    66,    67,    68,    69,    58,     0,    74,
       0,    59,    60,    61,    62,    63,    64,    65,    66,    67,
      68,    69,    58,     0,     0,     0,    59,    60,    61,    62,
      63,    64,    65,    66,    67,    68,    69,    59,    60,    61,
      62,    63,    64,    65,    66,    67,    68,    69,    61,    62,
      63,    64,    65,    66,    67,    68,    69
};

static const yytype_int8 yycheck[] =
{
       3,    19,    21,    17,    15,     4,     3,     4,     8,     9,
      10,     4,    30,     8,    33,     0,    19,    14,     3,     4,
       3,     4,     3,     4,     8,     9,    29,    17,     4,    14,
      41,    14,    11,    14,    11,    53,    54,    12,    12,     4,
      58,    59,    60,    61,    62,    63,    64,    65,    66,    67,
      68,    69,    12,    38,    32,    38,    37,    15,    12,    78,
      13,     3,     4,     5,     6,     7,     4,     8,    71,    13,
       5,     8,    14,    91,    16,   103,    18,    99,    -1,    97,
      99,    24,    25,    26,    27,    28,    29,    -1,    30,    -1,
      -1,    33,    34,    35,    36,   113,   110,    -1,    -1,    -1,
     103,     3,     4,     5,     6,     7,     4,     5,     6,     7,
      -1,    -1,    14,    -1,    16,    13,    14,    -1,    16,     4,
       5,     6,     7,    26,    27,    28,    29,    -1,    -1,    14,
      -1,    16,    -1,    35,    36,    -1,    -1,    35,    36,    -1,
      -1,    -1,     4,     5,     6,     7,    -1,    -1,    -1,    -1,
      35,    36,    14,    13,    16,    15,    -1,    -1,    -1,    19,
      20,    21,    22,    23,    24,    25,    26,    27,    28,    29,
      13,    -1,    15,    35,    36,    -1,    19,    20,    21,    22,
      23,    24,    25,    26,    27,    28,    29,    15,    -1,    17,
      -1,    19,    20,    21,    22,    23,    24,    25,    26,    27,
      28,    29,    15,    -1,    -1,    -1,    19,    20,    21,    22,
      23,    24,    25,    26,    27,    28,    29,    19,    20,    21,
      22,    23,    24,    25,    26,    27,    28,    29,    21,    22,
      23,    24,    25,    26,    27,    28,    29
};

/* YYSTOS[STATE-NUM] -- The symbol kind of the accessing symbol of
   state STATE-NUM.  */
static const yytype_int8 yystos[] =
{
       0,     3,     4,    14,    38,    41,    42,    43,    44,    45,
      66,    66,     4,     0,    42,     8,    50,    51,    52,    53,
       4,    11,    53,     9,    52,     4,     5,     6,     7,    14,
      16,    18,    30,    33,    34,    35,    36,    54,    55,    56,
      57,    58,    60,    61,    62,    63,    66,    11,    50,    62,
       4,    14,    62,    12,    12,    50,    53,    59,    15,    19,
      20,    21,    22,    23,    24,    25,    26,    27,    28,    29,
       4,    12,    17,     4,    17,    13,    62,    62,    32,    62,
      62,    62,    62,    62,    62,    62,    62,    62,    62,    62,
      62,    15,    37,    46,    47,    48,    66,    12,    13,    13,
      50,    62,    13,     8,     4,    62,    64,    65,    49,    50,
      51,    48,    13,     8,    10,    62
};

/* YYR1[RULE-NUM] -- Symbol kind of the left-hand side of rule RULE-NUM.  */
static const yytype_int8 yyr1[] =
{
       0,    40,    41,    41,    42,    42,    42,    43,    44,    45,
      46,    46,    47,    47,    48,    48,    49,    50,    51,    51,
      52,    53,    53,    54,    54,    54,    54,    54,    54,    54,
      55,    56,    56,    57,    58,    59,    60,    60,    61,    61,
      62,    62,    62,    62,    62,    62,    62,    62,    62,    62,
      62,    62,    62,    62,    62,    62,    62,    62,    62,    62,
      62,    63,    64,    64,    65,    65,    66,    66,    66
};

/* YYR2[RULE-NUM] -- Number of symbols on the right-hand side of rule RULE-NUM.  */
static const yytype_int8 yyr2[] =
{
       0,     2,     1,     2,     1,     1,     1,     2,     6,     4,
       0,     1,     1,     3,     2,     1,     2,     2,     1,     2,
       2,     1,     2,     0,     1,     1,     1,     1,     1,     1,
       2,     1,     2,     5,     5,     3,     4,     2,     4,     3,
       3,     3,     3,     3,     3,     3,     3,     3,     3,     3,
       3,     3,     3,     2,     1,     1,     1,     1,     1,     1,
       1,     6,     0,     1,     1,     3,     1,     1,     2
};


enum { YYENOMEM = -2 };

#define yyerrok         (yyerrstatus = 0)
#define yyclearin       (yychar = YYEMPTY)

#define YYACCEPT        goto yyacceptlab
#define YYABORT         goto yyabortlab
#define YYERROR         goto yyerrorlab
#define YYNOMEM         goto yyexhaustedlab


#define YYRECOVERING()  (!!yyerrstatus)

#define YYBACKUP(Token, Value)                                    \
  do                                                              \
    if (yychar == YYEMPTY)                                        \
      {                                                           \
        yychar = (Token);                                         \
        yylval = (Value);                                         \
        YYPOPSTACK (yylen);                                       \
        yystate = *yyssp;                                         \
        goto yybackup;                                            \
      }                                                           \
    else                                                          \
      {                                                           \
        yyerror (YY_("syntax error: cannot back up")); \
        YYERROR;                                                  \
      }                                                           \
  while (0)

/* Backward compatibility with an undocumented macro.
   Use YYerror or YYUNDEF. */
#define YYERRCODE YYUNDEF

/* YYLLOC_DEFAULT -- Set CURRENT to span from RHS[1] to RHS[N].
   If N is 0, then set CURRENT to the empty location which ends
   the previous symbol: RHS[0] (always defined).  */

#ifndef YYLLOC_DEFAULT
# define YYLLOC_DEFAULT(Current, Rhs, N)                                \
    do                                                                  \
      if (N)                                                            \
        {                                                               \
          (Current).first_line   = YYRHSLOC (Rhs, 1).first_line;        \
          (Current).first_column = YYRHSLOC (Rhs, 1).first_column;      \
          (Current).last_line    = YYRHSLOC (Rhs, N).last_line;         \
          (Current).last_column  = YYRHSLOC (Rhs, N).last_column;       \
        }                                                               \
      else                                                              \
        {                                                               \
          (Current).first_line   = (Current).last_line   =              \
            YYRHSLOC (Rhs, 0).last_line;                                \
          (Current).first_column = (Current).last_column =              \
            YYRHSLOC (Rhs, 0).last_column;                              \
        }                                                               \
    while (0)
#endif

#define YYRHSLOC(Rhs, K) ((Rhs)[K])


/* Enable debugging if requested.  */
#if YYDEBUG

# ifndef YYFPRINTF
#  include <stdio.h> /* INFRINGES ON USER NAME SPACE */
#  define YYFPRINTF fprintf
# endif

# define YYDPRINTF(Args)                        \
do {                                            \
  if (yydebug)                                  \
    YYFPRINTF Args;                             \
} while (0)


/* YYLOCATION_PRINT -- Print the location on the stream.
   This macro was not mandated originally: define only if we know
   we won't break user code: when these are the locations we know.  */

# ifndef YYLOCATION_PRINT

#  if defined YY_LOCATION_PRINT

   /* Temporary convenience wrapper in case some people defined the
      undocumented and private YY_LOCATION_PRINT macros.  */
#   define YYLOCATION_PRINT(File, Loc)  YY_LOCATION_PRINT(File, *(Loc))

#  elif defined YYLTYPE_IS_TRIVIAL && YYLTYPE_IS_TRIVIAL

/* Print *YYLOCP on YYO.  Private, do not rely on its existence. */

YY_ATTRIBUTE_UNUSED
static int
yy_location_print_ (FILE *yyo, YYLTYPE const * const yylocp)
{
  int res = 0;
  int end_col = 0 != yylocp->last_column ? yylocp->last_column - 1 : 0;
  if (0 <= yylocp->first_line)
    {
      res += YYFPRINTF (yyo, "%d", yylocp->first_line);
      if (0 <= yylocp->first_column)
        res += YYFPRINTF (yyo, ".%d", yylocp->first_column);
    }
  if (0 <= yylocp->last_line)
    {
      if (yylocp->first_line < yylocp->last_line)
        {
          res += YYFPRINTF (yyo, "-%d", yylocp->last_line);
          if (0 <= end_col)
            res += YYFPRINTF (yyo, ".%d", end_col);
        }
      else if (0 <= end_col && yylocp->first_column < end_col)
        res += YYFPRINTF (yyo, "-%d", end_col);
    }
  return res;
}

#   define YYLOCATION_PRINT  yy_location_print_

    /* Temporary convenience wrapper in case some people defined the
       undocumented and private YY_LOCATION_PRINT macros.  */
#   define YY_LOCATION_PRINT(File, Loc)  YYLOCATION_PRINT(File, &(Loc))

#  else

#   define YYLOCATION_PRINT(File, Loc) ((void) 0)
    /* Temporary convenience wrapper in case some people defined the
       undocumented and private YY_LOCATION_PRINT macros.  */
#   define YY_LOCATION_PRINT  YYLOCATION_PRINT

#  endif
# endif /* !defined YYLOCATION_PRINT */


# define YY_SYMBOL_PRINT(Title, Kind, Value, Location)                    \
do {                                                                      \
  if (yydebug)                                                            \
    {                                                                     \
      YYFPRINTF (stderr, "%s ", Title);                                   \
      yy_symbol_print (stderr,                                            \
                  Kind, Value, Location); \
      YYFPRINTF (stderr, "\n");                                           \
    }                                                                     \
} while (0)


/*-----------------------------------.
| Print this symbol's value on YYO.  |
`-----------------------------------*/

static void
yy_symbol_value_print (FILE *yyo,
                       yysymbol_kind_t yykind, YYSTYPE const * const yyvaluep, YYLTYPE const * const yylocationp)
{
  FILE *yyoutput = yyo;
  YY_USE (yyoutput);
  YY_USE (yylocationp);
  if (!yyvaluep)
    return;
  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  YY_USE (yykind);
  YY_IGNORE_MAYBE_UNINITIALIZED_END
}


/*---------------------------.
| Print this symbol on YYO.  |
`---------------------------*/

static void
yy_symbol_print (FILE *yyo,
                 yysymbol_kind_t yykind, YYSTYPE const * const yyvaluep, YYLTYPE const * const yylocationp)
{
  YYFPRINTF (yyo, "%s %s (",
             yykind < YYNTOKENS ? "token" : "nterm", yysymbol_name (yykind));

  YYLOCATION_PRINT (yyo, yylocationp);
  YYFPRINTF (yyo, ": ");
  yy_symbol_value_print (yyo, yykind, yyvaluep, yylocationp);
  YYFPRINTF (yyo, ")");
}

/*------------------------------------------------------------------.
| yy_stack_print -- Print the state stack from its BOTTOM up to its |
| TOP (included).                                                   |
`------------------------------------------------------------------*/

static void
yy_stack_print (yy_state_t *yybottom, yy_state_t *yytop)
{
  YYFPRINTF (stderr, "Stack now");
  for (; yybottom <= yytop; yybottom++)
    {
      int yybot = *yybottom;
      YYFPRINTF (stderr, " %d", yybot);
    }
  YYFPRINTF (stderr, "\n");
}

# define YY_STACK_PRINT(Bottom, Top)                            \
do {                                                            \
  if (yydebug)                                                  \
    yy_stack_print ((Bottom), (Top));                           \
} while (0)


/*------------------------------------------------.
| Report that the YYRULE is going to be reduced.  |
`------------------------------------------------*/

static void
yy_reduce_print (yy_state_t *yyssp, YYSTYPE *yyvsp, YYLTYPE *yylsp,
                 int yyrule)
{
  int yylno = yyrline[yyrule];
  int yynrhs = yyr2[yyrule];
  int yyi;
  YYFPRINTF (stderr, "Reducing stack by rule %d (line %d):\n",
             yyrule - 1, yylno);
  /* The symbols being reduced.  */
  for (yyi = 0; yyi < yynrhs; yyi++)
    {
      YYFPRINTF (stderr, "   $%d = ", yyi + 1);
      yy_symbol_print (stderr,
                       YY_ACCESSING_SYMBOL (+yyssp[yyi + 1 - yynrhs]),
                       &yyvsp[(yyi + 1) - (yynrhs)],
                       &(yylsp[(yyi + 1) - (yynrhs)]));
      YYFPRINTF (stderr, "\n");
    }
}

# define YY_REDUCE_PRINT(Rule)          \
do {                                    \
  if (yydebug)                          \
    yy_reduce_print (yyssp, yyvsp, yylsp, Rule); \
} while (0)

/* Nonzero means print parse trace.  It is left uninitialized so that
   multiple parsers can coexist.  */
int yydebug;
#else /* !YYDEBUG */
# define YYDPRINTF(Args) ((void) 0)
# define YY_SYMBOL_PRINT(Title, Kind, Value, Location)
# define YY_STACK_PRINT(Bottom, Top)
# define YY_REDUCE_PRINT(Rule)
#endif /* !YYDEBUG */


/* YYINITDEPTH -- initial size of the parser's stacks.  */
#ifndef YYINITDEPTH
# define YYINITDEPTH 200
#endif

/* YYMAXDEPTH -- maximum size the stacks can grow to (effective only
   if the built-in stack extension method is used).

   Do not make this value too large; the results are undefined if
   YYSTACK_ALLOC_MAXIMUM < YYSTACK_BYTES (YYMAXDEPTH)
   evaluated with infinite-precision integer arithmetic.  */

#ifndef YYMAXDEPTH
# define YYMAXDEPTH 10000
#endif


/* Context of a parse error.  */
typedef struct
{
  yy_state_t *yyssp;
  yysymbol_kind_t yytoken;
  YYLTYPE *yylloc;
} yypcontext_t;

/* Put in YYARG at most YYARGN of the expected tokens given the
   current YYCTX, and return the number of tokens stored in YYARG.  If
   YYARG is null, return the number of expected tokens (guaranteed to
   be less than YYNTOKENS).  Return YYENOMEM on memory exhaustion.
   Return 0 if there are more than YYARGN expected tokens, yet fill
   YYARG up to YYARGN. */
static int
yypcontext_expected_tokens (const yypcontext_t *yyctx,
                            yysymbol_kind_t yyarg[], int yyargn)
{
  /* Actual size of YYARG. */
  int yycount = 0;
  int yyn = yypact[+*yyctx->yyssp];
  if (!yypact_value_is_default (yyn))
    {
      /* Start YYX at -YYN if negative to avoid negative indexes in
         YYCHECK.  In other words, skip the first -YYN actions for
         this state because they are default actions.  */
      int yyxbegin = yyn < 0 ? -yyn : 0;
      /* Stay within bounds of both yycheck and yytname.  */
      int yychecklim = YYLAST - yyn + 1;
      int yyxend = yychecklim < YYNTOKENS ? yychecklim : YYNTOKENS;
      int yyx;
      for (yyx = yyxbegin; yyx < yyxend; ++yyx)
        if (yycheck[yyx + yyn] == yyx && yyx != YYSYMBOL_YYerror
            && !yytable_value_is_error (yytable[yyx + yyn]))
          {
            if (!yyarg)
              ++yycount;
            else if (yycount == yyargn)
              return 0;
            else
              yyarg[yycount++] = YY_CAST (yysymbol_kind_t, yyx);
          }
    }
  if (yyarg && yycount == 0 && 0 < yyargn)
    yyarg[0] = YYSYMBOL_YYEMPTY;
  return yycount;
}




#ifndef yystrlen
# if defined __GLIBC__ && defined _STRING_H
#  define yystrlen(S) (YY_CAST (YYPTRDIFF_T, strlen (S)))
# else
/* Return the length of YYSTR.  */
static YYPTRDIFF_T
yystrlen (const char *yystr)
{
  YYPTRDIFF_T yylen;
  for (yylen = 0; yystr[yylen]; yylen++)
    continue;
  return yylen;
}
# endif
#endif

#ifndef yystpcpy
# if defined __GLIBC__ && defined _STRING_H && defined _GNU_SOURCE
#  define yystpcpy stpcpy
# else
/* Copy YYSRC to YYDEST, returning the address of the terminating '\0' in
   YYDEST.  */
static char *
yystpcpy (char *yydest, const char *yysrc)
{
  char *yyd = yydest;
  const char *yys = yysrc;

  while ((*yyd++ = *yys++) != '\0')
    continue;

  return yyd - 1;
}
# endif
#endif

#ifndef yytnamerr
/* Copy to YYRES the contents of YYSTR after stripping away unnecessary
   quotes and backslashes, so that it's suitable for yyerror.  The
   heuristic is that double-quoting is unnecessary unless the string
   contains an apostrophe, a comma, or backslash (other than
   backslash-backslash).  YYSTR is taken from yytname.  If YYRES is
   null, do not copy; instead, return the length of what the result
   would have been.  */
static YYPTRDIFF_T
yytnamerr (char *yyres, const char *yystr)
{
  if (*yystr == '"')
    {
      YYPTRDIFF_T yyn = 0;
      char const *yyp = yystr;
      for (;;)
        switch (*++yyp)
          {
          case '\'':
          case ',':
            goto do_not_strip_quotes;

          case '\\':
            if (*++yyp != '\\')
              goto do_not_strip_quotes;
            else
              goto append;

          append:
          default:
            if (yyres)
              yyres[yyn] = *yyp;
            yyn++;
            break;

          case '"':
            if (yyres)
              yyres[yyn] = '\0';
            return yyn;
          }
    do_not_strip_quotes: ;
    }

  if (yyres)
    return yystpcpy (yyres, yystr) - yyres;
  else
    return yystrlen (yystr);
}
#endif


static int
yy_syntax_error_arguments (const yypcontext_t *yyctx,
                           yysymbol_kind_t yyarg[], int yyargn)
{
  /* Actual size of YYARG. */
  int yycount = 0;
  /* There are many possibilities here to consider:
     - If this state is a consistent state with a default action, then
       the only way this function was invoked is if the default action
       is an error action.  In that case, don't check for expected
       tokens because there are none.
     - The only way there can be no lookahead present (in yychar) is if
       this state is a consistent state with a default action.  Thus,
       detecting the absence of a lookahead is sufficient to determine
       that there is no unexpected or expected token to report.  In that
       case, just report a simple "syntax error".
     - Don't assume there isn't a lookahead just because this state is a
       consistent state with a default action.  There might have been a
       previous inconsistent state, consistent state with a non-default
       action, or user semantic action that manipulated yychar.
     - Of course, the expected token list depends on states to have
       correct lookahead information, and it depends on the parser not
       to perform extra reductions after fetching a lookahead from the
       scanner and before detecting a syntax error.  Thus, state merging
       (from LALR or IELR) and default reductions corrupt the expected
       token list.  However, the list is correct for canonical LR with
       one exception: it will still contain any token that will not be
       accepted due to an error action in a later state.
  */
  if (yyctx->yytoken != YYSYMBOL_YYEMPTY)
    {
      int yyn;
      if (yyarg)
        yyarg[yycount] = yyctx->yytoken;
      ++yycount;
      yyn = yypcontext_expected_tokens (yyctx,
                                        yyarg ? yyarg + 1 : yyarg, yyargn - 1);
      if (yyn == YYENOMEM)
        return YYENOMEM;
      else
        yycount += yyn;
    }
  return yycount;
}

/* Copy into *YYMSG, which is of size *YYMSG_ALLOC, an error message
   about the unexpected token YYTOKEN for the state stack whose top is
   YYSSP.

   Return 0 if *YYMSG was successfully written.  Return -1 if *YYMSG is
   not large enough to hold the message.  In that case, also set
   *YYMSG_ALLOC to the required number of bytes.  Return YYENOMEM if the
   required number of bytes is too large to store.  */
static int
yysyntax_error (YYPTRDIFF_T *yymsg_alloc, char **yymsg,
                const yypcontext_t *yyctx)
{
  enum { YYARGS_MAX = 5 };
  /* Internationalized format string. */
  const char *yyformat = YY_NULLPTR;
  /* Arguments of yyformat: reported tokens (one for the "unexpected",
     one per "expected"). */
  yysymbol_kind_t yyarg[YYARGS_MAX];
  /* Cumulated lengths of YYARG.  */
  YYPTRDIFF_T yysize = 0;

  /* Actual size of YYARG. */
  int yycount = yy_syntax_error_arguments (yyctx, yyarg, YYARGS_MAX);
  if (yycount == YYENOMEM)
    return YYENOMEM;

  switch (yycount)
    {
#define YYCASE_(N, S)                       \
      case N:                               \
        yyformat = S;                       \
        break
    default: /* Avoid compiler warnings. */
      YYCASE_(0, YY_("syntax error"));
      YYCASE_(1, YY_("syntax error, unexpected %s"));
      YYCASE_(2, YY_("syntax error, unexpected %s, expecting %s"));
      YYCASE_(3, YY_("syntax error, unexpected %s, expecting %s or %s"));
      YYCASE_(4, YY_("syntax error, unexpected %s, expecting %s or %s or %s"));
      YYCASE_(5, YY_("syntax error, unexpected %s, expecting %s or %s or %s or %s"));
#undef YYCASE_
    }

  /* Compute error message size.  Don't count the "%s"s, but reserve
     room for the terminator.  */
  yysize = yystrlen (yyformat) - 2 * yycount + 1;
  {
    int yyi;
    for (yyi = 0; yyi < yycount; ++yyi)
      {
        YYPTRDIFF_T yysize1
          = yysize + yytnamerr (YY_NULLPTR, yytname[yyarg[yyi]]);
        if (yysize <= yysize1 && yysize1 <= YYSTACK_ALLOC_MAXIMUM)
          yysize = yysize1;
        else
          return YYENOMEM;
      }
  }

  if (*yymsg_alloc < yysize)
    {
      *yymsg_alloc = 2 * yysize;
      if (! (yysize <= *yymsg_alloc
             && *yymsg_alloc <= YYSTACK_ALLOC_MAXIMUM))
        *yymsg_alloc = YYSTACK_ALLOC_MAXIMUM;
      return -1;
    }

  /* Avoid sprintf, as that infringes on the user's name space.
     Don't have undefined behavior even if the translation
     produced a string with the wrong number of "%s"s.  */
  {
    char *yyp = *yymsg;
    int yyi = 0;
    while ((*yyp = *yyformat) != '\0')
      if (*yyp == '%' && yyformat[1] == 's' && yyi < yycount)
        {
          yyp += yytnamerr (yyp, yytname[yyarg[yyi++]]);
          yyformat += 2;
        }
      else
        {
          ++yyp;
          ++yyformat;
        }
  }
  return 0;
}


/*-----------------------------------------------.
| Release the memory associated to this symbol.  |
`-----------------------------------------------*/

static void
yydestruct (const char *yymsg,
            yysymbol_kind_t yykind, YYSTYPE *yyvaluep, YYLTYPE *yylocationp)
{
  YY_USE (yyvaluep);
  YY_USE (yylocationp);
  if (!yymsg)
    yymsg = "Deleting";
  YY_SYMBOL_PRINT (yymsg, yykind, yyvaluep, yylocationp);

  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  YY_USE (yykind);
  YY_IGNORE_MAYBE_UNINITIALIZED_END
}


/* Lookahead token kind.  */
int yychar;

/* The semantic value of the lookahead symbol.  */
YYSTYPE yylval;
/* Location data for the lookahead symbol.  */
YYLTYPE yylloc
# if defined YYLTYPE_IS_TRIVIAL && YYLTYPE_IS_TRIVIAL
  = { 1, 1, 1, 1 }
# endif
;
/* Number of syntax errors so far.  */
int yynerrs;




/*----------.
| yyparse.  |
`----------*/

int
yyparse (void)
{
    yy_state_fast_t yystate = 0;
    /* Number of tokens to shift before error messages enabled.  */
    int yyerrstatus = 0;

    /* Refer to the stacks through separate pointers, to allow yyoverflow
       to reallocate them elsewhere.  */

    /* Their size.  */
    YYPTRDIFF_T yystacksize = YYINITDEPTH;

    /* The state stack: array, bottom, top.  */
    yy_state_t yyssa[YYINITDEPTH];
    yy_state_t *yyss = yyssa;
    yy_state_t *yyssp = yyss;

    /* The semantic value stack: array, bottom, top.  */
    YYSTYPE yyvsa[YYINITDEPTH];
    YYSTYPE *yyvs = yyvsa;
    YYSTYPE *yyvsp = yyvs;

    /* The location stack: array, bottom, top.  */
    YYLTYPE yylsa[YYINITDEPTH];
    YYLTYPE *yyls = yylsa;
    YYLTYPE *yylsp = yyls;

  int yyn;
  /* The return value of yyparse.  */
  int yyresult;
  /* Lookahead symbol kind.  */
  yysymbol_kind_t yytoken = YYSYMBOL_YYEMPTY;
  /* The variables used to return semantic value and location from the
     action routines.  */
  YYSTYPE yyval;
  YYLTYPE yyloc;

  /* The locations where the error started and ended.  */
  YYLTYPE yyerror_range[3];

  /* Buffer for error messages, and its allocated size.  */
  char yymsgbuf[128];
  char *yymsg = yymsgbuf;
  YYPTRDIFF_T yymsg_alloc = sizeof yymsgbuf;

#define YYPOPSTACK(N)   (yyvsp -= (N), yyssp -= (N), yylsp -= (N))

  /* The number of symbols on the RHS of the reduced rule.
     Keep to zero when no symbol should be popped.  */
  int yylen = 0;

  YYDPRINTF ((stderr, "Starting parse\n"));

  yychar = YYEMPTY; /* Cause a token to be read.  */

  yylsp[0] = yylloc;
  goto yysetstate;


/*------------------------------------------------------------.
| yynewstate -- push a new state, which is found in yystate.  |
`------------------------------------------------------------*/
yynewstate:
  /* In all cases, when you get here, the value and location stacks
     have just been pushed.  So pushing a state here evens the stacks.  */
  yyssp++;


/*--------------------------------------------------------------------.
| yysetstate -- set current state (the top of the stack) to yystate.  |
`--------------------------------------------------------------------*/
yysetstate:
  YYDPRINTF ((stderr, "Entering state %d\n", yystate));
  YY_ASSERT (0 <= yystate && yystate < YYNSTATES);
  YY_IGNORE_USELESS_CAST_BEGIN
  *yyssp = YY_CAST (yy_state_t, yystate);
  YY_IGNORE_USELESS_CAST_END
  YY_STACK_PRINT (yyss, yyssp);

  if (yyss + yystacksize - 1 <= yyssp)
#if !defined yyoverflow && !defined YYSTACK_RELOCATE
    YYNOMEM;
#else
    {
      /* Get the current used size of the three stacks, in elements.  */
      YYPTRDIFF_T yysize = yyssp - yyss + 1;

# if defined yyoverflow
      {
        /* Give user a chance to reallocate the stack.  Use copies of
           these so that the &'s don't force the real ones into
           memory.  */
        yy_state_t *yyss1 = yyss;
        YYSTYPE *yyvs1 = yyvs;
        YYLTYPE *yyls1 = yyls;

        /* Each stack pointer address is followed by the size of the
           data in use in that stack, in bytes.  This used to be a
           conditional around just the two extra args, but that might
           be undefined if yyoverflow is a macro.  */
        yyoverflow (YY_("memory exhausted"),
                    &yyss1, yysize * YYSIZEOF (*yyssp),
                    &yyvs1, yysize * YYSIZEOF (*yyvsp),
                    &yyls1, yysize * YYSIZEOF (*yylsp),
                    &yystacksize);
        yyss = yyss1;
        yyvs = yyvs1;
        yyls = yyls1;
      }
# else /* defined YYSTACK_RELOCATE */
      /* Extend the stack our own way.  */
      if (YYMAXDEPTH <= yystacksize)
        YYNOMEM;
      yystacksize *= 2;
      if (YYMAXDEPTH < yystacksize)
        yystacksize = YYMAXDEPTH;

      {
        yy_state_t *yyss1 = yyss;
        union yyalloc *yyptr =
          YY_CAST (union yyalloc *,
                   YYSTACK_ALLOC (YY_CAST (YYSIZE_T, YYSTACK_BYTES (yystacksize))));
        if (! yyptr)
          YYNOMEM;
        YYSTACK_RELOCATE (yyss_alloc, yyss);
        YYSTACK_RELOCATE (yyvs_alloc, yyvs);
        YYSTACK_RELOCATE (yyls_alloc, yyls);
#  undef YYSTACK_RELOCATE
        if (yyss1 != yyssa)
          YYSTACK_FREE (yyss1);
      }
# endif

      yyssp = yyss + yysize - 1;
      yyvsp = yyvs + yysize - 1;
      yylsp = yyls + yysize - 1;

      YY_IGNORE_USELESS_CAST_BEGIN
      YYDPRINTF ((stderr, "Stack size increased to %ld\n",
                  YY_CAST (long, yystacksize)));
      YY_IGNORE_USELESS_CAST_END

      if (yyss + yystacksize - 1 <= yyssp)
        YYABORT;
    }
#endif /* !defined yyoverflow && !defined YYSTACK_RELOCATE */


  if (yystate == YYFINAL)
    YYACCEPT;

  goto yybackup;


/*-----------.
| yybackup.  |
`-----------*/
yybackup:
  /* Do appropriate processing given the current state.  Read a
     lookahead token if we need one and don't already have one.  */

  /* First try to decide what to do without reference to lookahead token.  */
  yyn = yypact[yystate];
  if (yypact_value_is_default (yyn))
    goto yydefault;

  /* Not known => get a lookahead token if don't already have one.  */

  /* YYCHAR is either empty, or end-of-input, or a valid lookahead.  */
  if (yychar == YYEMPTY)
    {
      YYDPRINTF ((stderr, "Reading a token\n"));
      yychar = yylex ();
    }

  if (yychar <= YYEOF)
    {
      yychar = YYEOF;
      yytoken = YYSYMBOL_YYEOF;
      YYDPRINTF ((stderr, "Now at end of input.\n"));
    }
  else if (yychar == YYerror)
    {
      /* The scanner already issued an error message, process directly
         to error recovery.  But do not keep the error token as
         lookahead, it is too special and may lead us to an endless
         loop in error recovery. */
      yychar = YYUNDEF;
      yytoken = YYSYMBOL_YYerror;
      yyerror_range[1] = yylloc;
      goto yyerrlab1;
    }
  else
    {
      yytoken = YYTRANSLATE (yychar);
      YY_SYMBOL_PRINT ("Next token is", yytoken, &yylval, &yylloc);
    }

  /* If the proper action on seeing token YYTOKEN is to reduce or to
     detect an error, take that action.  */
  yyn += yytoken;
  if (yyn < 0 || YYLAST < yyn || yycheck[yyn] != yytoken)
    goto yydefault;
  yyn = yytable[yyn];
  if (yyn <= 0)
    {
      if (yytable_value_is_error (yyn))
        goto yyerrlab;
      yyn = -yyn;
      goto yyreduce;
    }

  /* Count tokens shifted since error; after three, turn off error
     status.  */
  if (yyerrstatus)
    yyerrstatus--;

  /* Shift the lookahead token.  */
  YY_SYMBOL_PRINT ("Shifting", yytoken, &yylval, &yylloc);
  yystate = yyn;
  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  *++yyvsp = yylval;
  YY_IGNORE_MAYBE_UNINITIALIZED_END
  *++yylsp = yylloc;

  /* Discard the shifted token.  */
  yychar = YYEMPTY;
  goto yynewstate;


/*-----------------------------------------------------------.
| yydefault -- do the default action for the current state.  |
`-----------------------------------------------------------*/
yydefault:
  yyn = yydefact[yystate];
  if (yyn == 0)
    goto yyerrlab;
  goto yyreduce;


/*-----------------------------.
| yyreduce -- do a reduction.  |
`-----------------------------*/
yyreduce:
  /* yyn is the number of a rule to reduce with.  */
  yylen = yyr2[yyn];

  /* If YYLEN is nonzero, implement the default value of the action:
     '$$ = $1'.

     Otherwise, the following line sets YYVAL to garbage.
     This behavior is undocumented and Bison
     users should not rely upon it.  Assigning to YYVAL
     unconditionally makes the parser a bit smaller, and it avoids a
     GCC warning that YYVAL may be used uninitialized.  */
  yyval = yyvsp[1-yylen];

  /* Default location. */
  YYLLOC_DEFAULT (yyloc, (yylsp - yylen), yylen);
  yyerror_range[1] = yyloc;
  YY_REDUCE_PRINT (yyn);
  switch (yyn)
    {
  case 2: /* program: prg_stmt  */
#line 77 "src/parser.y"
    { 
        (yyval.node) = node_make_programme((yyvsp[0].node));
        root = (yyval.node);
    }
#line 1629 "src/gen/parser.c"
    break;

  case 3: /* program: program prg_stmt  */
#line 82 "src/parser.y"
    {
        Node *pr = (yyvsp[-1].node);
        while(pr->as.programme.next)
        { pr = pr->as.programme.next; }
        pr->as.programme.next = node_make_programme((yyvsp[0].node));
        (yyval.node) = (yyvsp[-1].node);
    }
#line 1641 "src/gen/parser.c"
    break;

  case 4: /* prg_stmt: fn_def  */
#line 93 "src/parser.y"
    { (yyval.node) = node_make_prg_stmt(PST_FN_DEF, (yyvsp[0].node)); }
#line 1647 "src/gen/parser.c"
    break;

  case 5: /* prg_stmt: fn_decl  */
#line 95 "src/parser.y"
    { (yyval.node) = node_make_prg_stmt(PST_FN_DECL, (yyvsp[0].node)); }
#line 1653 "src/gen/parser.c"
    break;

  case 6: /* prg_stmt: type_def  */
#line 97 "src/parser.y"
    { (yyval.node) = node_make_prg_stmt(PST_TYPE_DEF, (yyvsp[0].node)); }
#line 1659 "src/gen/parser.c"
    break;

  case 7: /* fn_def: fn_decl block_with_end  */
#line 101 "src/parser.y"
    { (yyval.node) = node_make_fndef((yyvsp[-1].node), (yyvsp[0].node)); }
#line 1665 "src/gen/parser.c"
    break;

  case 8: /* fn_decl: type IDENT COLON LBRACKET param_list_opt RBRACKET  */
#line 106 "src/parser.y"
    {
        Node *id = node_make_ident((yyvsp[-4].str));
        (yyval.node) = node_make_fndecl((yyvsp[-5].node), id, (yyvsp[-1].node));
    }
#line 1674 "src/gen/parser.c"
    break;

  case 9: /* type_def: TYPEDEF IDENT COLON block_with_end  */
#line 114 "src/parser.y"
    {
        Node *id = node_make_ident((yyvsp[-2].str));
        (yyval.node) = node_make_type_def(id, (yyvsp[0].node));
    }
#line 1683 "src/gen/parser.c"
    break;

  case 10: /* param_list_opt: %empty  */
#line 122 "src/parser.y"
    { (yyval.node) = NULL; }
#line 1689 "src/gen/parser.c"
    break;

  case 11: /* param_list_opt: param_list  */
#line 124 "src/parser.y"
    { (yyval.node) = (yyvsp[0].node); }
#line 1695 "src/gen/parser.c"
    break;

  case 12: /* param_list: parametre  */
#line 129 "src/parser.y"
    { (yyval.node) = (yyvsp[0].node); }
#line 1701 "src/gen/parser.c"
    break;

  case 13: /* param_list: param_list VBAR parametre  */
#line 131 "src/parser.y"
    {
        Node *list = (yyvsp[-2].node);
        while(list->as.parametre.next)
        { list = list->as.parametre.next; }
        list->as.parametre.next = (yyvsp[0].node);
        (yyval.node) = (yyvsp[-2].node);
    }
#line 1713 "src/gen/parser.c"
    break;

  case 14: /* parametre: type IDENT  */
#line 142 "src/parser.y"
    {
        Node *id = node_make_ident((yyvsp[0].str));
        (yyval.node) = node_make_parametre((yyvsp[-1].node), id);
    }
#line 1722 "src/gen/parser.c"
    break;

  case 15: /* parametre: ELLIPSIS  */
#line 147 "src/parser.y"
    {
        (yyval.node) = node_make_parametre_vaarg();
    }
#line 1730 "src/gen/parser.c"
    break;

  case 16: /* block_with_continue: block_line_list BLOCK_CONTINUE  */
#line 154 "src/parser.y"
    { (yyval.node) = (yyvsp[-1].node); }
#line 1736 "src/gen/parser.c"
    break;

  case 17: /* block_with_end: block_line_list BLOCK_END  */
#line 159 "src/parser.y"
    { (yyval.node) = (yyvsp[-1].node); }
#line 1742 "src/gen/parser.c"
    break;

  case 18: /* block_line_list: block_line  */
#line 164 "src/parser.y"
    { (yyval.node) = (yyvsp[0].node); }
#line 1748 "src/gen/parser.c"
    break;

  case 19: /* block_line_list: block_line_list block_line  */
#line 166 "src/parser.y"
    {
        Node *list = (yyvsp[-1].node);
        while(list->as.block.next)
        { list = list->as.block.next; }
        list->as.block.next = (yyvsp[0].node);
        (yyval.node) = (yyvsp[-1].node);
    }
#line 1760 "src/gen/parser.c"
    break;

  case 20: /* block_line: indent_seq stmt  */
#line 177 "src/parser.y"
    { (yyval.node) = node_make_block((yyvsp[0].node)); }
#line 1766 "src/gen/parser.c"
    break;

  case 21: /* indent_seq: VBAR  */
#line 182 "src/parser.y"
    { (yyval.vbars) = 1; }
#line 1772 "src/gen/parser.c"
    break;

  case 22: /* indent_seq: VBAR indent_seq  */
#line 184 "src/parser.y"
    { (yyval.vbars) = 1 + (yyvsp[0].vbars); }
#line 1778 "src/gen/parser.c"
    break;

  case 23: /* stmt: %empty  */
#line 189 "src/parser.y"
    { (yyval.node) = NULL; }
#line 1784 "src/gen/parser.c"
    break;

  case 24: /* stmt: expression  */
#line 191 "src/parser.y"
    { (yyval.node) = node_make_stmt(ST_EXPR, (yyvsp[0].node)); }
#line 1790 "src/gen/parser.c"
    break;

  case 25: /* stmt: var_decl  */
#line 193 "src/parser.y"
    { (yyval.node) = node_make_stmt(ST_VAR_DECL, (yyvsp[0].node)); }
#line 1796 "src/gen/parser.c"
    break;

  case 26: /* stmt: ret_stmt  */
#line 195 "src/parser.y"
    { (yyval.node) = node_make_stmt(ST_RET, (yyvsp[0].node)); }
#line 1802 "src/gen/parser.c"
    break;

  case 27: /* stmt: cond_stmt  */
#line 197 "src/parser.y"
    { (yyval.node) = node_make_stmt(ST_COND, (yyvsp[0].node)); }
#line 1808 "src/gen/parser.c"
    break;

  case 28: /* stmt: loop_stmt  */
#line 199 "src/parser.y"
    { (yyval.node) = node_make_stmt(ST_LOOP, (yyvsp[0].node)); }
#line 1814 "src/gen/parser.c"
    break;

  case 29: /* stmt: BREAK  */
#line 201 "src/parser.y"
    { (yyval.node) = node_make_stmt(ST_BREAK, NULL); }
#line 1820 "src/gen/parser.c"
    break;

  case 30: /* loop_stmt: LOOP block_with_end  */
#line 206 "src/parser.y"
    { (yyval.node) = node_make_loop((yyvsp[0].node)); }
#line 1826 "src/gen/parser.c"
    break;

  case 31: /* cond_stmt: cond_if  */
#line 211 "src/parser.y"
    { (yyval.node) = node_make_cond((yyvsp[0].node), NULL); }
#line 1832 "src/gen/parser.c"
    break;

  case 32: /* cond_stmt: cond_if_else cond_else  */
#line 213 "src/parser.y"
    { (yyval.node) = node_make_cond((yyvsp[-1].node), (yyvsp[0].node)); }
#line 1838 "src/gen/parser.c"
    break;

  case 33: /* cond_if: IF LBRACKET expression RBRACKET block_with_end  */
#line 218 "src/parser.y"
    { (yyval.node) = node_make_if((yyvsp[-2].node), (yyvsp[0].node)); }
#line 1844 "src/gen/parser.c"
    break;

  case 34: /* cond_if_else: IF LBRACKET expression RBRACKET block_with_continue  */
#line 223 "src/parser.y"
    { (yyval.node) = node_make_if((yyvsp[-2].node), (yyvsp[0].node)); }
#line 1850 "src/gen/parser.c"
    break;

  case 35: /* cond_else: indent_seq ELSE block_with_end  */
#line 228 "src/parser.y"
    { (yyval.node) = node_make_else((yyvsp[0].node)); }
#line 1856 "src/gen/parser.c"
    break;

  case 36: /* var_decl: type IDENT EQUAL expression  */
#line 234 "src/parser.y"
    {
        Node *id = node_make_ident((yyvsp[-2].str));
        (yyval.node) = node_make_var_decl((yyvsp[-3].node), id, (yyvsp[0].node));
    }
#line 1865 "src/gen/parser.c"
    break;

  case 37: /* var_decl: type IDENT  */
#line 239 "src/parser.y"
    {
        Node *id = node_make_ident((yyvsp[0].str));
        (yyval.node) = node_make_var_decl((yyvsp[-1].node), id, NULL);
    }
#line 1874 "src/gen/parser.c"
    break;

  case 38: /* ret_stmt: RET LBRACKET expression RBRACKET  */
#line 247 "src/parser.y"
    {
        (yyval.node) = node_make_ret((yyvsp[-1].node));
    }
#line 1882 "src/gen/parser.c"
    break;

  case 39: /* ret_stmt: RET LBRACKET RBRACKET  */
#line 251 "src/parser.y"
    { (yyval.node) = node_make_ret(NULL); }
#line 1888 "src/gen/parser.c"
    break;

  case 40: /* expression: LPAREN expression RPAREN  */
#line 256 "src/parser.y"
    { (yyval.node) = (yyvsp[-1].node); }
#line 1894 "src/gen/parser.c"
    break;

  case 41: /* expression: expression EQUAL expression  */
#line 258 "src/parser.y"
    {
        Node *e = node_make_bin_op(BOT_ASSIGN, (yyvsp[-2].node), (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_BIN_OP, e);
    }
#line 1903 "src/gen/parser.c"
    break;

  case 42: /* expression: expression PLUS expression  */
#line 263 "src/parser.y"
    {
        Node *e = node_make_bin_op(BOT_PLUS, (yyvsp[-2].node), (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_BIN_OP, e);
    }
#line 1912 "src/gen/parser.c"
    break;

  case 43: /* expression: expression MINUS expression  */
#line 268 "src/parser.y"
    {
        Node *e = node_make_bin_op(BOT_MINUS, (yyvsp[-2].node), (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_BIN_OP, e);
    }
#line 1921 "src/gen/parser.c"
    break;

  case 44: /* expression: expression STAR expression  */
#line 273 "src/parser.y"
    {
        Node *e = node_make_bin_op(BOT_MULT, (yyvsp[-2].node), (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_BIN_OP, e);
    }
#line 1930 "src/gen/parser.c"
    break;

  case 45: /* expression: expression SLASH expression  */
#line 278 "src/parser.y"
    {
        Node *e = node_make_bin_op(BOT_DIV, (yyvsp[-2].node), (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_BIN_OP, e);
    }
#line 1939 "src/gen/parser.c"
    break;

  case 46: /* expression: expression MODULA expression  */
#line 283 "src/parser.y"
    {
        Node *e = node_make_bin_op(BOT_MOD, (yyvsp[-2].node), (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_BIN_OP, e);
    }
#line 1948 "src/gen/parser.c"
    break;

  case 47: /* expression: expression DOUBLE_EQUAL expression  */
#line 288 "src/parser.y"
    {
        Node *e = node_make_bin_op(BOT_EQUAL, (yyvsp[-2].node), (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_BIN_OP, e);
    }
#line 1957 "src/gen/parser.c"
    break;

  case 48: /* expression: expression NOT_EQUAL expression  */
#line 293 "src/parser.y"
    {
        Node *e = node_make_bin_op(BOT_NEQ, (yyvsp[-2].node), (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_BIN_OP, e);
    }
#line 1966 "src/gen/parser.c"
    break;

  case 49: /* expression: expression LESS expression  */
#line 298 "src/parser.y"
    {
        Node *e = node_make_bin_op(BOT_LESS, (yyvsp[-2].node), (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_BIN_OP, e);
    }
#line 1975 "src/gen/parser.c"
    break;

  case 50: /* expression: expression LEQ expression  */
#line 303 "src/parser.y"
    {
        Node *e = node_make_bin_op(BOT_LEQ, (yyvsp[-2].node), (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_BIN_OP, e);
    }
#line 1984 "src/gen/parser.c"
    break;

  case 51: /* expression: expression GREAT expression  */
#line 308 "src/parser.y"
    {
        Node *e = node_make_bin_op(BOT_GREAT, (yyvsp[-2].node), (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_BIN_OP, e);
    }
#line 1993 "src/gen/parser.c"
    break;

  case 52: /* expression: expression GEQ expression  */
#line 313 "src/parser.y"
    {
        Node *e = node_make_bin_op(BOT_GEQ, (yyvsp[-2].node), (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_BIN_OP, e);
    }
#line 2002 "src/gen/parser.c"
    break;

  case 53: /* expression: PTR expression  */
#line 318 "src/parser.y"
    {
        Node *e = node_make_uny_op(UOT_DEREF, (yyvsp[0].node));
        (yyval.node) = node_make_expr(ET_UNY_OP, e);
    }
#line 2011 "src/gen/parser.c"
    break;

  case 54: /* expression: function_call  */
#line 323 "src/parser.y"
    { (yyval.node) = node_make_expr(ET_FN_CALL, (yyvsp[0].node)); }
#line 2017 "src/gen/parser.c"
    break;

  case 55: /* expression: STR_LITERAL  */
#line 325 "src/parser.y"
    {
        Node *e = node_make_str_lit((yyvsp[0].str));
        (yyval.node) = node_make_expr(ET_STR_LIT, e);
    }
#line 2026 "src/gen/parser.c"
    break;

  case 56: /* expression: CHR_LITERAL  */
#line 330 "src/parser.y"
    {
        Node *e = node_make_chr_lit((yyvsp[0].str));
        (yyval.node) = node_make_expr(ET_CHR_LIT, e);
    }
#line 2035 "src/gen/parser.c"
    break;

  case 57: /* expression: NUM_LITERAL  */
#line 335 "src/parser.y"
    {
        Node *e = node_make_num_lit((yyvsp[0].str));
        (yyval.node) = node_make_expr(ET_NUM_LIT, e);
    }
#line 2044 "src/gen/parser.c"
    break;

  case 58: /* expression: IDENT  */
#line 340 "src/parser.y"
    {
        Node *e = node_make_ident((yyvsp[0].str));
        (yyval.node) = node_make_expr(ET_IDENT, e);
    }
#line 2053 "src/gen/parser.c"
    break;

  case 59: /* expression: B1_TRUE  */
#line 345 "src/parser.y"
    {
        Node *e = node_make_bool_lit(BL_TRUE);
        (yyval.node) = node_make_expr(ET_BOOL_LIT, e);
    }
#line 2062 "src/gen/parser.c"
    break;

  case 60: /* expression: B1_FALSE  */
#line 350 "src/parser.y"
    {
        Node *e = node_make_bool_lit(BL_FALSE);
        (yyval.node) = node_make_expr(ET_BOOL_LIT, e);
    }
#line 2071 "src/gen/parser.c"
    break;

  case 61: /* function_call: LPAREN IDENT RPAREN LBRACKET arg_list_opt RBRACKET  */
#line 358 "src/parser.y"
    {
        Node *ident = node_make_ident((yyvsp[-4].str));
        (yyval.node) = node_make_fncall(ident, (yyvsp[-1].node));
    }
#line 2080 "src/gen/parser.c"
    break;

  case 62: /* arg_list_opt: %empty  */
#line 366 "src/parser.y"
    { (yyval.node) = NULL; }
#line 2086 "src/gen/parser.c"
    break;

  case 63: /* arg_list_opt: arg_list  */
#line 368 "src/parser.y"
    { (yyval.node) = (yyvsp[0].node); }
#line 2092 "src/gen/parser.c"
    break;

  case 64: /* arg_list: expression  */
#line 373 "src/parser.y"
    { (yyval.node) = node_make_argument((yyvsp[0].node)); }
#line 2098 "src/gen/parser.c"
    break;

  case 65: /* arg_list: arg_list VBAR expression  */
#line 375 "src/parser.y"
    {
        Node *list = (yyvsp[-2].node);
        while(list->as.arguments.next)
        { list = list->as.arguments.next; }
        list->as.arguments.next = node_make_argument((yyvsp[0].node));
        (yyval.node) = (yyvsp[-2].node);
    }
#line 2110 "src/gen/parser.c"
    break;

  case 66: /* type: TYPE  */
#line 386 "src/parser.y"
    { (yyval.node) = node_make_type((yyvsp[0].str)); }
#line 2116 "src/gen/parser.c"
    break;

  case 67: /* type: IDENT  */
#line 388 "src/parser.y"
    { (yyval.node) = node_make_user_type(node_make_ident((yyvsp[0].str))); }
#line 2122 "src/gen/parser.c"
    break;

  case 68: /* type: PTR type  */
#line 390 "src/parser.y"
    { (yyval.node) = node_make_type_ptr((yyvsp[0].node)); }
#line 2128 "src/gen/parser.c"
    break;


#line 2132 "src/gen/parser.c"

      default: break;
    }
  /* User semantic actions sometimes alter yychar, and that requires
     that yytoken be updated with the new translation.  We take the
     approach of translating immediately before every use of yytoken.
     One alternative is translating here after every semantic action,
     but that translation would be missed if the semantic action invokes
     YYABORT, YYACCEPT, or YYERROR immediately after altering yychar or
     if it invokes YYBACKUP.  In the case of YYABORT or YYACCEPT, an
     incorrect destructor might then be invoked immediately.  In the
     case of YYERROR or YYBACKUP, subsequent parser actions might lead
     to an incorrect destructor call or verbose syntax error message
     before the lookahead is translated.  */
  YY_SYMBOL_PRINT ("-> $$ =", YY_CAST (yysymbol_kind_t, yyr1[yyn]), &yyval, &yyloc);

  YYPOPSTACK (yylen);
  yylen = 0;

  *++yyvsp = yyval;
  *++yylsp = yyloc;

  /* Now 'shift' the result of the reduction.  Determine what state
     that goes to, based on the state we popped back to and the rule
     number reduced by.  */
  {
    const int yylhs = yyr1[yyn] - YYNTOKENS;
    const int yyi = yypgoto[yylhs] + *yyssp;
    yystate = (0 <= yyi && yyi <= YYLAST && yycheck[yyi] == *yyssp
               ? yytable[yyi]
               : yydefgoto[yylhs]);
  }

  goto yynewstate;


/*--------------------------------------.
| yyerrlab -- here on detecting error.  |
`--------------------------------------*/
yyerrlab:
  /* Make sure we have latest lookahead translation.  See comments at
     user semantic actions for why this is necessary.  */
  yytoken = yychar == YYEMPTY ? YYSYMBOL_YYEMPTY : YYTRANSLATE (yychar);
  /* If not already recovering from an error, report this error.  */
  if (!yyerrstatus)
    {
      ++yynerrs;
      {
        yypcontext_t yyctx
          = {yyssp, yytoken, &yylloc};
        char const *yymsgp = YY_("syntax error");
        int yysyntax_error_status;
        yysyntax_error_status = yysyntax_error (&yymsg_alloc, &yymsg, &yyctx);
        if (yysyntax_error_status == 0)
          yymsgp = yymsg;
        else if (yysyntax_error_status == -1)
          {
            if (yymsg != yymsgbuf)
              YYSTACK_FREE (yymsg);
            yymsg = YY_CAST (char *,
                             YYSTACK_ALLOC (YY_CAST (YYSIZE_T, yymsg_alloc)));
            if (yymsg)
              {
                yysyntax_error_status
                  = yysyntax_error (&yymsg_alloc, &yymsg, &yyctx);
                yymsgp = yymsg;
              }
            else
              {
                yymsg = yymsgbuf;
                yymsg_alloc = sizeof yymsgbuf;
                yysyntax_error_status = YYENOMEM;
              }
          }
        yyerror (yymsgp);
        if (yysyntax_error_status == YYENOMEM)
          YYNOMEM;
      }
    }

  yyerror_range[1] = yylloc;
  if (yyerrstatus == 3)
    {
      /* If just tried and failed to reuse lookahead token after an
         error, discard it.  */

      if (yychar <= YYEOF)
        {
          /* Return failure if at end of input.  */
          if (yychar == YYEOF)
            YYABORT;
        }
      else
        {
          yydestruct ("Error: discarding",
                      yytoken, &yylval, &yylloc);
          yychar = YYEMPTY;
        }
    }

  /* Else will try to reuse lookahead token after shifting the error
     token.  */
  goto yyerrlab1;


/*---------------------------------------------------.
| yyerrorlab -- error raised explicitly by YYERROR.  |
`---------------------------------------------------*/
yyerrorlab:
  /* Pacify compilers when the user code never invokes YYERROR and the
     label yyerrorlab therefore never appears in user code.  */
  if (0)
    YYERROR;
  ++yynerrs;

  /* Do not reclaim the symbols of the rule whose action triggered
     this YYERROR.  */
  YYPOPSTACK (yylen);
  yylen = 0;
  YY_STACK_PRINT (yyss, yyssp);
  yystate = *yyssp;
  goto yyerrlab1;


/*-------------------------------------------------------------.
| yyerrlab1 -- common code for both syntax error and YYERROR.  |
`-------------------------------------------------------------*/
yyerrlab1:
  yyerrstatus = 3;      /* Each real token shifted decrements this.  */

  /* Pop stack until we find a state that shifts the error token.  */
  for (;;)
    {
      yyn = yypact[yystate];
      if (!yypact_value_is_default (yyn))
        {
          yyn += YYSYMBOL_YYerror;
          if (0 <= yyn && yyn <= YYLAST && yycheck[yyn] == YYSYMBOL_YYerror)
            {
              yyn = yytable[yyn];
              if (0 < yyn)
                break;
            }
        }

      /* Pop the current state because it cannot handle the error token.  */
      if (yyssp == yyss)
        YYABORT;

      yyerror_range[1] = *yylsp;
      yydestruct ("Error: popping",
                  YY_ACCESSING_SYMBOL (yystate), yyvsp, yylsp);
      YYPOPSTACK (1);
      yystate = *yyssp;
      YY_STACK_PRINT (yyss, yyssp);
    }

  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  *++yyvsp = yylval;
  YY_IGNORE_MAYBE_UNINITIALIZED_END

  yyerror_range[2] = yylloc;
  ++yylsp;
  YYLLOC_DEFAULT (*yylsp, yyerror_range, 2);

  /* Shift the error token.  */
  YY_SYMBOL_PRINT ("Shifting", YY_ACCESSING_SYMBOL (yyn), yyvsp, yylsp);

  yystate = yyn;
  goto yynewstate;


/*-------------------------------------.
| yyacceptlab -- YYACCEPT comes here.  |
`-------------------------------------*/
yyacceptlab:
  yyresult = 0;
  goto yyreturnlab;


/*-----------------------------------.
| yyabortlab -- YYABORT comes here.  |
`-----------------------------------*/
yyabortlab:
  yyresult = 1;
  goto yyreturnlab;


/*-----------------------------------------------------------.
| yyexhaustedlab -- YYNOMEM (memory exhaustion) comes here.  |
`-----------------------------------------------------------*/
yyexhaustedlab:
  yyerror (YY_("memory exhausted"));
  yyresult = 2;
  goto yyreturnlab;


/*----------------------------------------------------------.
| yyreturnlab -- parsing is finished, clean up and return.  |
`----------------------------------------------------------*/
yyreturnlab:
  if (yychar != YYEMPTY)
    {
      /* Make sure we have latest lookahead translation.  See comments at
         user semantic actions for why this is necessary.  */
      yytoken = YYTRANSLATE (yychar);
      yydestruct ("Cleanup: discarding lookahead",
                  yytoken, &yylval, &yylloc);
    }
  /* Do not reclaim the symbols of the rule whose action triggered
     this YYABORT or YYACCEPT.  */
  YYPOPSTACK (yylen);
  YY_STACK_PRINT (yyss, yyssp);
  while (yyssp != yyss)
    {
      yydestruct ("Cleanup: popping",
                  YY_ACCESSING_SYMBOL (+*yyssp), yyvsp, yylsp);
      YYPOPSTACK (1);
    }
#ifndef yyoverflow
  if (yyss != yyssa)
    YYSTACK_FREE (yyss);
#endif
  if (yymsg != yymsgbuf)
    YYSTACK_FREE (yymsg);
  return yyresult;
}

#line 392 "src/parser.y"



void yyerror(const char *msg)          /* ← прежняя сигнатура */
{
    extern char *yytext;               /* объявление из flex */
    /* yylloc ‒ глобальный, объявлен Bison-ом */
    fprintf(stderr,
            "syntax error: %s at %d:%d near '%s'\n",
            msg,
            yylloc.first_line, yylloc.first_column,
            yytext);
}

