//One port synchronous write/reset, two port async reading
//R0 = 0, R1 = LANE_ID
module reg_file #(
    parameter int LANE_ID = 0
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        wen,
    input  logic [3:0]  waddr,
    input  logic [15:0] wdata,
    input  logic [3:0]  raddr1, // rs_addr
    input  logic [3:0]  raddr2, // rt_addr
    output logic [15:0] rdata1, // rs_data
    output logic [15:0] rdata2  // rt_data
);

    logic [15:0] registers [2:15];

    // Write operations: One-port synchronous write + reset
    always_ff @(posedge clk) begin
        if (rst) begin
            // Reset only writable registers
            for (int i = 2; i < 16; i++) begin
                registers[i] <= 16'h0;
            end
        end else if (wen && waddr > 4'd1) begin
            // Protect registers 0 and 1
            registers[waddr] <= wdata;
        end
    end
    
    //Read operations: Two-port, asynchronous reading
    //Register 0 is always 16'h0
    //Register 1 is always 16'(LANE_ID)
    always_comb begin
        if (raddr1 == 4'd0)      rdata1 = 16'h0;
        else if (raddr1 == 4'd1) rdata1 = 16'(LANE_ID);
        else                     rdata1 = registers[raddr1];
    end

    always_comb begin
        if (raddr2 == 4'd0)      rdata2 = 16'h0;
        else if (raddr2 == 4'd1) rdata2 = 16'(LANE_ID);
        else                     rdata2 = registers[raddr2];
    end

endmodule
