// GPU_top_tb.sv - Comprehensive Testbench for GPU_top module with 4 parallel warps

`timescale 1ns/1ps

module GPU_top_tb;

    // ─────────────────────────────────────────────────────────────────────────
    // Parameters
    // ─────────────────────────────────────────────────────────────────────────
    parameter CLK_PERIOD = 10;
    parameter TIMEOUT_CYCLES = 200000;

    // ─────────────────────────────────────────────────────────────────────────
    // Signals
    // ─────────────────────────────────────────────────────────────────────────
    logic        clk;
    logic        reset;
    logic        GPU_done;

    logic [10:0]      dmem_addr;
    logic [127:0]     dmem_wdata;
    logic [15:0]      dmem_wen;
    logic [127:0]     dmem_rdata;

    logic [3:0][10:0]  imem_addr;
    logic [3:0][15:0] imem_rdata;

    int cycle_count;
    int error_count;
    int check_count;
    logic [31:0] program_duration_count;

    // ─────────────────────────────────────────────────────────────────────────
    // Clock Generation
    // ─────────────────────────────────────────────────────────────────────────
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ─────────────────────────────────────────────────────────────────────────
    // DUT Instantiation
    // ─────────────────────────────────────────────────────────────────────────
    GPU_top u_dut (
        .clk        (clk),
        .reset_in   (reset),
        .GPU_done   (GPU_done),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_wen   (dmem_wen),
        .dmem_rdata (dmem_rdata),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .program_duration_count (program_duration_count)
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Memory Instances
    // ─────────────────────────────────────────────────────────────────────────
    genvar w;
    generate
        for (w = 0; w < 4; w++) begin : imem_gen
            imem_bram_sim #(.WARP_ID(w)) u_imem (
                .clk   (clk),
                .addr  (imem_addr[w]),
                .rdata (imem_rdata[w])
            );
        end
    endgenerate

    dmem_bram_sim u_dmem (
        .clk   (clk),
        .addr  (dmem_addr),
        .wdata (dmem_wdata),
        .wen   (dmem_wen),
        .rdata (dmem_rdata)
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Cycle Counter and Timeout
    // ─────────────────────────────────────────────────────────────────────────
    always_ff @(posedge clk or posedge reset) begin
        if (reset) cycle_count <= 0;
        else cycle_count <= cycle_count + 1;
    end

    always @(posedge clk) begin
        if (cycle_count >= TIMEOUT_CYCLES) begin
            $display("[TIMEOUT] Exceeded %0d cycles", TIMEOUT_CYCLES);
            dump_memory();
            $finish;
        end
    end

    // ─────────────────────────────────────────────────────────────────────────
    // Main Test
    // ─────────────────────────────────────────────────────────────────────────
    initial begin
        $display("==========================================================");
        $display("GPU_top Comprehensive Testbench - 4 Warp Parallel Test");
        $display("==========================================================");

        error_count = 0;
        check_count = 0;
        reset = 1;
        repeat (10) @(posedge clk);
        reset = 0;
        $display("[%0t] Reset deasserted", $time);

        // Wait for completion
        wait (GPU_done == 1);
        $display("[%0t] GPU_done asserted at cycle %0d", $time, cycle_count);
        repeat (10) @(posedge clk);

        // Verify results
        verify_results();
        dump_memory();

        // Report
        $display("==========================================================");
        if (error_count == 0)
            $display("[PASS] All %0d checks passed (%0d cycles)", check_count, cycle_count);
        else
            $display("[FAIL] %0d / %0d checks failed", error_count, check_count);
        $display("==========================================================");
        $finish;
    end

    // ─────────────────────────────────────────────────────────────────────────
    // Verification - uses shadow memory
    // ─────────────────────────────────────────────────────────────────────────
    task automatic verify_results();
        for (int warp = 0; warp < 4; warp++) begin
            int base = warp * 128;
            $display("\n[WARP %0d] Verifying (word base %0d)...", warp, base);

            // ── Region 0: LANE_ID identity ───────────────────────────────────
            $display("  [Test 1] LANE_ID identity store...");
            for (int lane = 0; lane < 16; lane++) begin
                check_word(base + lane, lane,
                           $sformatf("W%0d LANE_ID[%0d]", warp, lane));
            end

            // ── Region 1: WARP_ID + LANE_ID ──────────────────────────────────
            $display("  [Test 2] WARP_ID + LANE_ID...");
            for (int lane = 0; lane < 16; lane++) begin
                check_word(base + 16 + lane, warp + lane,
                           $sformatf("W%0d ADD[%0d]", warp, lane));
            end

            // ── Region 2: Arithmetic chain ───────────────────────────────────
            $display("  [Test 3] Arithmetic chain (LANE*3 + 7 - WARP)...");
            for (int lane = 0; lane < 16; lane++) begin
                int expected = lane * 3 + 7 - warp;
                check_word(base + 32 + lane, expected & 16'hFFFF,
                           $sformatf("W%0d ARITH[%0d]", warp, lane));
            end

            // ── Region 3: LDC readback ───────────────────────────────────────
            $display("  [Test 4] LDC readback of LANE_ID...");
            for (int lane = 0; lane < 16; lane++) begin
                check_word(base + 48 + lane, lane,
                           $sformatf("W%0d LDC_RB[%0d]", warp, lane));
            end

            // ── Region 4: Divergent branch ───────────────────────────────────
            // Lanes 0-7 wrote 0xAA via STR (scatter store respects mask)
            // Lanes 8-15 were masked, memory unchanged (init pattern)
            $display("  [Test 5] Divergent branch (lanes 0-7: 0xAA, 8-15: unchanged)...");
            for (int lane = 0; lane < 8; lane++) begin
                check_word(base + 64 + lane, 16'h00AA,
                           $sformatf("W%0d DIV[%0d]", warp, lane));
            end
            for (int lane = 8; lane < 16; lane++) begin
                int word_addr = base + 64 + lane;
                int line = word_addr >> 3;
                int slot = word_addr & 7;
                int init_val = 16'hA000 + ((line & 8'hFF) << 4) + slot;
                check_word(word_addr, init_val,
                           $sformatf("W%0d DIV_MASKED[%0d]", warp, lane));
            end

            // ── Region 5: Post-SYNC reconvergence ────────────────────────────
            $display("  [Test 6] Post-SYNC reconvergence (all 0x55)...");
            for (int lane = 0; lane < 16; lane++) begin
                check_word(base + 80 + lane, 16'h0055,
                           $sformatf("W%0d SYNC[%0d]", warp, lane));
            end

            // ── Region 6: Scatter store pattern ──────────────────────────────
            // Each lane stored to base + 96 + LANE_ID*2
            // Value = LANE_ID + 0x100
            $display("  [Test 7] Scatter store (stride-2, value=LANE+0x100)...");
            for (int lane = 0; lane < 8; lane++) begin
                int addr = base + 96 + lane * 2;
                check_word(addr, lane + 16'h0100,
                           $sformatf("W%0d SCAT[%0d]", warp, lane));
            end

            // ── Region 7: Complex computation ────────────────────────────────
            $display("  [Test 8] Complex computation ((LANE+WARP)*5 - 10)...");
            for (int lane = 0; lane < 16; lane++) begin
                int expected = ((lane + warp) * 5) - 10;
                check_word(base + 112 + lane, expected & 16'hFFFF,
                           $sformatf("W%0d CPLX[%0d]", warp, lane));
            end
        end
    endtask

    task automatic check_word(int word_addr, int expected, string desc);
        logic [15:0] actual;
        actual = u_dmem.shadow_mem[word_addr];
        check_count++;
        if (actual !== expected[15:0]) begin
            $display("    [ERROR] %s: word[%0d] expected 0x%04X, got 0x%04X",
                     desc, word_addr, expected[15:0], actual);
            error_count++;
        end
    endtask

    task automatic dump_memory();
        $display("\n[Memory Dump] Modified words:");
        for (int warp = 0; warp < 4; warp++) begin
            int base = warp * 128;
            $display("  Warp %0d (base %0d):", warp, base);
            for (int region = 0; region < 8; region++) begin
                $write("    Region %0d: ", region);
                for (int i = 0; i < 16; i++) begin
                    $write("%04X ", u_dmem.shadow_mem[base + region*16 + i]);
                end
                $write("\n");
            end
        end
    endtask

endmodule


// ─────────────────────────────────────────────────────────────────────────────
// Instruction Memory Model - Comprehensive Test Program
// ─────────────────────────────────────────────────────────────────────────────
module imem_bram_sim #(
    parameter int WARP_ID = 0
)(
    input  logic        clk,
    input  logic [10:0]  addr,
    output logic [15:0] rdata
);
   logic [15:0] mem [0:1023];

    // Comprehensive test program
    // Preset registers:
    // R0 = 0 (hardwired)
    // R1 = LANE_ID (0-15)
    // R2 = WARP_ID (0-3)
    //
    // Memory layout per warp: 128 words (base = WARP_ID * 128)
    // Region 0: words 0-15   - LANE_ID identity
    // Region 1: words 16-31  - WARP_ID + LANE_ID
    // Region 2: words 32-47  - Arithmetic chain
    // Region 3: words 48-63  - LDC readback
    // Region 4: words 64-79  - Divergent branch (lanes <8 write 0xAA)
    // Region 5: words 80-95  - Post-SYNC (all lanes write 0x55)
    // Region 6: words 96-111 - Scatter store
    // Region 7: words 112-127- Complex computation

    initial begin
        int pc;
        for (int i = 0; i < 1024; i++) mem[i] = 16'h0000; // NOP

        // Encoding reference:
        // NOP:            0000_xxxx_xxxxxxxx = 0x0000
        // ADD Rd,Rs,Rt:   0011_dddd_ssss_tttt = 0x3DST
        // SUB Rd,Rs,Rt:   0100_dddd_ssss_tttt = 0x4DST
        // MUL Rd,Rs,Rt:   0101_dddd_ssss_tttt = 0x5DST
        // LDR Rd,Rs:      0111_dddd_ssss_xxxx = 0x7DS0
        // STR Rs,Rt:      1000_xxxx_ssss_tttt = 0x80ST
        // CONST Rd,imm8:  1001_dddd_iiiiiiii = 0x9Dii
        // CMP Rs,Rt:      1010_xxxx_ssss_tttt = 0xA0ST
        // BRnzp off8:     1011_nzp0_oooooooo = 0xBNoo (N=nzp flags)
        // SYNC:           1100_xxxx_xxxxxxxx = 0xC000
        // LDC Rd,Rs:      1101_dddd_ssss_xxxx = 0xDDS0
        // STRC Rs,Rt:     1110_xxxx_ssss_tttt = 0xE0ST
        // DONE:           1111_xxxx_xxxxxxxx = 0xF000

        pc = 0;

        // ══════════════════════════════════════════════════════════════════════
        // SETUP: Compute base address for this warp
        // ══════════════════════════════════════════════════════════════════════
        // R3 = 128 (words per warp region)
        mem[pc] = 16'h9380; pc++;                    // CONST R3, 128

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R4 = WARP_ID * 128 = base address
        mem[pc] = 16'h5423; pc++;                    // MUL R4, R2, R3

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // ══════════════════════════════════════════════════════════════════════
        // TEST 1: Store LANE_ID to Region 0 (base + 0)
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'hE041; pc++;                    // STRC R4, R1 (store LANE_ID)

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // ══════════════════════════════════════════════════════════════════════
        // TEST 2: Store WARP_ID + LANE_ID to Region 1 (base + 16)
        // ══════════════════════════════════════════════════════════════════════
        // R5 = WARP_ID + LANE_ID
        mem[pc] = 16'h3521; pc++;                    // ADD R5, R2, R1

        // R6 = 16 (offset to region 1)
        mem[pc] = 16'h9610; pc++;                    // CONST R6, 16

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R7 = base + 16
        mem[pc] = 16'h3746; pc++;                    // ADD R7, R4, R6

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        mem[pc] = 16'hE075; pc++;                    // STRC R7, R5

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // ══════════════════════════════════════════════════════════════════════
        // TEST 3: Arithmetic chain to Region 2 (base + 32)
        // R8 = LANE_ID * 3
        // R9 = R8 + 7
        // R10 = R9 - WARP_ID
        // ══════════════════════════════════════════════════════════════════════
        // R8 = 3
        mem[pc] = 16'h9803; pc++;                    // CONST R8, 3

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R8 = LANE_ID * 3
        mem[pc] = 16'h5818; pc++;                    // MUL R8, R1, R8

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R9 = 7
        mem[pc] = 16'h9907; pc++;                    // CONST R9, 7

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R9 = R8 + 7
        mem[pc] = 16'h3989; pc++;                    // ADD R9, R8, R9

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R10 = R9 - WARP_ID
        mem[pc] = 16'h4A92; pc++;                    // SUB R10, R9, R2

        // R11 = 32 (offset to region 2)
        mem[pc] = 16'h9B20; pc++;                    // CONST R11, 32

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R11 = base + 32
        mem[pc] = 16'h3B4B; pc++;                    // ADD R11, R4, R11

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        mem[pc] = 16'hE0BA; pc++;                    // STRC R11, R10

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // ══════════════════════════════════════════════════════════════════════
        // TEST 4: LDC readback from Region 0, store to Region 3 (base + 48)
        // ══════════════════════════════════════════════════════════════════════
        // R12 = load from base (Region 0 has LANE_ID)
        mem[pc] = 16'hDC40; pc++;                    // LDC R12, R4

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R13 = 48 (offset to region 3)
        mem[pc] = 16'h9D30; pc++;                    // CONST R13, 48

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R13 = base + 48
        mem[pc] = 16'h3D4D; pc++;                    // ADD R13, R4, R13

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        mem[pc] = 16'hE0DC; pc++;                    // STRC R13, R12

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // ══════════════════════════════════════════════════════════════════════
        // TEST 5: Divergent branch - Region 4 (base + 64)
        // Compare LANE_ID < 8: lanes 0-7 meet condition, lanes 8-15 don't
        // Branch masks lanes that DON'T meet condition (8-15)
        // Use STR (scatter store) which respects lane mask
        // ══════════════════════════════════════════════════════════════════════
        
        // R14 = 64 (offset to region 4)
        mem[pc] = 16'h9E40; pc++;                    // CONST R14, 64

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R14 = base + 64
        mem[pc] = 16'h3E4E; pc++;                    // ADD R14, R4, R14

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R15 = per-lane address: base + 64 + LANE_ID
        mem[pc] = 16'h3F1E; pc++;                    // ADD R15, R1, R14

        // R8 = 8 (threshold for comparison)
        mem[pc] = 16'h9808; pc++;                    // CONST R8, 8

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // CMP R1, R8: sets N if LANE_ID < 8
        mem[pc] = 16'hA018; pc++;                    // CMP R1, R8

        mem[pc] = 16'h0000; pc++;                    // NOP

        // BRn +2: always jumps, masks lanes where N is FALSE (lanes 8-15)
        mem[pc] = 16'hB802; pc++;                    // BRn +2

        mem[pc] = 16'h0000; pc++;                    // NOP (bubble)

        // ── Divergent block (only lanes 0-7 active) ──────────────────────────
        // R9 = 0xAA
        mem[pc] = 16'h99AA; pc++;                    // CONST R9, 0xAA

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // STR R15, R9: scatter store, only unmasked lanes (0-7) write
        mem[pc] = 16'h80F9; pc++;                    // STR R15, R9

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // ── SYNC: reconverge all lanes ───────────────────────────────────────
        mem[pc] = 16'hC000; pc++;                    // SYNC

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // ══════════════════════════════════════════════════════════════════════
        // TEST 6: Post-SYNC store to Region 5 (base + 80) - all 16 lanes write 0x55
        // ══════════════════════════════════════════════════════════════════════
        // R8 = 80
        mem[pc] = 16'h9850; pc++;                    // CONST R8, 80

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R8 = base + 80
        mem[pc] = 16'h3848; pc++;                    // ADD R8, R4, R8

        // R9 = 0x55
        mem[pc] = 16'h9955; pc++;                    // CONST R9, 0x55

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        mem[pc] = 16'hE089; pc++;                    // STRC R8, R9

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // ══════════════════════════════════════════════════════════════════════
        // TEST 7: Scatter store to Region 6 (base + 96)
        // Each lane stores to base + 96 + LANE_ID*2 (stride-2)
        // Value = LANE_ID + 0x100
        // ══════════════════════════════════════════════════════════════════════
        // R8 = 96
        mem[pc] = 16'h9860; pc++;                    // CONST R8, 96

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R8 = base + 96
        mem[pc] = 16'h3848; pc++;                    // ADD R8, R4, R8

        // R9 = 2 (stride)
        mem[pc] = 16'h9902; pc++;                    // CONST R9, 2

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R9 = LANE_ID * 2
        mem[pc] = 16'h5919; pc++;                    // MUL R9, R1, R9

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R9 = base + 96 + LANE_ID*2 (per-lane address)
        mem[pc] = 16'h3989; pc++;                    // ADD R9, R8, R9

        // Build 0x100 = 256: R10 = 16 * 16
        mem[pc] = 16'h9A10; pc++;                    // CONST R10, 16

        mem[pc] = 16'h9B10; pc++;                    // CONST R11, 16

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        mem[pc] = 16'h5AAB; pc++;                    // MUL R10, R10, R11 (R10 = 256)

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R10 = LANE_ID + 0x100
        mem[pc] = 16'h3A1A; pc++;                    // ADD R10, R1, R10

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // Scatter store: mem[R9] = R10 (per-lane addresses)
        mem[pc] = 16'h809A; pc++;                    // STR R9, R10

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // ══════════════════════════════════════════════════════════════════════
        // TEST 8: Complex computation to Region 7 (base + 112)
        // R = ((LANE_ID + WARP_ID) * 5) - 10
        // ══════════════════════════════════════════════════════════════════════
        // R8 = LANE_ID + WARP_ID
        mem[pc] = 16'h3812; pc++;                    // ADD R8, R1, R2

        // R9 = 5
        mem[pc] = 16'h9905; pc++;                    // CONST R9, 5

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R8 = (LANE_ID + WARP_ID) * 5
        mem[pc] = 16'h5889; pc++;                    // MUL R8, R8, R9

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R9 = 10
        mem[pc] = 16'h990A; pc++;                    // CONST R9, 10

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R8 = R8 - 10
        mem[pc] = 16'h4889; pc++;                    // SUB R8, R8, R9

        // R10 = 112
        mem[pc] = 16'h9A70; pc++;                    // CONST R10, 112

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // R10 = base + 112
        mem[pc] = 16'h3A4A; pc++;                    // ADD R10, R4, R10

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        mem[pc] = 16'hE0A8; pc++;                    // STRC R10, R8

        mem[pc] = 16'h0000; pc++;                    // NOP
        mem[pc] = 16'h0000; pc++;                    // NOP

        // ══════════════════════════════════════════════════════════════════════
        // DONE
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'hF000; pc++;                    // DONE


        
                $display("WARP %0d: Program loaded, %0d instructions", WARP_ID, pc);
    end

    always_ff @(posedge clk) begin
        rdata <= mem[addr];
    end
endmodule


// ─────────────────────────────────────────────────────────────────────────────
// Data Memory Model with Shadow Memory
// ─────────────────────────────────────────────────────────────────────────────
module dmem_bram_sim (
    input  logic         clk,
    input  logic [10:0]  addr,
    input  logic [127:0] wdata,
    input  logic [15:0]  wen,
    output logic [127:0] rdata
);
    // Main memory: 2048 lines × 128 bits (8 words per line)
    logic [127:0] mem [0:2047];

    // Initialize with distinguishable pattern: 0xA000 + (line << 4) + slot
    initial begin
        for (int L = 0; L < 2048; L++)
            for (int S = 0; S < 8; S++)
                mem[L][S*16 +: 16] = 16'hA000 + (L[7:0] << 4) + S[3:0];
    end

    // Read-before-write behavior
    always_ff @(posedge clk) begin
        rdata <= mem[addr];
        for (int b = 0; b < 16; b++)
            if (wen[b]) mem[addr][b*8 +: 8] <= wdata[b*8 +: 8];
    end

    // ── Shadow memory for verification ───────────────────────
    // Word-addressed: 16384 words = 2048 lines × 8 slots
    logic [15:0] shadow_mem [0:16383];

    initial begin
        for (int W = 0; W < 16384; W++) begin
            logic [10:0] L;
            logic [2:0]  S;
            L = W[13:3];
            S = W[2:0];
            shadow_mem[W] = 16'hA000 + (L[7:0] << 4) + S;
        end
    end

    // Update shadow on writes (byte pairs form words)
    always_ff @(posedge clk) begin
        for (int b = 0; b < 16; b += 2) begin
            if (wen[b] || wen[b+1]) begin
                int word_idx;
                word_idx = (addr << 3) + (b >> 1);
                if (wen[b])
                    shadow_mem[word_idx][7:0] <= wdata[b*8 +: 8];
                if (wen[b+1])
                    shadow_mem[word_idx][15:8] <= wdata[(b+1)*8 +: 8];
            end
        end
    end

endmodule