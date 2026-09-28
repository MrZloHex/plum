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

# -O0: PLUM has no VOLATILE yet, so an optimiser would drop register writes.
# --data-sections: every global in its own section, for the vector table.
blink.o: blink.pl startup.pl $(PLC)
	$(PLC) --emit=OBJ --target=$(TRIPLE) --cpu=$(CPU) -O0 --data-sections $< -o $@

blink.elf: blink.o g071.ld
	arm-none-eabi-ld --no-warn-rwx-segments -T g071.ld blink.o -o $@
	arm-none-eabi-size $@

blink.bin: blink.elf
	arm-none-eabi-objcopy -O binary $< $@

flash: blink.bin
	st-flash --reset write blink.bin 0x08000000

clean:
	rm -f blink.o blink.elf blink.bin

.PHONY: all flash clean
