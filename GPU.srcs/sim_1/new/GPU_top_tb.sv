// Engineer: Cole Kaufmann
// Module Name: GPU_top_tb
// Description: Bare-minimum testbench - assert reset, then let it run
//              until all warps are done (or a timeout fires).

`timescale 1ns / 1ps

module GPU_top_tb;

    // ── DUT Signals ──────────────────────────────────────────────────────────
    logic       clk;
    logic       reset;
    logic [3:0] warp_done;

    // ── DUT ──────────────────────────────────────────────────────────────────
    GPU_top dut (
        .clk       (clk),
        .reset     (reset),
        .warp_done (warp_done)
    );

    // ── Clock: 10 ns period ──────────────────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Timeout guard (adjust as needed) ────────────────────────────────────
    localparam int TIMEOUT_CYCLES = 10_000;
    int cycle_count = 0;

    always_ff @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count >= TIMEOUT_CYCLES) begin
            $display("TIMEOUT: simulation reached %0d cycles without all warps finishing.", TIMEOUT_CYCLES);
            $finish;
        end
    end

    // ── Stimulus ─────────────────────────────────────────────────────────────
    initial begin
        // Hold reset for 4 cycles
        reset = 1;
        repeat (4) @(posedge clk);
        @(negedge clk);   // de-assert on falling edge so flops see clean input
        reset = 0;

        $display("Reset de-asserted at time %0t - GPU running.", $time);

        // Wait until all 4 warps signal done
        wait (warp_done == 4'b1111);
        $display("All warps done at time %0t (%0d cycles).", $time, cycle_count);
        $finish;
    end

    // ── Optional: print each warp-done transition ────────────────────────────
    genvar w;
    generate
        for (w = 0; w < 4; w++) begin : warp_done_monitor
            always @(posedge warp_done[w])
                $display("  Warp %0d done at time %0t (cycle %0d).", w, $time, cycle_count);
        end
    endgenerate

endmodule