`timescale 1ns / 1ps

// Testbench for warp_controller
//
// The controller implements round-robin scheduling across 4 warps.
// - alu_req[i] = 1 means warp i wants ALU access
// - alu_access is one-hot indicating which warp has access
// - From current warp, priority goes to next warp in round-robin order
// - FULL_HALT when no warps requesting

module warp_controller_tb;

    // -- DUT Signals --
    logic        clk;
    logic        rst;
    logic [3:0]  alu_req;
    logic [3:0]  alu_access;

    // -- Test Statistics --
    int test_num = 0;
    int pass_count = 0;
    int fail_count = 0;

    // -- DUT Instantiation --
    warp_controller dut (
        .clk        (clk),
        .rst        (rst),
        .alu_req    (alu_req),
        .alu_access (alu_access)
    );

    // -- Clock Generation --
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz

    // -- Helper Tasks --
    task automatic tick(input int n = 1);
        repeat(n) @(posedge clk);
        #1;
    endtask

    task automatic check(input string name, input logic [3:0] expected);
        test_num++;
        if (alu_access === expected) begin
            $display("  PASS  TEST %0d: %s (alu_access=%b)", test_num, name, alu_access);
            pass_count++;
        end else begin
            $display("  FAIL  TEST %0d: %s (alu_access=%b, expected=%b)", 
                     test_num, name, alu_access, expected);
            fail_count++;
        end
    endtask

    // -- Test Sequence --
    initial begin
        $display("\n===========================================");
        $display(" WARP CONTROLLER TESTBENCH");
        $display("===========================================\n");

        // Initialize
        rst = 1;
        alu_req = 4'b0000;

        // -------------------------------------------------
        // TEST: Reset behavior
        // -------------------------------------------------
        $display("-- Reset Behavior --");
        tick(3);
        check("During reset, no access", 4'b0000);
        
        rst = 0;
        tick(1);
        check("After reset, no request -> no access", 4'b0000);

        // -------------------------------------------------
        // TEST: Single warp requesting from FULL_HALT
        // -------------------------------------------------
        $display("\n-- Single Warp Request from FULL_HALT --");
        
        alu_req = 4'b0001;  // Warp 0 requests
        tick(1);
        check("Warp 0 requests -> warp 0 access", 4'b0001);
        
        alu_req = 4'b0000;
        tick(1);
        check("No requests -> FULL_HALT", 4'b0000);
        
        alu_req = 4'b0010;  // Warp 1 requests
        tick(1);
        check("Warp 1 requests -> warp 1 access", 4'b0010);
        
        alu_req = 4'b0000;
        tick(1);
        
        alu_req = 4'b0100;  // Warp 2 requests
        tick(1);
        check("Warp 2 requests -> warp 2 access", 4'b0100);
        
        alu_req = 4'b0000;
        tick(1);
        
        alu_req = 4'b1000;  // Warp 3 requests
        tick(1);
        check("Warp 3 requests -> warp 3 access", 4'b1000);
        
        alu_req = 4'b0000;
        tick(1);

        // -------------------------------------------------
        // TEST: Round-robin from WARP0
        // -------------------------------------------------
        $display("\n-- Round-Robin from WARP0 --");
        
        // Get to WARP0 state
        alu_req = 4'b0001;
        tick(1);
        check("Setup: in WARP0", 4'b0001);
        
        // From WARP0: priority is 1 > 2 > 3 > 0
        alu_req = 4'b0011;  // Warps 0,1 request
        tick(1);
        check("WARP0 + req 0,1 -> warp 1 (next in RR)", 4'b0010);
        
        // Back to WARP0
        alu_req = 4'b0001;
        tick(2);
        
        alu_req = 4'b0101;  // Warps 0,2 request
        tick(1);
        check("WARP0 + req 0,2 -> warp 2", 4'b0100);
        
        // Back to WARP0
        alu_req = 4'b0001;
        tick(2);
        
        alu_req = 4'b1001;  // Warps 0,3 request
        tick(1);
        check("WARP0 + req 0,3 -> warp 3", 4'b1000);

        // -------------------------------------------------
        // TEST: Round-robin from WARP1
        // -------------------------------------------------
        $display("\n-- Round-Robin from WARP1 --");
        
        // Get to WARP1 state
        alu_req = 4'b0010;
        tick(2);
        check("Setup: in WARP1", 4'b0010);
        
        // From WARP1: priority is 2 > 3 > 0 > 1
        alu_req = 4'b0110;  // Warps 1,2 request
        tick(1);
        check("WARP1 + req 1,2 -> warp 2", 4'b0100);
        
        // Back to WARP1
        alu_req = 4'b0010;
        tick(2);
        
        alu_req = 4'b1010;  // Warps 1,3 request
        tick(1);
        check("WARP1 + req 1,3 -> warp 3", 4'b1000);
        
        // Back to WARP1
        alu_req = 4'b0010;
        tick(2);
        
        alu_req = 4'b0011;  // Warps 0,1 request
        tick(1);
        check("WARP1 + req 0,1 -> warp 0", 4'b0001);

        // -------------------------------------------------
        // TEST: Round-robin from WARP2
        // -------------------------------------------------
        $display("\n-- Round-Robin from WARP2 --");
        
        // Get to WARP2 state
        alu_req = 4'b0100;
        tick(2);
        check("Setup: in WARP2", 4'b0100);
        
        // From WARP2: priority is 3 > 0 > 1 > 2
        alu_req = 4'b1100;  // Warps 2,3 request
        tick(1);
        check("WARP2 + req 2,3 -> warp 3", 4'b1000);
        
        // Back to WARP2
        alu_req = 4'b0100;
        tick(2);
        
        alu_req = 4'b0101;  // Warps 0,2 request
        tick(1);
        check("WARP2 + req 0,2 -> warp 0", 4'b0001);
        
        // Back to WARP2
        alu_req = 4'b0100;
        tick(2);
        
        alu_req = 4'b0110;  // Warps 1,2 request
        tick(1);
        check("WARP2 + req 1,2 -> warp 1", 4'b0010);

        // -------------------------------------------------
        // TEST: Round-robin from WARP3
        // -------------------------------------------------
        $display("\n-- Round-Robin from WARP3 --");
        
        // Get to WARP3 state
        alu_req = 4'b1000;
        tick(2);
        check("Setup: in WARP3", 4'b1000);
        
        // From WARP3: priority is 0 > 1 > 2 > 3
        alu_req = 4'b1001;  // Warps 0,3 request
        tick(1);
        check("WARP3 + req 0,3 -> warp 0", 4'b0001);
        
        // Back to WARP3
        alu_req = 4'b1000;
        tick(2);
        
        alu_req = 4'b1010;  // Warps 1,3 request
        tick(1);
        check("WARP3 + req 1,3 -> warp 1", 4'b0010);
        
        // Back to WARP3
        alu_req = 4'b1000;
        tick(2);
        
        alu_req = 4'b1100;  // Warps 2,3 request
        tick(1);
        check("WARP3 + req 2,3 -> warp 2", 4'b0100);

        // -------------------------------------------------
        // TEST: All warps requesting - full round-robin cycle
        // -------------------------------------------------
        $display("\n-- Full Round-Robin Cycle (all requesting) --");
        
        alu_req = 4'b1111;  // All warps request
        
        // Start from FULL_HALT
        rst = 1;
        tick(1);
        rst = 0;
        tick(1);
        check("All req from HALT -> warp 0", 4'b0001);
        
        tick(1);
        check("All req from WARP0 -> warp 1", 4'b0010);
        
        tick(1);
        check("All req from WARP1 -> warp 2", 4'b0100);
        
        tick(1);
        check("All req from WARP2 -> warp 3", 4'b1000);
        
        tick(1);
        check("All req from WARP3 -> warp 0", 4'b0001);
        
        tick(1);
        check("Cycle continues -> warp 1", 4'b0010);

        // -------------------------------------------------
        // TEST: Warp drops request mid-cycle
        // -------------------------------------------------
        $display("\n-- Request Drop Mid-Cycle --");
        
        alu_req = 4'b1111;
        tick(4);  // Get to known state
        
        // Assume we're at warp 1, drop warp 2's request
        alu_req = 4'b1011;  // Warp 2 stops requesting
        tick(1);
        check("Warp 2 dropped -> skip to warp 3", 4'b1000);
        
        tick(1);
        check("Continue RR -> warp 0", 4'b0001);

        // -------------------------------------------------
        // TEST: Only current warp requesting (stays)
        // -------------------------------------------------
        $display("\n-- Only Current Warp Requesting --");
        
        // Get to WARP2
        alu_req = 4'b0100;
        tick(2);
        check("Setup: in WARP2", 4'b0100);
        
        // Only warp 2 keeps requesting
        tick(1);
        check("Only warp 2 requesting -> stays", 4'b0100);
        
        tick(1);
        check("Still only warp 2 -> stays", 4'b0100);

        // -------------------------------------------------
        // TEST: Request appears then disappears
        // -------------------------------------------------
        $display("\n-- Transient Requests --");
        
        alu_req = 4'b0000;
        tick(1);
        check("No requests -> FULL_HALT", 4'b0000);
        
        // Brief request
        alu_req = 4'b0100;
        tick(1);
        check("Warp 2 requests -> access", 4'b0100);
        
        alu_req = 4'b0000;
        tick(1);
        check("Request gone -> FULL_HALT", 4'b0000);

        // -------------------------------------------------
        // TEST: Reset during operation
        // -------------------------------------------------
        $display("\n-- Reset During Operation --");
        
        alu_req = 4'b1111;
        tick(3);
        
        rst = 1;
        tick(1);
        check("Reset asserted -> no access", 4'b0000);
        
        tick(1);
        check("Still in reset -> no access", 4'b0000);
        
        rst = 0;
        tick(1);
        check("Reset released, all req -> warp 0", 4'b0001);

        // -------------------------------------------------
        // TEST: FULL_HALT priority (0 > 1 > 2 > 3)
        // -------------------------------------------------
        $display("\n-- FULL_HALT Priority --");
        
        alu_req = 4'b0000;
        tick(1);
        
        alu_req = 4'b1100;  // Warps 2,3 request
        tick(1);
        check("HALT + req 2,3 -> warp 2 (lower index)", 4'b0100);
        
        alu_req = 4'b0000;
        tick(1);
        
        alu_req = 4'b1010;  // Warps 1,3 request
        tick(1);
        check("HALT + req 1,3 -> warp 1", 4'b0010);
        
        alu_req = 4'b0000;
        tick(1);
        
        alu_req = 4'b1110;  // Warps 1,2,3 request
        tick(1);
        check("HALT + req 1,2,3 -> warp 1", 4'b0010);

        // -------------------------------------------------
        // TEST: Rapid toggling
        // -------------------------------------------------
        $display("\n-- Rapid Request Toggling --");
        
        for (int i = 0; i < 8; i++) begin
            alu_req = 4'(i);
            tick(1);
        end
        
        alu_req = 4'b1111;
        tick(1);
        // Just verify it doesn't hang - state is deterministic but complex
        $display("  INFO  Rapid toggling complete, alu_access=%b", alu_access);

        // -------------------------------------------------
        // Summary
        // -------------------------------------------------

        $display("\n===========================================");
        $display(" RESULTS: %0d passed, %0d failed out of %0d tests", 
                 pass_count, fail_count, test_num);
        if (fail_count == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" SOME TESTS FAILED");
        $display("===========================================\n");

        $finish;
    end

    // -- Timeout watchdog --
    initial begin
        #50000;
        $display("\n  TIMEOUT - simulation exceeded time limit");
        $display(" %0d passed, %0d failed before timeout", pass_count, fail_count);
        $finish;
    end

endmodule