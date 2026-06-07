`timescale 1ns / 1ps

module warp_controller_tb;

    // ── DUT Signals ──────────────────────────────────────────
    logic        clk;
    logic        rst;
    logic [3:0]  store_requests;
    logic [3:0]  load_requests;
    logic [3:0]  warps_in_mem_queue;
    logic [3:0]  warp_idling;
    logic [3:0]  warp_halt;

    // ── DUT Instantiation ────────────────────────────────────
    warp_controller dut (
        .clk                (clk),
        .rst                (rst),
        .store_requests     (store_requests),
        .load_requests      (load_requests),
        .warps_in_mem_queue (warps_in_mem_queue),
        .warp_idling        (warp_idling),
        .warp_halt          (warp_halt)
    );

    // ── Clock Generation ─────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz

    // ── Helper Task ──────────────────────────────────────────
    task tick(input int n = 1);
        repeat(n) @(posedge clk);
        #1;
    endtask

    // ── Test Sequence ────────────────────────────────────────
    initial begin
        // Initialise all inputs
        rst                 = 1;
        store_requests      = 4'b0000;
        load_requests       = 4'b0000;
        warps_in_mem_queue  = 4'b0000;
        warp_idling         = 4'b0000;

        // ── Test 1: Reset behaviour ──────────────────────────
        $display("TEST 1: Reset - expect warp_halt = 4'b1111");
        tick(3);
        rst = 0;
        tick(1);
        assert (warp_halt == 4'b1111)
            else $error("FAIL: warp_halt = %b, expected 1111", warp_halt);

        // ── Test 2: Come out of reset, warp 0 should run ─────
        $display("TEST 2: No warps busy - expect WARP0 (halt = 1110)");
        tick(1);
        assert (warp_halt == 4'b1110)
            else $error("FAIL: warp_halt = %b, expected 1110", warp_halt);

        // ── Test 3: Warp 0 store request → switch ────────────
        $display("TEST 3: Warp 0 store request - expect WARP1 (halt = 1101)");
        store_requests     = 4'b0001;
        warps_in_mem_queue = 4'b0001;
        tick(1);
        store_requests = 4'b0000;
        tick(1);
        assert (warp_halt == 4'b1101)
            else $error("FAIL: warp_halt = %b, expected 1101", warp_halt);

        // ── Test 4: Warp 1 load request → switch ─────────────
        $display("TEST 4: Warp 1 load request - expect WARP2 (halt = 1011)");
        load_requests      = 4'b0010;
        warps_in_mem_queue = 4'b0011;
        tick(1);
        load_requests = 4'b0000;
        tick(1);
        assert (warp_halt == 4'b1011)
            else $error("FAIL: warp_halt = %b, expected 1011", warp_halt);

        // ── Test 5: All warps busy → FULL_HALT ───────────────
        $display("TEST 5: All warps busy - expect FULL_HALT (halt = 1111)");
        warps_in_mem_queue = 4'b1111;
        tick(1);
        assert (warp_halt == 4'b1111)
            else $error("FAIL: warp_halt = %b, expected 1111", warp_halt);

        // ── Test 6: Warp 3 becomes available ────────────────
        $display("TEST 6: Warp 3 free - expect WARP3 (halt = 0111)");
        warps_in_mem_queue = 4'b0111;
        tick(1);
        assert (warp_halt == 4'b0111)
            else $error("FAIL: warp_halt = %b, expected 0111", warp_halt);

        // ── Test 7: Idling warp should NOT be scheduled ─────
        $display("TEST 7: Warp 3 idling - expect switch away");
        warp_idling = 4'b1000; // warp 3 idle → considered busy
        tick(1);
        assert (warp_halt != 4'b0111)
            else $error("FAIL: Warp 3 was scheduled while idling");

        warp_idling = 4'b0000;

        // ── Test 8: Reset mid operation ─────────────────────
        $display("TEST 8: Mid-operation reset - expect FULL_HALT");
        rst = 1;
        tick(2);
        assert (warp_halt == 4'b1111)
            else $error("FAIL: warp_halt = %b, expected 1111", warp_halt);
        rst = 0;

        $display("All tests complete");
        $finish;
    end

    // ── Timeout watchdog ─────────────────────────────────────
    initial begin
        #10000;
        $error("TIMEOUT - simulation hung");
        $finish;
    end

endmodule