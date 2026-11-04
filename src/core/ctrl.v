`timescale 1ns / 1ps
`include "riscv_define.vh"


module Ctrl(
    input [6:0]opcode,     // 输出：操作码
    input [2:0]func3,     // 输出：功能码3
    input [6:0]func7,     // 输出：功能码7
    input [11:0]func12,
    
    output [6:0]ALU_Ctrl,
    output [2:0]Comp_Ctrl,
    output Comp_en,
    output [1:0]reuse,
    output Load_en,
    output [2:0]Load_Ctrl,
    output Store_en,
    output [1:0]Store_Ctrl,
    output [2:0]WB_Ctrl,
    output wb_en
    );
    
    reg [6:0] reg_ALU_Ctrl;
    reg [2:0] reg_Comp_Ctrl;
    reg reg_Comp_en;
    reg [1:0]reg_reuse;
    reg reg_Load_en; 
    reg [2:0]reg_Load_Ctrl;
    reg reg_Store_en;
    reg [1:0]reg_Store_Ctrl;
    reg [2:0]reg_WB_Ctrl;
    reg reg_wb_en;
    
    always @ * begin
    	reg_ALU_Ctrl = `ADD;
    	reg_Comp_Ctrl = 3'b000;
    	reg_Comp_en = 1'b0;
    	reg_reuse = `NOUSE;
    	reg_Load_en = 1'b0;
    	reg_Load_Ctrl = `LOAD_NONE;
    	reg_Store_en = 1'b0;
    	reg_Store_Ctrl = `STORE_NO;
    	reg_WB_Ctrl = `WB_ALUOUT;
    	reg_wb_en = 1'b1;
    
    	case (opcode)
    		`OPCODE_I_TYPE: begin
    			case (func3)
    				3'b000: reg_ALU_Ctrl = `ADD;                                   	// addi
                		3'b010: begin 
                			reg_ALU_Ctrl = `ALU_SLT;  
                			reg_reuse = `SLTI;  
                			reg_Comp_en = 1'b1; 
                			reg_Comp_Ctrl = func3;
                			end							// slti
                		3'b011: begin 
                			reg_ALU_Ctrl = `ALU_SLTU; 
                			reg_reuse = `SLTI;
                			reg_Comp_en = 1'b1; 
                			reg_Comp_Ctrl = func3;
                			end 							// sltiu
                		3'b100: reg_ALU_Ctrl = `ALU_XOR;                                // xori
                		3'b110: reg_ALU_Ctrl = `ALU_OR;                                 // ori
                		3'b111: reg_ALU_Ctrl = `ALU_AND;                                // andi
                		3'b001: reg_ALU_Ctrl = `ALU_SLL;                                // slli
                		3'b101: reg_ALU_Ctrl = (func7 == 7'b0000000) ? `ALU_SRL : `ALU_SRA; // srli/srai
                		default: reg_ALU_Ctrl = `ADD;
    			endcase
    				reg_WB_Ctrl = `WB_ALUOUT;
    			end
    		`OPCODE_R_TYPE: begin
    			if (func7 == 7'b0000000 || func7 == 7'b0100000) begin
    				case (func3)
                			3'b000: reg_ALU_Ctrl = (func7 == 7'b0000000) ? `ADD : `SUB; 		// add/sub
                			3'b001: reg_ALU_Ctrl = `ALU_SLL;                                   	// sll
                			3'b010: begin 
                				reg_ALU_Ctrl = `ALU_SLT;  
                				reg_reuse = `SLTR;  
                				reg_Comp_en = 1'b1; 
                				reg_Comp_Ctrl = func3;
                			end 									// slt
                			3'b011: begin 
                				reg_ALU_Ctrl = `ALU_SLTU; 
                				reg_reuse = `SLTR; 
                				reg_Comp_en = 1'b1; 
                				reg_Comp_Ctrl = func3;
                			end 									// sltu
                			3'b100: reg_ALU_Ctrl = `ALU_XOR;                                   	// xor
                			3'b101: reg_ALU_Ctrl = (func7 == 7'b0000000) ? `ALU_SRL : `ALU_SRA; 	// srl/sra
                			3'b110: reg_ALU_Ctrl = `ALU_OR;                                    	// or
                			3'b111: reg_ALU_Ctrl = `ALU_AND;                                   	// and
                			default: reg_ALU_Ctrl = `ADD;
            			endcase
            		end
            		else if (func7 == 7'b0000001) begin
            			case (func3)
            				3'b000:reg_ALU_Ctrl = `ALU_MUL;
            				3'b001:reg_ALU_Ctrl = `ALU_MULH;
            				3'b010:reg_ALU_Ctrl = `ALU_MULHSU;
            				3'b011:reg_ALU_Ctrl = `ALU_MULHU;
            				3'b100:reg_ALU_Ctrl = `ALU_DIV;
            				3'b101:reg_ALU_Ctrl = `ALU_DIVU;
            				3'b110:reg_ALU_Ctrl = `ALU_REM;
            				3'b111:reg_ALU_Ctrl = `ALU_REMU;
            			endcase
            		end
            		else begin
            			reg_ALU_Ctrl = `ADD;
            		end
            				reg_WB_Ctrl = `WB_ALUOUT;
            		
    			end
    		`OPCODE_B_TYPE: begin
    				reg_ALU_Ctrl = `ADD;
    				reg_reuse = `NOUSE; 
                		reg_Comp_en = 1'b1;
                		reg_Comp_Ctrl = func3;
                		reg_wb_en = 1'b0;
    			end
    		`OPCODE_LUI: begin
            			reg_ALU_Ctrl = `ALU_PASS; // 透传高位立即数，无需ALU运算
            			reg_WB_Ctrl = `WB_ALUOUT;
        		end
        	`OPCODE_AUIPC: begin
            			reg_ALU_Ctrl = `ADD; 	// PC + 左移12位的立即数
            			reg_WB_Ctrl = `WB_ALUOUT;
        		end
        	`OPCODE_JAL: begin
        			reg_ALU_Ctrl = `ADD;
        			reg_WB_Ctrl = `WB_PC4;
        		end
        	`OPCODE_JALR: begin
        			reg_ALU_Ctrl = `ADD;
        			reg_WB_Ctrl = `WB_PC4;
        		end
        	`OPCODE_LW: begin
        		 case (func3)
                		3'b000: reg_Load_Ctrl = `LOAD_LB;  // lb：字节，有符号扩展
                		3'b001: reg_Load_Ctrl = `LOAD_LH;  // lh：半字，有符号扩展
                		3'b010: reg_Load_Ctrl = `LOAD_LW;  // lw：字，无扩展
                		3'b100: reg_Load_Ctrl = `LOAD_LBU; // lbu：字节，无符号扩展
                		3'b101: reg_Load_Ctrl = `LOAD_LHU; // lhu：半字，无符号扩展
                		default: reg_Load_Ctrl = `LOAD_NONE;
            		endcase
        			reg_ALU_Ctrl = `ADD;
        			reg_Load_en = 1'b1;
        			reg_WB_Ctrl = `WB_LOAD;
        		end
        	`OPCODE_SW: begin
        		case (func3)
                		3'b000: reg_Store_Ctrl = `STORE_SB;
                		3'b001: reg_Store_Ctrl = `STORE_SH;
                		3'b010: reg_Store_Ctrl = `STORE_SW;
                		default: reg_Store_Ctrl = `STORE_NO;
            		endcase
        			reg_ALU_Ctrl = `ADD;
        			reg_Store_en = 1'b1;
        			reg_WB_Ctrl = `WB_ELSE;
        			reg_wb_en = 1'b0;
        		end
        	`OPCODE_SYS: begin
        		if (func3 != 3'b000) begin
        			case (func3)
        			3'b001: reg_ALU_Ctrl = `ALU_CSRRW;
        			3'b010: reg_ALU_Ctrl = `ALU_CSRRS;
        			3'b011: reg_ALU_Ctrl = `ALU_CSRRC;
        			3'b101: reg_ALU_Ctrl = `ALU_CSRRWI;
        			3'b110: reg_ALU_Ctrl = `ALU_CSRRSI;
        			3'b111: reg_ALU_Ctrl = `ALU_CSRRCI;
        		endcase
    				reg_WB_Ctrl = `WB_CSR;
    				reg_wb_en = 1'b1;
    			end
        		else 
        			case (func12)
        			12'b000000000000: reg_ALU_Ctrl = `ALU_ECALL;
        			12'b000000000001: reg_ALU_Ctrl = `ALU_EBREAK;
        			12'b001100000010: reg_ALU_Ctrl = `ALU_MRET;
        			endcase
        		end
        	default: ;					//什么都不干
    	endcase
    end
    
    assign ALU_Ctrl = reg_ALU_Ctrl;
    assign Comp_Ctrl = reg_Comp_Ctrl;
    assign Comp_en = reg_Comp_en;
    assign reuse = reg_reuse;
    assign Load_en = reg_Load_en;
    assign Load_Ctrl = reg_Load_Ctrl;
    assign Store_en = reg_Store_en;
    assign Store_Ctrl = reg_Store_Ctrl;
    assign WB_Ctrl = reg_WB_Ctrl;
    assign wb_en = reg_wb_en;
    
endmodule
