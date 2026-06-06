// Engineer: Cole Kaufmann
// Create Date: 06/01/2026
// Module Name: GPU_top_wrapper
//
// Synthesis wrapper around GPU_top. Instantiates internal BRAMs for the four
// instruction memories and the data memory so the full design can synthesize
// as a self-contained unit with only clk/reset/GPU_done crossing the package
// boundary. Use this as the top-level for timing exploration and (eventually)
// board bringup. For pure OOC timing analysis of GPU_top itself, target
// GPU_top directly instead and leave this wrapper out of the run.


module top_level (
    input  logic clk,
    input  logic reset,
    output logic GPU_done
);
    // This is primarily for testing GPU, it is not used in final design connecting GPU and CPU top

    // ── Internal nets to/from GPU_top ────────────────────────────────────────
    logic [10:0]      dmem_addr;
    logic [127:0]     dmem_wdata;
    logic [15:0]      dmem_wen;
    logic [127:0]     dmem_rdata;

    logic [3:0][9:0]  imem_addr;
    logic [3:0][15:0] imem_rdata;

    // ── DUT ──────────────────────────────────────────────────────────────────
    GPU_top u_gpu (
        .clk        (clk),
        .reset      (reset),
        .GPU_done   (GPU_done),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_wen   (dmem_wen),
        .dmem_rdata (dmem_rdata),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata)
    );

    // ── Instruction memories - one BRAM per warp ─────────────────────────────
    genvar w;
    generate
        for (w = 0; w < 4; w++) begin : imem_gen
            imem_bram #(.SET_ID(w)) u_imem (
                .clk   (clk),
                .addr  (imem_addr[w]),
                .rdata (imem_rdata[w])
            );
        end
    endgenerate

    // ── Data memory - single 128-bit-wide BRAM ───────────────────────────────
    dmem_bram u_dmem (
        .clk   (clk),
        .addr  (dmem_addr),
        .wdata (dmem_wdata),
        .wen   (dmem_wen),
        .rdata (dmem_rdata)
    );

endmodule


// ─────────────────────────────────────────────────────────────────────────────
// Instruction memory BRAM - TEMPORARY
// 1024 × 16-bit, synchronous read. SET_ID picks which rom_setN.mem to preload.
// Matches the read latency of the prior in-warp instr_regfile (1 cycle).
// ─────────────────────────────────────────────────────────────────────────────
module imem_bram #(
    parameter int SET_ID = 0
)(
    input  logic        clk,
    input  logic [9:0]  addr,
    output logic [15:0] rdata
);
    (* ram_style = "block" *) logic [15:0] mem [0:1023];

    initial begin
        for (int i = 0; i < 1024; i++) mem[i] = 16'h0;
        case (SET_ID)
            0: $readmemh("rom_set0.mem", mem);
            1: $readmemh("rom_set1.mem", mem);
            2: $readmemh("rom_set2.mem", mem);
            3: $readmemh("rom_set3.mem", mem);
        endcase
    end

    always_ff @(posedge clk) begin
        rdata <= mem[addr];
    end
endmodule


// ─────────────────────────────────────────────────────────────────────────────
// Data memory BRAM - TEMPORARY
// 2048 × 128-bit, synchronous read + write. Sixteen byte-write enables align
// with Xilinx BRAM byte-WE behavior; the memory_controller emits wen in pairs
// of 2 bits per 16-bit word, so each pair enables both bytes of that word.
// dmem_init.mem is optional - leave the file absent for an all-zero memory
// (e.g. for OOC timing runs where contents don't matter).
// ─────────────────────────────────────────────────────────────────────────────
module dmem_bram (
    input  logic         clk,
    input  logic [10:0]  addr,
    input  logic [127:0] wdata,
    input  logic [15:0]  wen,
    output logic [127:0] rdata
);
    (* ram_style = "block" *) logic [127:0] mem [0:2047];

    initial begin
        for (int i = 0; i < 2048; i++) mem[i] = 128'h0;
        $readmemh("mem_init.mem", mem);
    end

    always_ff @(posedge clk) begin
        for (int b = 0; b < 16; b++) begin
            if (wen[b])
                mem[addr][b*8 +: 8] <= wdata[b*8 +: 8];
        end
        rdata <= mem[addr];
    end
endmodule
