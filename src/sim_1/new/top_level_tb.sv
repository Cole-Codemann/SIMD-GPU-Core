// Engineer: Cole Kaufmann
// Create Date: 06/01/2026
// Module Name: top_level_tb
//
// Smoke test for top_level. Verifies that GPU_done asserts within a
// reasonable cycle window after reset. Instruction memories preload from
// rom_setN.mem via the imem_bram instances inside top_level; data memory
// preloads from dmem_init.mem via the dmem_bram instance.
//
// No DUT-external signals - the wrapper closes over all memory, so this
// testbench just drives clock + reset and watches GPU_done.

`timescale 1ns / 1ps

module top_level_tb;

    // ── Parameters ───────────────────────────────────────────────────────────
    localparam int CLK_PERIOD_NS  = 10;       // 100 MHz
    localparam int RESET_CYCLES   = 4;        // matches prior testbench
    localparam int TIMEOUT_CYCLES = 10_000;   // matches prior testbench

    // ── DUT signals ──────────────────────────────────────────────────────────
    logic clk;
    logic reset;
    logic GPU_done;

    // ── DUT ──────────────────────────────────────────────────────────────────
    top_level dut (
        .clk      (clk),
        .reset    (reset),
        .GPU_done (GPU_done)
    );

    // ── Clock ────────────────────────────────────────────────────────────────
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;

    // ── Cycle counter (for timeout + reporting) ──────────────────────────────
    int unsigned cycle_count;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) cycle_count <= '0;
        else       cycle_count <= cycle_count + 1;
    end

    // ── Stimulus + check ─────────────────────────────────────────────────────
    initial begin
        $display("[%0t] top_level smoke test starting", $time);
        $display("       clock period = %0d ns (%0d MHz)",
                 CLK_PERIOD_NS, 1000/CLK_PERIOD_NS);
        $display("       reset cycles = %0d", RESET_CYCLES);
        $display("       timeout      = %0d cycles", TIMEOUT_CYCLES);

        // Reset assertion
        reset = 1'b1;
        repeat (RESET_CYCLES) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        $display("[%0t] reset released, cycle %0d", $time, cycle_count);

        // Wait for done or timeout, whichever comes first
        fork
            begin : wait_done
                @(posedge GPU_done);
                $display("[%0t] PASS: GPU_done asserted at cycle %0d",
                         $time, cycle_count);
                disable timeout;
            end
            begin : timeout
                repeat (TIMEOUT_CYCLES) @(posedge clk);
                $display("[%0t] FAIL: timeout after %0d cycles, GPU_done = %0b",
                         $time, TIMEOUT_CYCLES, GPU_done);
                disable wait_done;
            end
        join

        // Hold a few extra cycles so any post-done activity is visible
        repeat (10) @(posedge clk);

        $display("[%0t] simulation complete, final cycle = %0d",
                 $time, cycle_count);
        $finish;
    end

endmodule