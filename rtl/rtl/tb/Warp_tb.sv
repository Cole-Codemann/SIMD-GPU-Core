// warp_tb.sv - Unit-level testbench for warp module
//
// Stubs out the surrounding GPU_top environment:
//   - Instruction memory: imem[] preloaded from rom_set0.mem
//   - ALU model:          combinational; computes ADD/SUB/MUL/DIV/CMP
//                         (CMP modeled as SUB so the rs/rt operands set flags)
//   - Warp controller:    always grants this warp (alu_access = alu_req)
//   - Memory controller:  small dmem array, single-cycle ack, next-cycle done
//
// Smoke test: assert done within 10000 cycles, then dump non-zero dmem in 64-160.

`timescale 1ns / 1ps

module warp_tb;

    // ── Clock & reset ────────────────────────────────────────────────────────
    localparam int CLK_PERIOD_NS = 10;
    logic clk = 0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;
    logic reset;

    // ── DUT signals ──────────────────────────────────────────────────────────
    logic              mem_req_done;
    logic [15:0][15:0] exe_out;
    logic [15:0][15:0] mem_to_reg_data;
    logic              mem_request_ack;
    logic              alu_access;
    logic [15:0][15:0] rs_data_exe;
    logic [15:0][15:0] rt_data_exe;
    logic [3:0]        op_exe;
    logic              store_request, load_request, conc_request;
    logic [15:0]       mask_exe;
    logic              alu_req;
    logic              done;
    logic              stalled_on_alu_out;
    logic              stalled_on_mem_out;
    logic              scoreboard_stall_out;
    logic [15:0]       instr_in;
    logic [10:0]        pc;

    // ── DUT ──────────────────────────────────────────────────────────────────
    warp #(.WARP_ID(2'd0)) dut (
        .clk            (clk),
        .reset          (reset),
        .mem_req_done   (mem_req_done),
        .exe_out        (exe_out),
        .mem_to_reg_data(mem_to_reg_data),
        .mem_request_ack(mem_request_ack),
        .alu_access     (alu_access),
        .rs_data_exe    (rs_data_exe),
        .rt_data_exe    (rt_data_exe),
        .op_exe         (op_exe),
        .store_request  (store_request),
        .load_request   (load_request),
        .conc_request   (conc_request),
        .mask_exe       (mask_exe),
        .alu_req        (alu_req),
        .done           (done),
        .stalled_on_alu_out (stalled_on_alu_out),
        .stalled_on_mem_out (stalled_on_mem_out),
        .scoreboard_stall_out (scoreboard_stall_out),
        .instr_in       (instr_in),
        .pc             (pc)
    );

    // ── Instruction memory (loaded from rom_set0.mem) ────────────────────────

    imem_bram_sim #(.WARP_ID(0)) u_imem (
        .clk   (clk),
        .addr  (pc),
        .rdata (instr_in)
    );

    // ── ALU model: combinational. CMP modeled as SUB so its operands set flags
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            case (op_exe)
                4'b0011: exe_out[i] = rs_data_exe[i] + rt_data_exe[i];                     // ADD
                4'b0100: exe_out[i] = rs_data_exe[i] - rt_data_exe[i];                     // SUB
                4'b1010: exe_out[i] = rs_data_exe[i] - rt_data_exe[i];                     // CMP (SUB)
                4'b0101: exe_out[i] = rs_data_exe[i] * rt_data_exe[i];                     // MUL
                4'b0110: exe_out[i] = (rt_data_exe[i] != 0) ?
                                       rs_data_exe[i] / rt_data_exe[i] : 16'h0;            // DIV
                default: exe_out[i] = 16'h0;
            endcase
        end
    end

    // ── Warp controller stub: register the grant ─────────────────────────────
    always_ff @(posedge clk or posedge reset) begin
        if (reset) alu_access <= 1'b0;
        else begin
               alu_access <= alu_req;
        end        
    end
    
    // ── Memory model: small dmem, ack-then-done handshake ────────────────────
    logic [15:0] dmem [0:2047];
    initial for (int i = 0; i < 2048; i++) dmem[i] = 16'h0;

    typedef enum logic [1:0] {MEM_IDLE, MEM_DONE} mem_state_t;
    mem_state_t mem_state;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_state       <= MEM_IDLE;
            mem_request_ack <= 1'b0;
            mem_req_done    <= 1'b0;
            mem_to_reg_data <= '0;
        end else begin
            mem_request_ack <= 1'b0;
            mem_req_done    <= 1'b0;
            case (mem_state)
                MEM_IDLE: begin
                    if (load_request) begin
                        // Loads
                        if (conc_request) begin
                            // LDR_CON: read 16 contiguous words from lane-0 base
                            for (int i = 0; i < 16; i++)
                                mem_to_reg_data[i] <= dmem[(rs_data_exe[0] + i) & 11'h7FF];
                        end else begin
                            // LDR: each lane its own address
                            for (int i = 0; i < 16; i++)
                                if (!mask_exe[i])
                                    mem_to_reg_data[i] <= dmem[rs_data_exe[i] & 11'h7FF];
                        end
                        mem_request_ack <= 1'b1;
                        mem_state       <= MEM_DONE;
                    end else if (store_request) begin
                        // Stores
                        if (conc_request) begin
                            // STR_CON: 16 contiguous writes from lane-0 base
                            for (int i = 0; i < 16; i++)
                                dmem[(rs_data_exe[0] + i) & 11'h7FF] <= rt_data_exe[i];
                        end else begin
                            for (int i = 0; i < 16; i++)
                                if (!mask_exe[i])
                                    dmem[rs_data_exe[i] & 11'h7FF] <= rt_data_exe[i];
                        end
                        mem_request_ack <= 1'b1;
                        mem_state       <= MEM_DONE;
                    end
                end
                MEM_DONE: begin
                    mem_req_done <= 1'b1;
                    mem_state    <= MEM_IDLE;
                end
                default: mem_state <= MEM_IDLE;
            endcase
        end
    end

// ── Stimulus ─────────────────────────────────────────────────────────────
    int error_count;
    int pass_count;

    initial begin
        $display("[%0t] warp_tb starting", $time);
        reset = 1'b1;
        error_count = 0;
        pass_count = 0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        $display("[%0t] reset released", $time);

        fork
            begin : wait_done
                @(posedge done);
                $display("[%0t] done asserted, pc=0x%03X", $time, pc);
                disable timeout;
            end
            begin : timeout
                repeat (10_000) @(posedge clk);
                $display("[%0t] FAIL: timeout, pc=0x%03X done=%b", $time, pc, done);
                error_count++;
                disable wait_done;
            end
        join

        repeat (10) @(posedge clk);

        // ── Memory Verification ──────────────────────────────────────────────
        $display("");
        $display("================================================================");
        $display("Memory Verification");
        $display("================================================================");

        // [0..15] = LANE_ID identity
        $display("LANE_ID identity [0..15]:");
        for (int i = 0; i < 16; i++)
            check($sformatf("  [%0d]", i), i[15:0], dmem[i]);

        // [64..79] = 15 (ADD: 10 + 5)
        $display("ADD 10+5 [64..79]:");
        for (int i = 64; i < 80; i++)
            check($sformatf("  [%0d]", i), 16'd15, dmem[i]);

        // [80..95] = 5 (SUB: 10 - 5)
        $display("SUB 10-5 [80..95]:");
        for (int i = 80; i < 96; i++)
            check($sformatf("  [%0d]", i), 16'd5, dmem[i]);

        // [96..111] = 50 (MUL: 10 * 5)
        $display("MUL 10*5 [96..111]:");
        for (int i = 96; i < 112; i++)
            check($sformatf("  [%0d]", i), 16'd50, dmem[i]);

        // [112..127] = 3 (DIV: 10 / 3)
        $display("DIV 10/3 [112..127]:");
        for (int i = 112; i < 128; i++)
            check($sformatf("  [%0d]", i), 16'd3, dmem[i]);

        // [128..143] = 15 (LDR readback of [64..79])
        $display("LDR readback [128..143]:");
        for (int i = 128; i < 144; i++)
            check($sformatf("  [%0d]", i), 16'd15, dmem[i]);

        // [144..153] = 42 (Divergent write, lanes 0-9 only)
        $display("Divergent write lanes 0-9 [144..153]:");
        for (int i = 144; i < 154; i++)
            check($sformatf("  [%0d]", i), 16'd42, dmem[i]);

        // [154..159] = 0 (Masked lanes 10-15, unwritten)
        $display("Masked lanes 10-15 [154..159]:");
        for (int i = 154; i < 160; i++)
            check($sformatf("  [%0d]", i), 16'd0, dmem[i]);

        // [160..175] = 7 (Post-SYNC reconvergence, all lanes)
        $display("Post-SYNC all lanes [160..175]:");
        for (int i = 160; i < 176; i++)
            check($sformatf("  [%0d]", i), 16'd7, dmem[i]);

        // [176..191] = LANE_ID identity (Post-SYNC)
        $display("Post-SYNC LANE_ID [176..191]:");
        for (int i = 176; i < 192; i++)
            check($sformatf("  [%0d]", i), (i - 176), dmem[i]);

        // ── Summary ──────────────────────────────────────────────────────────
        $display("");
        $display("================================================================");
        if (error_count == 0)
            $display("PASS (%0d checks)", pass_count);
        else
            $display("FAIL (%0d errors, %0d passed)", error_count, pass_count);
        $display("================================================================");

        // ── Dump non-zero for inspection ─────────────────────────────────────
        $display("");
        $display("--- dmem dump [0..191] ---");
        for (int i = 0; i < 192; i++) begin
            if (dmem[i] !== 16'h0)
                $display("  dmem[%0d] = 0x%04X (%0d)", i, dmem[i], $signed(dmem[i]));
        end

        $finish;
    end

    // ── Check Task ───────────────────────────────────────────────────────────
    task check(input string name, input logic [15:0] expected, input logic [15:0] actual);
        if (actual === expected) begin
            pass_count++;
        end else begin
            $display("%s = %0d [FAIL] expected %0d", name, actual, expected);
            error_count++;
        end
    endtask

endmodule

module imem_bram_sim #(
    parameter int WARP_ID = 0
)(
    input  logic        clk,
    input  logic [10:0] addr,
    output logic [15:0] rdata
);
    logic [15:0] mem [0:1023];

    // ============================================================================
    // Warp_tb_nonconcurrent_imem.mem - NOP-free version
    // ============================================================================
    // GPU warp instruction memory - comprehensive non-concurrent feature test
    //
    // Tests: CONST, ADD, SUB, MUL, DIV, STR, LDR, CMP, BRnzp, SYNC, DONE
    //
    // Registers:
    //   r0  = 0 (hardwired)        r1  = LANE_ID (0-15)
    //   r2  = WARP_ID (0)          r3  = const 10
    //   r4  = const 5              r5  = ADD result (15)
    //   r6  = SUB result (5)       r7  = const 3
    //   r8  = MUL result (50)      r9  = DIV result (3)
    //   r10-r13 = address regs     r14-r15 = temporaries
    //
    // Expected DMEM after execution:
    //   [0..15]    = {0,1,2,...,15}    LANE_ID identity
    //   [64..79]   = 15               ADD:  10 + 5
    //   [80..95]   = 5                SUB:  10 - 5
    //   [96..111]  = 50               MUL:  10 × 5
    //   [112..127] = 3                DIV:  10 / 3
    //   [128..143] = 15               LDR readback of [64..79]
    //   [144..153] = 42               Divergent write (lanes 0-9 only)
    //   [154..159] = 0                Masked lanes 10-15 (unwritten)
    //   [160..175] = 7                Post-SYNC reconvergence (all lanes)
    //   [176..191] = {0,1,2,...,15}   Post-SYNC LANE_ID identity (all lanes)
    // ============================================================================

    // Encoding reference:
    // NOP:            0000_xxxx_xxxxxxxx = 0x0000
    // ADD Rd,Rs,Rt:   0011_dddd_ssss_tttt = 0x3DST
    // SUB Rd,Rs,Rt:   0100_dddd_ssss_tttt = 0x4DST
    // MUL Rd,Rs,Rt:   0101_dddd_ssss_tttt = 0x5DST
    // DIV Rd,Rs,Rt:   0110_dddd_ssss_tttt = 0x6DST
    // LDR Rd,Rs:      0111_dddd_ssss_xxxx = 0x7DS0
    // STR Rs,Rt:      1000_xxxx_ssss_tttt = 0x80ST
    // CONST Rd,imm8:  1001_dddd_iiiiiiii = 0x9Dii
    // CMP Rs,Rt:      1010_xxxx_ssss_tttt = 0xA0ST
    // BRnzp off8:     1011_nzp0_oooooooo = 0xBNoo (N=nzp flags)
    // SYNC:           1100_xxxx_xxxxxxxx = 0xC000
    // DONE:           1111_xxxx_xxxxxxxx = 0xF000

    initial begin
        int pc;
        for (int i = 0; i < 1024; i++) mem[i] = 16'h0000; // NOP

        pc = 0;

        // ══════════════════════════════════════════════════════════════════════
        // Section 1: CONST loading
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'h930A; pc++;                    // 0x00: CONST r3, 10
        mem[pc] = 16'h9405; pc++;                    // 0x01: CONST r4, 5
        mem[pc] = 16'h9703; pc++;                    // 0x02: CONST r7, 3

        // ══════════════════════════════════════════════════════════════════════
        // Section 2: Arithmetic
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'h3534; pc++;                    // 0x03: ADD r5, r3, r4  (r5 = 15)
        mem[pc] = 16'h4634; pc++;                    // 0x04: SUB r6, r3, r4  (r6 = 5)
        mem[pc] = 16'h5834; pc++;                    // 0x05: MUL r8, r3, r4  (r8 = 50)
        mem[pc] = 16'h6937; pc++;                    // 0x06: DIV r9, r3, r7  (r9 = 3)

        // ══════════════════════════════════════════════════════════════════════
        // Section 3: LANE_ID identity store
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'h8011; pc++;                    // 0x07: STR -, r1, r1  (mem[LANE_ID] = LANE_ID)

        // ══════════════════════════════════════════════════════════════════════
        // Section 4: Compute addresses & store arithmetic results
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'h9A40; pc++;                    // 0x08: CONST r10, 64
        mem[pc] = 16'h9B50; pc++;                    // 0x09: CONST r11, 80
        mem[pc] = 16'h9C60; pc++;                    // 0x0A: CONST r12, 96
        mem[pc] = 16'h9D70; pc++;                    // 0x0B: CONST r13, 112
        mem[pc] = 16'h3AA1; pc++;                    // 0x0C: ADD r10, r10, r1  (r10 = 64 + LANE_ID)
        mem[pc] = 16'h3BB1; pc++;                    // 0x0D: ADD r11, r11, r1  (r11 = 80 + LANE_ID)
        mem[pc] = 16'h3CC1; pc++;                    // 0x0E: ADD r12, r12, r1  (r12 = 96 + LANE_ID)
        mem[pc] = 16'h3DD1; pc++;                    // 0x0F: ADD r13, r13, r1  (r13 = 112 + LANE_ID)
        mem[pc] = 16'h80A5; pc++;                    // 0x10: STR -, r10, r5  (mem[64+LID] = 15)
        mem[pc] = 16'h80B6; pc++;                    // 0x11: STR -, r11, r6  (mem[80+LID] = 5)
        mem[pc] = 16'h80C8; pc++;                    // 0x12: STR -, r12, r8  (mem[96+LID] = 50)
        mem[pc] = 16'h80D9; pc++;                    // 0x13: STR -, r13, r9  (mem[112+LID] = 3)

        // ══════════════════════════════════════════════════════════════════════
        // Section 5: LDR test - load back ADD result, re-store to [128..143]
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'h7EA0; pc++;                    // 0x14: LDR r14, r10  (r14 = mem[64+LID] = 15)
        mem[pc] = 16'h9A80; pc++;                    // 0x15: CONST r10, 128
        mem[pc] = 16'h3AA1; pc++;                    // 0x16: ADD r10, r10, r1  (r10 = 128 + LANE_ID)
        mem[pc] = 16'h80AE; pc++;                    // 0x17: STR -, r10, r14  (mem[128+LID] = 15)

        // ══════════════════════════════════════════════════════════════════════
        // Section 6: CMP + BRnzp divergence
        // Compare LANE_ID vs 10:
        //   Lanes 0-9  → LANE_ID - 10 < 0  → N flag  → branch taken (active)
        //   Lane  10   → 10 - 10 = 0       → Z flag  → masked
        //   Lanes 11-15→ LANE_ID - 10 > 0  → P flag  → masked
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'h9A90; pc++;                    // 0x18: CONST r10, 144
        mem[pc] = 16'h3AA1; pc++;                    // 0x19: ADD r10, r10, r1  (r10 = 144 + LANE_ID)
        mem[pc] = 16'hA013; pc++;                    // 0x1A: CMP -, r1, r3  (compare LANE_ID vs 10)
        mem[pc] = 16'hB801; pc++;                    // 0x1B: BRn 1  (target = 0x1B + 2 = 0x1D)

        // ══════════════════════════════════════════════════════════════════════
        // Divergent block (lanes 0-9 only)
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'h9B2A; pc++;                    // 0x1D: CONST r11, 42
        mem[pc] = 16'h80AB; pc++;                    // 0x1E: STR -, r10, r11  (mem[144+LID] = 42, lanes 0-9)

        // ══════════════════════════════════════════════════════════════════════
        // Section 7: SYNC - reconverge all 16 lanes
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'hC000; pc++;                    // 0x1F: SYNC

        // ══════════════════════════════════════════════════════════════════════
        // Section 8: Post-SYNC verification - all lanes store constant
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'h9B07; pc++;                    // 0x20: CONST r11, 7
        mem[pc] = 16'h9AA0; pc++;                    // 0x21: CONST r10, 160
        mem[pc] = 16'h3AA1; pc++;                    // 0x22: ADD r10, r10, r1  (r10 = 160 + LANE_ID)
        mem[pc] = 16'h80AB; pc++;                    // 0x23: STR -, r10, r11  (mem[160+LID] = 7)

        // ══════════════════════════════════════════════════════════════════════
        // Section 9: Post-SYNC LANE_ID identity - verify per-lane reconvergence
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'h9AB0; pc++;                    // 0x24: CONST r10, 176
        mem[pc] = 16'h3AA1; pc++;                    // 0x25: ADD r10, r10, r1  (r10 = 176 + LANE_ID)
        mem[pc] = 16'h80A1; pc++;                    // 0x26: STR -, r10, r1  (mem[176+LID] = LANE_ID)

        // ══════════════════════════════════════════════════════════════════════
        // Section 10: Halt
        // ══════════════════════════════════════════════════════════════════════
        mem[pc] = 16'hF000; pc++;                    // 0x27: DONE

        $display("WARP %0d: Program loaded, %0d instructions", WARP_ID, pc);
    end

    always_ff @(posedge clk) begin
        rdata <= mem[addr];
    end
endmodule
