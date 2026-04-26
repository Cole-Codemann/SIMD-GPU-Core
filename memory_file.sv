module memory_file #(
    localparam bit INIT_FROM_FILE = 1,
    localparam string MEM_FILE = "mem_init.mem"
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        wen,
    input  logic [15:0] waddr,
    input  logic [15:0] wdata,
    input  logic [15:0] raddr,
    output logic [15:0] rdata
);

    logic [15:0] mem [0:1023];

    // Optional file initialization (simulation-time only)
    generate
        if (INIT_FROM_FILE) begin : init_block
            initial begin
                $readmemh(MEM_FILE, mem);
            end
        end
    endgenerate

    // Runtime behavior
    always_ff @(posedge clk) begin
        if (rst && !INIT_FROM_FILE) begin
            for (int i = 0; i < 1024; i++) begin
                mem[i] <= 16'h0;
            end
        end else if (wen) begin
            mem[waddr[9:0]] <= wdata;
        end
    end

    assign rdata = mem[raddr[9:0]];

endmodule