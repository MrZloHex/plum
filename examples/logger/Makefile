# A temperature logger in PLUM: sample, summarise, save to flash, load, check.
#
#   make          build ./logger, optimised
#   make run      run it
#   make check    run it and compare with expected.out
#   make arm      compile it for a Cortex-M0+ as well: its STATIC_ASSERTs
#                 are checked against that target's layout too

PLC ?= ../../bin/plc
SRC  = main.pl sensor.pl bus.pl flash.pl record.pl stats.pl ../option.pl ../result.pl

logger: $(SRC) $(PLC)
	$(PLC) --emit=OBJ -O2 main.pl -o logger.o
	clang logger.o -o $@

run: logger
	./logger

check: logger
	./logger | diff - expected.out && echo "output as expected"

arm: $(SRC) $(PLC)
	$(PLC) --emit=OBJ -O2 --target=thumbv6m-unknown-none-eabi --cpu=cortex-m0plus main.pl -o logger-arm.o
	@echo "compiled for Cortex-M0+: logger-arm.o"

clean:
	rm -f logger logger.o logger-arm.o

.PHONY: run check arm clean
