`timescale 1ns / 1ps

// Each asynchronous source has its own dedicated primitive CLR/PRE path.
// Combine only captured requests. The combination feeds the synchronous
// qualification stage in cpu_reset_control, never a CPU asynchronous pin.
module cpu_reset_sync (
    input wire clk,
    input wire ext_resetn,
    input wire locked,
    input wire controller_reset,
    output wire reset
);
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [2:0] ext_ff = 3'b000;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [2:0] lock_ff = 3'b000;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [2:0] controller_ff = 3'b111;
    always @(posedge clk or negedge ext_resetn)
        if (!ext_resetn) ext_ff <= 3'b000;
        else ext_ff <= {ext_ff[1:0],1'b1};
    always @(posedge clk or negedge locked)
        if (!locked) lock_ff <= 3'b000;
        else lock_ff <= {lock_ff[1:0],1'b1};
    always @(posedge clk or posedge controller_reset)
        if (controller_reset) controller_ff <= 3'b111;
        else controller_ff <= {controller_ff[1:0],1'b0};
    assign reset = !ext_ff[2] || !lock_ff[2] || controller_ff[2];
endmodule
