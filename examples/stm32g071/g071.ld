/* g071.ld -- STM32G071RB: 128 KB of flash, 36 KB of RAM */

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 128K
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 36K
}

ENTRY(Reset_Handler)

/* the handlers a program leaves undefined, as weak symbols would be */
PROVIDE(NMI_Handler = Default_Handler);
PROVIDE(HardFault_Handler = Default_Handler);
PROVIDE(SVC_Handler = Default_Handler);
PROVIDE(PendSV_Handler = Default_Handler);
PROVIDE(SysTick_Handler = Default_Handler);

SECTIONS
{
    /* startup.pl's vector_NN_* globals, one section each, in order */
    .isr_vector : { KEEP(*(SORT_BY_NAME(.data.vector_*))) } > FLASH

    .text : {
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
    } > FLASH

    _sidata = LOADADDR(.data);
    .data : {
        _sdata = .;
        *(.data*)
        . = ALIGN(4);
        _edata = .;
    } > RAM AT > FLASH

    .bss : {
        _sbss = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    /* unwind tables, for C++ exceptions: PLUM has none */
    /DISCARD/ : { *(.ARM.exidx*) *(.ARM.extab*) }
}
