
CC      = gcc
CFLAGS  = -std=c11 -Wall -Wextra -g

SRCS = main.c lexer.c ast.c parser.c
OBJS = $(SRCS:.c=.o)

plumc: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

clean:
	rm -f $(OBJS) plumc
