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
#
#   Description:
#       plc is written in PLUM and compiles itself. `make` builds it from
#       the checked-in seed. bootstrap/ holds the frozen C compiler that
#       produced the first seed; it is only needed to verify the seed or
#       to start over on a new target.
#
#   Warning    : This Makefile is so cool it might make your terminal shine!
# ==============================================================================

V ?= 0
ifeq ($(V),0)
	Q = @
else
	Q =
endif

BUILD ?= debug

BIN        = bin
OBJ        = obj
PLC        = $(BIN)/plc
BOOT       = $(BIN)/plc-bootstrap

LLVM_LIBS  = $(shell llvm-config --ldflags --libs core analysis target --system-libs)

# --- plc, written in PLUM -----------------------------------------------
PLUM_SRC   = $(wildcard src/*.pl lib/*.pl extern/*.pl)
SEED       = seed/plc.ll

# --- the frozen C bootstrap compiler ------------------------------------
CC         = gcc
C_SRC_DIR  = bootstrap/src
C_INC_DIR  = bootstrap/inc

CFLAGS_BASE  = -Wall -Wextra -std=c2x -Wstrict-aliasing
CFLAGS_BASE += -Wno-old-style-declaration -Wno-unused-function
CFLAGS_BASE += -ggdb -MMD -MP
CFLAGS_BASE += -I$(C_INC_DIR)
CFLAGS_BASE += $(shell llvm-config --cflags)

ifeq ($(BUILD),debug)
	CFLAGS = $(CFLAGS_BASE) -O0 -g
else ifeq ($(BUILD),release)
	CFLAGS = $(CFLAGS_BASE) -O2 -Werror
else
	$(error Unknown build mode: $(BUILD). Use BUILD=debug or BUILD=release)
endif

C_LDFLAGS = $(shell llvm-config --ldflags --libs core --system-libs) -lfl
C_SOURCES = $(shell find $(C_SRC_DIR) -type f -name '*.c')
C_OBJECTS = $(patsubst $(C_SRC_DIR)/%.c, $(OBJ)/%.o, $(C_SOURCES))

.PHONY: all plc bootstrap selfhost test typecheck seed-verify seed-refresh clean help

all: plc

help:
	@echo "  make            build plc from the seed (default)"
	@echo "  make bootstrap  build the frozen C compiler -> $(BOOT)"
	@echo "  make selfhost   stage 1 -> 2 -> 3, and check the fixed point"
	@echo "  make test       run the test suite"
	@echo "  make typecheck  run the programs that must be rejected"
	@echo "  make seed-verify   check the seed against the C compiler"
	@echo "  make seed-refresh  advance the seed (see BOOTSTRAP.md)"
	@echo "  make clean"

# --- plc ------------------------------------------------------------------

plc: $(PLC)

$(PLC): $(SEED) $(PLUM_SRC) | $(BIN) $(OBJ)
	@echo "  SEED     $(SEED)"
	$(Q) llvm-as $(SEED) -o $(OBJ)/seed.bc
	$(Q) clang $(OBJ)/seed.bc -o $(BIN)/plc-seed $(LLVM_LIBS) 2>/dev/null
	@echo "  PLC      src/main.pl"
	$(Q) $(BIN)/plc-seed src/main.pl -o $(OBJ)/plc.ll --emit=IR
	$(Q) llvm-as $(OBJ)/plc.ll -o $(OBJ)/plc.bc
	$(Q) clang $(OBJ)/plc.bc -o $@ $(LLVM_LIBS) 2>/dev/null
	@echo "  CCLD     $@"

# --- the C bootstrap compiler --------------------------------------------

bootstrap: $(BOOT)

$(BOOT): $(C_OBJECTS) | $(BIN)
	@echo "  CCLD     $(patsubst $(BIN)/%,%,$@)"
	$(Q) $(CC) -o $@ $^ $(C_LDFLAGS)

$(OBJ)/%.o: $(C_SRC_DIR)/%.c | $(OBJ)
	@echo "  CC       $(patsubst $(OBJ)/%,%,$@)"
	$(Q) $(CC) -o $@ -c $< $(CFLAGS)

$(BIN) $(OBJ):
	@mkdir -p $@

# --- checks ---------------------------------------------------------------

selfhost: $(BOOT)
	$(Q) ./scripts/bootstrap.sh

seed-verify: $(BOOT)
	$(Q) ./scripts/seed-verify.sh

seed-refresh:
	$(Q) ./scripts/refresh-seed.sh

test: $(PLC)
	$(Q) cd test && ./run.sh

typecheck: $(PLC)
	$(Q) ./test/typecheck/run.sh

clean:
	$(Q) rm -rf $(OBJ) $(BIN) stage*.ll stage*.bc fromseed*.ll fromseed*.bc seed.bc

-include $(C_OBJECTS:.o=.d)
