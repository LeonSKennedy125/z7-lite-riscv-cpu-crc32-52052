`ifndef RISCV_DEFINE_VH
`define RISCV_DEFINE_VH

`define OPCODE_R_TYPE    7'b0110011  // R型指令（add/sub/and等）
`define OPCODE_I_TYPE    7'b0010011  // I型立即数指令（addi/andi等）
`define OPCODE_LW        7'b0000011  // I型加载指令（lw/lb）
`define OPCODE_SW        7'b0100011  // S型存储指令（sw/sb）
`define OPCODE_B_TYPE    7'b1100011  // B型分支指令（beq/bne/blt）
`define OPCODE_JAL       7'b1101111  // J型跳转指令（jal）
`define OPCODE_JALR      7'b1100111  // I型跳转指令（jalr）
`define OPCODE_LUI       7'b0110111  // U型指令（lui）
`define OPCODE_AUIPC     7'b0010111  // U型指令（auipc）
`define OPCODE_SYS       7'b1110011  // 系统指令，ECALL/EBREAK，MRET，CSR

`define TYPE_R 4'b0000
`define TYPE_I 4'b0001
`define TYPE_S 4'b0010
`define TYPE_B 4'b0011
`define TYPE_JAL 4'b0100
`define TYPE_JALR 4'b0101
`define TYPE_LUI 4'b0110
`define TYPE_AUIPC 4'b0111
`define TYPE_LW 4'b1000
`define TYPE_CSR 4'b1001
`define TYPE_EM 4'b1010

`define PREDICT_W1 2'b01
`define PREDICT_W2 2'b10
`define PREDICT_R 2'b00

`define JUMP 1'b1
`define NOTJUMP 1'b0

`define Imm_I 3'b000
`define Imm_R 3'b001
`define Imm_U 3'b010
`define Imm_S 3'b011
`define Imm_B 3'b100
`define Imm_J 3'b101

`define A_PC 1'b0
`define A_DATA1 1'b1

`define B_IMM 1'b0
`define B_DATA2 1'b1

`define ADD 7'b0000000
`define SUB 7'b0000001
`define ALU_AND 7'b0000010
`define ALU_OR 7'b0000011
`define ALU_XOR 7'b0000100
`define ALU_SLL 7'b0000101
`define ALU_SRL 7'b0000110
`define ALU_SRA 7'b0000111
`define ALU_SLT 7'b0001000
`define ALU_SLTU 7'b0001001
`define ALU_PASS 7'b0001010
`define ALU_MUL 7'b0001011
`define ALU_MULH 7'b0001100
`define ALU_MULHSU 7'b0001101
`define ALU_MULHU 7'b0001110
`define ALU_DIV 7'b0001111
`define ALU_DIVU 7'b0010000
`define ALU_REM 7'b0010001
`define ALU_REMU 7'b0010010
`define ALU_ECALL 7'b0010011
`define ALU_EBREAK 7'b0010100
`define ALU_MRET 7'b0010101
`define ALU_CSRRW 7'b0010110
`define ALU_CSRRS 7'b0010111
`define ALU_CSRRC 7'b0011000
`define ALU_CSRRWI 7'b0011001
`define ALU_CSRRSI 7'b0011010
`define ALU_CSRRCI 7'b0011011

`define NOUSE 2'b00
`define SLTR 2'b01
`define SLTI 2'b10

`define LOAD_NONE 3'b000
`define LOAD_LB 3'b001
`define LOAD_LH 3'b010
`define LOAD_LW 3'b011
`define LOAD_LBU 3'b100
`define LOAD_LHU 3'b101

`define STORE_SB 2'b01
`define STORE_SH 2'b10
`define STORE_SW 2'b11
`define STORE_NO 2'b00

`define WB_ALUOUT 3'b000
`define WB_LOAD 3'b001
`define WB_PC4 3'b010
`define WB_CSR 3'b011
`define WB_ELSE 3'b100

`define FW_Aluout 2'b00
`define FW_Load 2'b01
`define FW_Pc4 2'b10
`define FW_CSR 2'b11

`endif