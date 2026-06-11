`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: imem_partition
//
// Partitions an AXI BRAM-controller port into 4 independent instruction
// memories, one per warp. MicroBlaze broadcasts writes to all 4 banks
// simultaneously so a single write pass loads all warps. Each warp gets
// a dedicated synchronous read port (port B) for contention-free fetching.
//
// Memory layout (byte-addressed from BD side):
//   bd_addr[10:2]  : 32-bit word index within bank (512 words = 2 KB)
//   bd_addr[1:0]   : byte select within 32-bit word (via bd_we[3:0])
//
// Each bank is 512 x 32-bit, packing two 16-bit GPU instructions per word:
//   GPU addr 2k   -> low half  (bits [15:0]  of word k)
//   GPU addr 2k+1 -> high half (bits [31:16] of word k)
//////////////////////////////////////////////////////////////////////////////////

module imem_partition #(
    parameter int N_WARPS        = 4,
    parameter int WORDS_PER_BANK = 512    // 32-bit words per bank (= 1024 16-bit instructions)
)(
    // ── Block-design side: AXI BRAM ctrl port A ──────────────────────────────
    input  logic        bd_clk,
    input  logic [12:0] bd_addr,    // byte address; only [10:2] used for word index
    input  logic [31:0] bd_din,
    output logic [31:0] bd_dout,
    input  logic        bd_en,
    input  logic [3:0]  bd_we,

    // ── GPU side: per-warp port B ────────────────────────────────────────────
    input  logic                       gpu_clk,
    input  logic [N_WARPS-1:0][9:0]    gpu_addr,
    output logic [N_WARPS-1:0][15:0]   gpu_rdata
);
    //Note: The top two bits of the address aren't being used, allows for us to switch to system where each warp has unique instruction


    // ── Word index for port A ─────────────────────────────────────────────────
    logic [8:0] bd_word_idx = bd_addr[10:2];

    // ── 4 BRAM banks ─────────────────────────────────────────────────────────
    genvar w;
    generate
        for (w = 0; w < N_WARPS; w++) begin : bank
            (* ram_style = "block" *) logic [31:0] mem [0:WORDS_PER_BANK-1];

            initial for (int i = 0; i < WORDS_PER_BANK; i++) mem[i] = 32'h0;

            // Port A: MicroBlaze broadcasts writes to all banks simultaneously
            always_ff @(posedge bd_clk) begin
                if (bd_en) begin
                    if (bd_we[0]) mem[bd_word_idx][ 7: 0] <= bd_din[ 7: 0];
                    if (bd_we[1]) mem[bd_word_idx][15: 8] <= bd_din[15: 8];
                    if (bd_we[2]) mem[bd_word_idx][23:16] <= bd_din[23:16];
                    if (bd_we[3]) mem[bd_word_idx][31:24] <= bd_din[31:24];
                end
            end

            // Port B: per-warp 1-cycle synchronous read with 16-bit half mux
            logic [31:0] gpu_word_q;
            logic        gpu_lsb_q;

            always_ff @(posedge gpu_clk) begin
                gpu_word_q <= mem[gpu_addr[w][9:1]];
                gpu_lsb_q  <= gpu_addr[w][0];
            end

            assign gpu_rdata[w] = gpu_lsb_q ? gpu_word_q[31:16]
                                            : gpu_word_q[15:0];
        end
    endgenerate

    // ── Read back to MicroBlaze from bank 0 (all banks identical) ────────────
    always_ff @(posedge bd_clk) begin
        if (bd_en)
            bd_dout <= bank[0].mem[bd_word_idx];
    end

endmodule