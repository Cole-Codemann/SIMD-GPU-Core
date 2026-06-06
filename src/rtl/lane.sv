//Lane contains just the register file currently,
//Has unique LANE_ID
module lane #(
    parameter LANE_ID = 0,
    parameter WARP_ID = 0
)(
    input  logic        clk,
    input  logic        reset,
    input  logic        regwe,
    input  logic        halt,
    input  logic        mask,
    input  logic [3:0]  rs_addr,
    input  logic [3:0]  rt_addr,
    input  logic [3:0]  rd_addr,
    input  logic [15:0] rd_data,
    output logic [15:0] rs_data,
    output logic [15:0] rt_data
);
    //Register file unique to lane, write enable depends on regwe, halt, and mask signals
    reg_file #(
        .LANE_ID (LANE_ID), .WARP_ID(WARP_ID)
    ) rf_inst (
        .clk    (clk),
        .rst    (reset),
        .wen    (regwe & !halt & !mask),
        .waddr  (rd_addr),
        .wdata  (rd_data),
        .raddr1 (rs_addr),
        .rdata1 (rs_data),
        .raddr2 (rt_addr),
        .rdata2 (rt_data)
    );

endmodule
