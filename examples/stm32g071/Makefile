# A PLUM program on a NUCLEO-G071RB (Cortex-M0+), with no C at all.
#
#   make          blink.pl (which USES startup.pl) -> blink.elf, blink.bin
#   make flash    write it with st-flash over the board's ST-LINK
#
# Or copy blink.bin onto the NOD_G071RB drive the board shows over USB.

PLC     ?= ../../bin/plc
TRIPLE   = thumbv6m-unknown-none-eabi
CPU      = cortex-m0plus

all: blink.bin

blink.ll: blink.pl startup.pl $(PLC)
	$(PLC) --target=$(TRIPLE) $< -o $@

# -O0: PLUM has no VOLATILE yet, so an optimiser would drop register writes.
# -fdata-sections: every global in its own section, for the vector table.
blink.o: blink.ll
	clang --target=$(TRIPLE) -mcpu=$(CPU) -O0 -fdata-sections -c $< -o $@

blink.elf: blink.o g071.ld
	arm-none-eabi-ld --no-warn-rwx-segments -T g071.ld blink.o -o $@
	arm-none-eabi-size $@

blink.bin: blink.elf
	arm-none-eabi-objcopy -O binary $< $@

flash: blink.bin
	st-flash --reset write blink.bin 0x08000000

clean:
	rm -f blink.ll blink.o blink.elf blink.bin

.PHONY: all flash clean
