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
//
// WRITE-TIMING NOTE:
//   The AXI BRAM Controller presents bram_addr / bram_en / bram_we one cycle
//   AHEAD of the corresponding bram_wrdata. Fix: delay address/enable/strobes
//   by one cycle (wr_idx_q, wr_en_q, wr_we_q) while leaving bd_din undelayed.
//
// SYMMETRIC PORT-A INFERENCE:
//   Every bank's port A has an IDENTICAL structure: a write path AND a
//   read-first read into a per-bank `bd_dout_w` register. This forces Vivado
//   to infer all 4 banks with the same primitive shape, so the broadcast
//   write reaches every bank equally.
//
//   Only bank 1's readback is wired to bd_dout (this build); the others'
//   bd_dout_w registers are forced to exist via dont_touch so synthesis
//   can't drop them as dead code.
//
// DEBUG SWITCH: which bank drives bd_dout
//   #define READBACK_BANK below to choose. Currently set to 1 to confirm
//   broadcast: if only bank READBACK_BANK is alive, hardware reads from
//   wherever this points.
//////////////////////////////////////////////////////////////////////////////////

`define READBACK_BANK 1   // which bank drives bd_dout (0, 1, 2, or 3)

module imem_partition #(
    parameter int N_WARPS        = 12,
    parameter int WORDS_PER_BANK = 2048    // 32-bit words per bank (= 1024 16-bit instructions)
)(
    // ── Block-design side: AXI BRAM ctrl port A ──────────────────────────────
    input  logic        bd_clk,
    input  logic [12:0] bd_addr,    // byte address; only [12:2] used for word index
    input  logic [31:0] bd_din,
    output logic [31:0] bd_dout,
    input  logic        bd_en,
    input  logic [3:0]  bd_we,

    // ── GPU side: per-warp port B ─────────────────────────────────────────────
    input  logic                      gpu_clk,
    input  logic [N_WARPS-1:0][11:0]   gpu_addr,
    output logic [N_WARPS-1:0][15:0]  gpu_rdata
);

    // ── Word index for port A ─────────────────────────────────────────────────
    logic [10:0] bd_word_idx;
    assign bd_word_idx = bd_addr[12:2];

    // ── Write-control pipeline ────────────────────────────────────────────────
    // Delay address/enable/strobes one cycle to align with bd_din.
    logic [10:0] wr_idx_q;
    logic       wr_en_q;
    logic [3:0] wr_we_q;
    always_ff @(posedge bd_clk) begin
        wr_idx_q <= bd_word_idx;
        wr_en_q  <= bd_en;
        wr_we_q  <= bd_we;
    end

    // ── 4 BRAM banks ─────────────────────────────────────────────────────────
    // Every bank gets IDENTICAL port-A structure: write + read-first into a
    // per-bank bd_dout_w register. `dont_touch` on bd_dout_w forces synthesis
    // to keep the read path alive on every bank, so all 4 banks are inferred
    // with the same primitive shape - which is necessary for the broadcast
    // write to reach all of them.
    genvar w;
    generate
        for (w = 0; w < N_WARPS; w++) begin : bank
            (* keep_hierarchy = "yes" *)
            (* dont_touch = "yes", ram_style = "block" *) logic [31:0] mem [0:WORDS_PER_BANK-1];
            initial for (int i = 0; i < WORDS_PER_BANK; i++) mem[i] = 32'h0;

            // Per-bank readback register - forced to stay even if unused so
            // every bank has a symmetric port-A read path.
            (* dont_touch = "yes" *) logic [31:0] bd_dout_w;

            // Port A: write + read-first in one always_ff. Identical across
            // all banks so Vivado infers them the same way.
            always_ff @(posedge bd_clk) begin
                if (wr_en_q) begin
                    if (wr_we_q[0]) mem[wr_idx_q][ 7: 0] <= bd_din[ 7: 0];
                    if (wr_we_q[1]) mem[wr_idx_q][15: 8] <= bd_din[15: 8];
                    if (wr_we_q[2]) mem[wr_idx_q][23:16] <= bd_din[23:16];
                    if (wr_we_q[3]) mem[wr_idx_q][31:24] <= bd_din[31:24];
                end
                bd_dout_w <= mem[bd_word_idx];   // unconditional read on port A
            end

            // Port B: per-warp 1-cycle synchronous read with 16-bit half mux.
            logic [31:0] gpu_word_q;
            logic        gpu_lsb_q;
            always_ff @(posedge gpu_clk) begin
                gpu_word_q <= mem[gpu_addr[w][11:1]];
                gpu_lsb_q  <= gpu_addr[w][0];
            end
            assign gpu_rdata[w] = gpu_lsb_q ? gpu_word_q[31:16]
                                            : gpu_word_q[15:0];
        end
    endgenerate

    // ── Bank-select mux for bd_dout ───────────────────────────────────────────
    // Pick which bank's read-back drives bd_dout. Parameterized so it works
    // for any N_WARPS value without a hardcoded case statement.
    assign bd_dout = bank[`READBACK_BANK].bd_dout_w;
endmodule