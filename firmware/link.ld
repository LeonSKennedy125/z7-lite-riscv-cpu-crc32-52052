OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { ROM(rx): ORIGIN = 0x80000000, LENGTH = 16K
         RAM(rw): ORIGIN = 0x80100000, LENGTH = 64K }
SECTIONS {
 .text : { KEEP(*(.text.start)) *(.text .text.*) } >ROM
 .boundary (NOLOAD) : { . += 16; } >RAM
 .rodata : { *(.rodata .rodata.* .srodata .srodata.*) } >RAM
 .data : { *(.data .data.* .sdata .sdata.*) } >RAM
 .bss (NOLOAD) : { . = ALIGN(4); __bss_start = .; *(.bss .bss.* .sbss .sbss.*) *(COMMON) . = ALIGN(4); __bss_end = .; } >RAM
 __stack_top = ORIGIN(RAM)+LENGTH(RAM);
 ASSERT(SIZEOF(.data)==0,"initialized writable data forbidden")
 ASSERT(__bss_end<=__stack_top-4096,"RAM stack reserve exceeded")
 /DISCARD/ : { *(.comment) *(.eh_frame*) }
}
