`timescale 1ns/1ps
// R1 reset boundary. An off-clock fault is captured immediately by capture.
// Only the two-stage, clock-qualified reset reaches CPU/BRAM control logic.
// io_resetn asserts without a clock and remains low through core qualification.
module cpu_reset_control (
    input wire clk,
    input wire ext_resetn,
    input wire locked,
    input wire controller_reset,
    output wire reset,
    output wire io_resetn
);
    wire request;
    cpu_reset_sync capture(clk,ext_resetn,locked,controller_reset,request);
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *)
    reg [1:0] qualified = 2'b11;
    always @(posedge clk)
        qualified <= {qualified[0],request};
    assign reset = qualified[1];
    assign io_resetn = !request && !reset;
endmodule
