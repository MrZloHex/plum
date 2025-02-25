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

CFLAGS_BASE  = -Wall -Wextra -std=c2x -Wstrict-aliasing
CFLAGS_BASE += -Wno-old-style-declaration -Wno-unused-function
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

LDFLAGS  = $(shell llvm-config --ldflags) -lLLVM-18 -lfl

TARGET   = plc

SRC 	 = src
INC      = inc
OBJ 	 = obj
BIN 	 = bin
LIB 	 =

LEXES    = $(shell find $(SRC) -type f -name '*.l')
PARSERS  = $(shell find $(SRC) -type f -name '*.y')
SOURCES  = $(patsubst $(SRC)/%.y, $(SRC)/%.c, $(PARSERS))
SOURCES += $(patsubst $(SRC)/%.l, $(SRC)/%.c, $(LEXES))
SOURCES += $(shell find $(SRC) -type f -name '*.c')
OBJECTS  = $(patsubst $(SRC)/%.c, $(OBJ)/%.o, $(SOURCES))

ifneq ($(strip $(LIB)),)
LIBRARY  = $(wildcard $(LIB)/*.c)
OBJECTS += $(patsubst $(LIB)/%.c, $(OBJ)/%.o, $(LIBRARY))
endif

all: $(BIN)/$(TARGET)

$(BIN)/$(TARGET): $(OBJECTS)
	@mkdir -p $(BIN)
	@echo "  CCLD     $(patsubst $(BIN)/%,%,$@)"
	$(Q) $(CC) -o $(BIN)/$(TARGET) $^ $(LDFLAGS)

$(SRC)/%.c: $(SRC)/%.y
	@echo "  YC       $(patsubst $(SRC)/%,%,$@)"
	$(Q) $(YACC) $< -o $@ --header=$(patsubst $(SRC)/%.c,$(INC)/%.h, $@)

$(SRC)/%.c: $(SRC)/%.l
	@echo "  LX       $(patsubst $(SRC)/%,%,$@)"
	$(Q) $(LEX) -o $@ $<

$(OBJ)/%.o: $(SRC)/%.c
	@mkdir -p $(@D)
	@echo "  CC       $(patsubst $(OBJ)/%,%,$@)"
	$(Q) $(CC) -o $@ -c $< $(CFLAGS)

$(OBJ)/%.o: $(GEN)/%.c
	@mkdir -p $(@D)
	@echo "  CC       $(patsubst $(OBJ)/%,%,$@)"
	$(Q) $(CC) -o $@ -c $< $(CFLAGS)

ifneq ($(strip $(LIB)),)
$(OBJ)/%.o: $(LIB)/%.c
    @mkdir -p $(@D)
    @echo "  CC       $(patsubst $(OBJ)/%,%,$@)"
    $(Q) $(CC) -o $@ -c $< $(CFLAGS)
endif

clean:
	$(Q) rm -rf $(OBJ) $(BIN)

debug:
	$(MAKE) BUILD=debug all

release:
	$(MAKE) BUILD=release all

.PHONY: all clean debug release

-include $(OBJECTS:.o=.d)
