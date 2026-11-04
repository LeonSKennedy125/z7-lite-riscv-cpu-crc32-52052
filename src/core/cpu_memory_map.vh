`ifndef CPU_MEMORY_MAP_VH
`define CPU_MEMORY_MAP_VH
// Provided CPU design document, section 2.3.4; byte addresses, no aliases.
`define CPU_RAM_BASE     32'h80100000
`define CPU_RAM_LAST     32'h8010ffff
`define CPU_MMIO_DIGITS  32'h80200020
`define CPU_MMIO_LED     32'h80200040
`define CPU_MMIO_COUNTER 32'h80200050
`endif
