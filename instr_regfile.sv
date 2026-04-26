//Instruction regfile, Synchronous read, ID differs for each warp, allowing each to have unique memory file
module instr_regfile #(
    parameter logic [1:0] SET_ID = 2'd0
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        rd_en,        
    input  logic [9:0]  rd_addr,
    output logic [15:0] rd_data 
);
    logic [15:0] mem [0:1023]; 

    initial begin
        for (int i = 0; i < 1024; i++) mem[i] = 16'h0;
        case (SET_ID)
            2'd0: $readmemh("rom_set0.mem", mem);
            2'd1: $readmemh("rom_set1.mem", mem);
            2'd2: $readmemh("rom_set2.mem", mem);
            2'd3: $readmemh("rom_set3.mem", mem);
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst)
            rd_data <= '0;
        else if (rd_en)
            rd_data <= mem[rd_addr];
    end
endmodule
