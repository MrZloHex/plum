# ==============================================================================
#
#		░▒▓███████▓▒░░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓██████████████▓▒░
#		░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
#		░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
#		░▒▓███████▓▒░░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
#		░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
#		░▒▓█▓▒░      ░▒▓█▓▒░     ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
#		░▒▓█▓▒░      ░▒▓████████▓▒░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
#
#                           ░▒▓█ _PLC_█▓▒░
#
#   Makefile
#   Author     : MrZloHex
#   Date       : 2025-02-23
#   Version    : 1.0
#
#   Description:
#       This Makefile compiles and links the tma project sources.
#       It searches recursively under the "src" directory for source files,
#       compiles them into "obj", and links the final executable in "bin".
#
#   Warning    : This Makefile is so cool it might make your terminal shine!
# ==============================================================================
#
# Verbosity: Set V=1 for verbose output (full commands) or leave it unset for cool, quiet messages.
V ?= 0
ifeq ($(V),0)
	Q = @
else
	Q =
endif

BUILD ?= debug


CC      	 = gcc
YACC		 = bison
LEX 	 	 = flex

TARGET   = plc

SRC 	 = src
GEN      = $(SRC)/gen
INC      = inc
OBJ 	 = obj
BIN 	 = bin
LIB 	 =


LEXFLAGS     = --noyywrap -o $(GEN)/$*.c
YACCFLAGS	 = -Wall -Wcounterexamples -d -o $(GEN)/$*.c --header=$(INC)/$*.h

CFLAGS_BASE  = -Wall -Wextra -std=c2x -Wstrict-aliasing
CFLAGS_BASE += -Wno-old-style-declaration -Wno-unused-function
CFLAGS_BASE += -ggdb
CFLAGS_BASE += -MMD -MP
CFLAGS_BASE += -Iinc -Ilib
CFLAGS_BASE += $(shell llvm-config --cflags)

ifeq ($(BUILD),debug)
	CFLAGS  = $(CFLAGS_BASE)
	CFLAGS += -O0 -g
else ifeq ($(BUILD),release)
	CFLAGS  = $(CFLAGS_BASE)
	CFLAGS += -O2 -Werror
else
	$(error Unknown build mode: $(BUILD). Use BUILD=debug or BUILD=release)
endif

LDFLAGS  = $(shell llvm-config --ldflags --libs core irreader native --system-libs) -lfl

LEXES    = $(shell find $(SRC) -type f -name '*.l')
PARSERS  = $(shell find $(SRC) -type f -name '*.y')
GEN_SRC  = $(patsubst $(SRC)/%.y, $(GEN)/%.c, $(PARSERS))
GEN_SRC += $(patsubst $(SRC)/%.l, $(GEN)/%.c, $(LEXES))
SOURCES  = $(GEN_SRC)
SOURCES += $(shell find $(SRC) -type f -name '*.c')
OBJECTS  = $(patsubst $(SRC)/%.c, $(OBJ)/%.o, $(SOURCES))

ifneq ($(strip $(LIB)),)
LIBRARY  = $(wildcard $(LIB)/*.c)
OBJECTS += $(patsubst $(LIB)/%.c, $(OBJ)/%.o, $(LIBRARY))
endif

all: $(BIN)/$(TARGET)

$(BIN)/$(TARGET): $(OBJECTS) | $(BIN)
	@echo "  CCLD     $(patsubst $(BIN)/%,%,$@)"
	$(Q) $(CC) -o $(BIN)/$(TARGET) $^ $(LDFLAGS)

$(BIN):
	@mkdir -p $@

$(GEN)/%.c $(INC)/%.h: $(SRC)/%.y | $(GEN)
	@echo "  YC       $(patsubst $(SRC)/%,%,$@)"
	$(Q) $(YACC) $< $(YACCFLAGS)

$(GEN)/%.c: $(SRC)/%.l | $(GEN)
	@echo "  LX       $(patsubst $(SRC)/%,%,$@)"
	$(Q) $(LEX) $(LEXFLAGS) $<

$(GEN):
	@mkdir -p $@

$(OBJ)/%.o: $(SRC)/%.c | $(OBJ)
	@echo "  CC       $(patsubst $(OBJ)/%,%,$@)"
	$(Q) $(CC) -o $@ -c $< $(CFLAGS)

$(OBJ)/%.o: $(GEN)/%.c | $(OBJ)
	@echo "  CC       $(patsubst $(OBJ)/%,%,$@)"
	$(Q) $(CC) -o $@ -c $< $(CFLAGS)

$(OBJ):
	@mkdir -p $@/gen

ifneq ($(strip $(LIB)),)
$(OBJ)/%.o: $(LIB)/%.c
    @mkdir -p $(@D)
    @echo "  CC       $(patsubst $(OBJ)/%,%,$@)"
    $(Q) $(CC) -o $@ -c $< $(CFLAGS)
endif

clean:
	$(Q) rm -rf $(OBJ) $(BIN) $(GEN)

debug release:
	$(MAKE) BUILD=$@ V=$(V)

.PHONY: all clean debug release
.SECONDARY: $(GEN_SRC)
.DELETE_ON_ERROR:

-include $(OBJECTS:.o=.d)
