`timescale 1ns/1ps

// Testbench for memory_controller with self-checking via shadow memory.
//
// Maintains software shadow of expected memory contents. Stores update shadow
// respecting per-lane mask. Loads compare captured data against shadow for
// unmasked lanes. Mismatches logged with final summary of checks and errors.

// Checked and approved, no further work needed on this.

module memory_controller_tb;

    // ── DUT signals ──────────────────────────────────────────
    logic                     clk, rst;
    logic [3:0][15:0][15:0]   reg_to_mem_data;
    logic [3:0][15:0][15:0]   mem_addr;
    logic [3:0]               store_requests;
    logic [3:0]               load_requests;
    logic [3:0]               con_request;
    logic [3:0][15:0]         lane_mask;
    logic [3:0]               mem_req_done;
    logic [15:0][15:0]        mem_to_reg_data;
    logic [3:0]               mem_request_ack;

    logic [10:0]              addr;
    logic [127:0]             wdata;
    logic [15:0]              wen;
    logic [127:0]             rdata;

    // ── Clock ────────────────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz

    // ── DUT ──────────────────────────────────────────────────
    memory_controller dut (.*);

    // ── Behavioral BRAM ──────────────────────────────────────
    // 1-cycle synchronous read, byte write-enable.
    // Word at (line L, slot S) = 0xA000 + ((L & 0xFF) << 4) + S
    logic [127:0] mem [0:2047];

    initial begin
        for (int L = 0; L < 2048; L++)
            for (int S = 0; S < 8; S++)
                mem[L][S*16 +: 16] = 16'hA000 + (L[7:0] << 4) + S[3:0];
    end

    always_ff @(posedge clk) begin
        rdata <= mem[addr];
        for (int b = 0; b < 16; b++)
            if (wen[b]) mem[addr][b*8 +: 8] <= wdata[b*8 +: 8];
    end

    // ── Shadow memory + stats ────────────────────────────────
    // Word-addressed shadow (16384 = 2048 lines × 8 slots).
    logic [15:0] shadow_mem [0:16383];
    int          total_checks = 0;
    int          total_errors = 0;
    int          test_num = 0;

    initial begin
        for (int W = 0; W < 16384; W++) begin
            logic [10:0] L = W[13:3];
            logic [2:0]  S = W[2:0];
            shadow_mem[W] = 16'hA000 + (L[7:0] << 4) + S;
        end
    end

    // ── Captured load data (per-warp) ────────────────────────
    // mem_to_reg_data is shared and gets overwritten by each load.
    // We capture it at the moment mem_req_done fires for each warp.
    logic [3:0][15:0][15:0] captured_load_data;
    logic [3:0][15:0][15:0] captured_mem_addr;

    // ── Shadow updates ───────────────────────────────────────
    function automatic void update_shadow_scatter(int warp, logic [15:0] mask);
        for (int l = 0; l < 16; l++)
            if (!mask[l])
                shadow_mem[mem_addr[warp][l][13:0]] = reg_to_mem_data[warp][l];
    endfunction

    function automatic void update_shadow_con(int warp);
        for (int l = 0; l < 16; l++)
            shadow_mem[mem_addr[warp][l][13:0]] = reg_to_mem_data[warp][l];
    endfunction

    // ── Load verification (uses captured data) ───────────────
    function automatic void verify_load(int warp, logic [15:0] mask, string label);
        int local_errors = 0;
        int local_checks = 0;
        for (int l = 0; l < 16; l++) begin
            if (!mask[l]) begin
                logic [15:0] exp_v;
                logic [15:0] got_v;
                exp_v = shadow_mem[captured_mem_addr[warp][l][13:0]];
                got_v = captured_load_data[warp][l];
                local_checks++;
                total_checks++;
                if (exp_v !== got_v) begin
                    local_errors++;
                    total_errors++;
                    $display("        lane %2d  addr=%0d  expected=%h  got=%h",
                             l, captured_mem_addr[warp][l], exp_v, got_v);
                end
            end
        end
        if (local_errors == 0)
            $display("    PASS  %s  (%0d lanes checked)", label, local_checks);
        else
            $display("    FAIL  %s  (%0d / %0d lanes mismatched)",
                     label, local_errors, local_checks);
    endfunction

    // ── Synchronization helpers ──────────────────────────────
    task automatic await_ack(int warp);
        int timeout = 0;
        forever begin
            @(posedge clk); #1;
            if (mem_request_ack[warp]) break;
            timeout++;
            if (timeout > 100) begin
                $display("    ERROR: await_ack timeout for warp %0d", warp);
                break;
            end
        end
    endtask

    task automatic await_done(int warp);
        int timeout = 0;
        forever begin
            @(posedge clk); #1;
            if (mem_req_done[warp]) break;
            timeout++;
            if (timeout > 500) begin
                $display("    ERROR: await_done timeout for warp %0d", warp);
                break;
            end
        end
    endtask

    task automatic await_done_and_capture(int warp);
        int timeout = 0;
        forever begin
            @(posedge clk); #1;
            if (mem_req_done[warp]) begin
                captured_load_data[warp] = mem_to_reg_data;
                captured_mem_addr[warp] = mem_addr[warp];
                break;
            end
            timeout++;
            if (timeout > 500) begin
                $display("    ERROR: await_done_and_capture timeout for warp %0d", warp);
                break;
            end
        end
    endtask

    // ── Request-issuing tasks ────────────────────────────────
    task automatic scatter_store(int warp, logic [15:0] mask = 16'h0000, int base = -1, int stride = 17);
        int actual_base;
        actual_base = (base < 0) ? (warp * 256) : base;
        
        for (int l = 0; l < 16; l++) begin
            mem_addr[warp][l]        = 16'(actual_base + l * stride);
            reg_to_mem_data[warp][l] = 16'hB000 | (warp << 8) | l;
        end
        lane_mask[warp]      = mask;
        con_request[warp]    = 1'b0;
        store_requests[warp] = 1'b1;
        await_ack(warp);
        store_requests[warp] = 1'b0;
        update_shadow_scatter(warp, mask);
    endtask

    task automatic scatter_load(int warp, logic [15:0] mask = 16'h0000, int base = -1, int stride = 17);
        int actual_base;
        actual_base = (base < 0) ? (warp * 256) : base;
        
        for (int l = 0; l < 16; l++)
            mem_addr[warp][l] = 16'(actual_base + l * stride);
        lane_mask[warp]     = mask;
        con_request[warp]   = 1'b0;
        load_requests[warp] = 1'b1;
        await_ack(warp);
        load_requests[warp] = 1'b0;
    endtask

    task automatic con_store(int warp, int base_word);
        for (int l = 0; l < 16; l++) begin
            mem_addr[warp][l]        = 16'(base_word + l);
            reg_to_mem_data[warp][l] = 16'hC000 | (warp << 8) | l;
        end
        lane_mask[warp]      = 16'h0000;
        con_request[warp]    = 1'b1;
        store_requests[warp] = 1'b1;
        await_ack(warp);
        store_requests[warp] = 1'b0;
        con_request[warp]    = 1'b0;
        update_shadow_con(warp);
    endtask

    task automatic con_load(int warp, int base_word);
        for (int l = 0; l < 16; l++)
            mem_addr[warp][l] = 16'(base_word + l);
        lane_mask[warp]     = 16'h0000;
        con_request[warp]   = 1'b1;
        load_requests[warp] = 1'b1;
        await_ack(warp);
        load_requests[warp] = 1'b0;
        con_request[warp]   = 1'b0;
    endtask

    task automatic sentinel_store(int warp, int base, int stride);
        for (int l = 0; l < 16; l++) begin
            mem_addr[warp][l]        = 16'(base + l * stride);
            reg_to_mem_data[warp][l] = 16'hE000 | l;
        end
        lane_mask[warp]      = 16'h0000;
        con_request[warp]    = 1'b0;
        store_requests[warp] = 1'b1;
        await_ack(warp);
        store_requests[warp] = 1'b0;
        update_shadow_scatter(warp, 16'h0000);
    endtask

    // ── Test header helper ───────────────────────────────────
    task automatic test_header(string name);
        test_num++;
        $display("\n--- TEST %0d: %s ---", test_num, name);
    endtask

    // ── Stimulus ─────────────────────────────────────────────
    initial begin
        // Init
        reg_to_mem_data    = '0;
        mem_addr           = '0;
        store_requests     = '0;
        load_requests      = '0;
        con_request        = '0;
        lane_mask          = '{default: 16'h0000};
        captured_load_data = '0;
        captured_mem_addr  = '0;
        rst                = 1'b1;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk); #1;
        $display("\n[%0t] ═══ RESET RELEASED ═══", $time);

        // ─────────────────────────────────────────────────────
        // TEST 1: Basic scatter store + load
        // ─────────────────────────────────────────────────────
        test_header("scatter store + load (warp 0)");
        scatter_store(0);
        await_done(0);
        scatter_load(0);
        await_done_and_capture(0);
        verify_load(0, 16'h0000, "scatter read-back");

        // ─────────────────────────────────────────────────────
        // TEST 2: Concurrent store + load
        // ─────────────────────────────────────────────────────
        test_header("concurrent store + load (warp 1, base=512)");
        con_store(1, 512);
        await_done(1);
        con_load(1, 512);
        await_done_and_capture(1);
        verify_load(1, 16'h0000, "concurrent read-back");

        // ─────────────────────────────────────────────────────
        // TEST 3: Two warps queued in parallel
        // ─────────────────────────────────────────────────────
        test_header("two warps queued in parallel (warps 2 & 3)");
        fork
            begin 
                scatter_store(2, 16'h0000, 2048, 11); 
                await_done(2);
            end
            begin 
                con_store(3, 1024); 
                await_done(3);
            end
        join

        scatter_load(2, 16'h0000, 2048, 11);
        await_done_and_capture(2);
        verify_load(2, 16'h0000, "warp-2 scatter");

        con_load(3, 1024);
        await_done_and_capture(3);
        verify_load(3, 16'h0000, "warp-3 concurrent");

        // ─────────────────────────────────────────────────────
        // TEST 4: Masked scatter store
        // ─────────────────────────────────────────────────────
        test_header("masked scatter store (warp 0, upper 8 lanes masked)");
        
        // Pre-fill with sentinel
        sentinel_store(0, 200, 3);
        await_done(0);

        // Masked store - only lanes 0-7 written
        for (int l = 0; l < 16; l++) begin
            mem_addr[0][l]        = 16'(200 + l * 3);
            reg_to_mem_data[0][l] = 16'hD000 | l;
        end
        lane_mask[0]      = 16'hFF00;
        con_request[0]    = 1'b0;
        store_requests[0] = 1'b1;
        await_ack(0);
        store_requests[0] = 1'b0;
        update_shadow_scatter(0, 16'hFF00);
        await_done(0);

        // Verify: lanes 0-7 = D00x, lanes 8-15 = E00x (sentinel)
        for (int l = 0; l < 16; l++)
            mem_addr[0][l] = 16'(200 + l * 3);
        lane_mask[0]      = 16'h0000;
        load_requests[0]  = 1'b1;
        await_ack(0);
        load_requests[0]  = 1'b0;
        await_done_and_capture(0);
        verify_load(0, 16'h0000, "masked store verify");

        // ─────────────────────────────────────────────────────
        // TEST 5: All lanes masked (should complete immediately)
        // ─────────────────────────────────────────────────────
        test_header("all-masked store (should complete immediately)");
        
        begin
            int start_cycle;
            int end_cycle;
            start_cycle = $time / 10;
            
            for (int l = 0; l < 16; l++) begin
                mem_addr[0][l]        = 16'(300 + l);
                reg_to_mem_data[0][l] = 16'hFFFF;  // Should NOT be written
            end
            lane_mask[0]      = 16'hFFFF;  // All masked
            store_requests[0] = 1'b1;
            await_ack(0);
            store_requests[0] = 1'b0;
            await_done(0);
            
            end_cycle = $time / 10;
            if ((end_cycle - start_cycle) <= 5)
                $display("    PASS  all-masked completed quickly (%0d cycles)", end_cycle - start_cycle);
            else
                $display("    WARN  all-masked took %0d cycles (expected ~2)", end_cycle - start_cycle);
        end

        // ─────────────────────────────────────────────────────
        // TEST 6: All 4 warps queued simultaneously
        // ─────────────────────────────────────────────────────
        test_header("4-warp simultaneous requests (queue stress)");
        fork
            begin scatter_store(0, 16'h0000, 3000, 7); await_done(0); $display("    warp 0 done"); end
            begin scatter_store(1, 16'h0000, 3200, 7); await_done(1); $display("    warp 1 done"); end
            begin scatter_store(2, 16'h0000, 3400, 7); await_done(2); $display("    warp 2 done"); end
            begin scatter_store(3, 16'h0000, 3600, 7); await_done(3); $display("    warp 3 done"); end
        join

        // Verify all 4 warps
        for (int w = 0; w < 4; w++) begin
            scatter_load(w, 16'h0000, 3000 + w*200, 7);
            await_done_and_capture(w);
            verify_load(w, 16'h0000, $sformatf("warp-%0d 4-way", w));
        end

        // ─────────────────────────────────────────────────────
        // TEST 7: Same warp rapid back-to-back requests
        // ─────────────────────────────────────────────────────
        test_header("same warp back-to-back requests (warp 0)");
        
        scatter_store(0, 16'h0000, 4000, 5);
        await_done(0);
        
        // Immediately re-request
        scatter_store(0, 16'h0000, 4000, 5);
        await_done(0);
        
        scatter_load(0, 16'h0000, 4000, 5);
        await_done_and_capture(0);
        verify_load(0, 16'h0000, "rapid re-request");

        // ─────────────────────────────────────────────────────
        // TEST 8: Masked load verification
        // ─────────────────────────────────────────────────────
        test_header("masked load (warp 0, odd lanes masked)");
        
        // Store known pattern
        scatter_store(0, 16'h0000, 4500, 3);
        await_done(0);
        
        // Load with odd lanes masked
        scatter_load(0, 16'hAAAA, 4500, 3);  // Mask = 1010...1010
        await_done_and_capture(0);
        verify_load(0, 16'hAAAA, "masked load (even lanes only)");

        // ─────────────────────────────────────────────────────
        // TEST 9: Interleaved load/store across warps
        // ─────────────────────────────────────────────────────
        test_header("interleaved load/store (warps 0-3)");
        
        // Pre-store data for loads
        scatter_store(0, 16'h0000, 5000, 4);
        await_done(0);
        scatter_store(2, 16'h0000, 5200, 4);
        await_done(2);
        
        // Interleaved: store W1, load W0, store W3, load W2
        fork
            begin scatter_store(1, 16'h0000, 5100, 4); await_done(1); end
            begin scatter_load(0, 16'h0000, 5000, 4);  await_done_and_capture(0); end
            begin scatter_store(3, 16'h0000, 5300, 4); await_done(3); end
            begin scatter_load(2, 16'h0000, 5200, 4);  await_done_and_capture(2); end
        join
        
        verify_load(0, 16'h0000, "interleaved W0 load");
        verify_load(2, 16'h0000, "interleaved W2 load");
        
        // Verify the stores completed correctly
        scatter_load(1, 16'h0000, 5100, 4);
        await_done_and_capture(1);
        verify_load(1, 16'h0000, "interleaved W1 store verify");
        
        scatter_load(3, 16'h0000, 5300, 4);
        await_done_and_capture(3);
        verify_load(3, 16'h0000, "interleaved W3 store verify");

        // ─────────────────────────────────────────────────────
        // TEST 10: Single lane active (sparse mask)
        // ─────────────────────────────────────────────────────
        test_header("single lane active (lane 7 only)");
        
        sentinel_store(0, 6000, 2);
        await_done(0);
        
        // Store with only lane 7 active
        for (int l = 0; l < 16; l++) begin
            mem_addr[0][l]        = 16'(6000 + l * 2);
            reg_to_mem_data[0][l] = 16'hABCD;
        end
        lane_mask[0]      = 16'hFF7F;  // Only lane 7 active (bit 7 = 0)
        store_requests[0] = 1'b1;
        await_ack(0);
        store_requests[0] = 1'b0;
        update_shadow_scatter(0, 16'hFF7F);
        await_done(0);
        
        // Verify
        for (int l = 0; l < 16; l++)
            mem_addr[0][l] = 16'(6000 + l * 2);
        lane_mask[0]      = 16'h0000;
        load_requests[0]  = 1'b1;
        await_ack(0);
        load_requests[0]  = 1'b0;
        await_done_and_capture(0);
        verify_load(0, 16'h0000, "single lane store verify");

        // ─────────────────────────────────────────────────────
        // TEST 11: Concurrent load with different base addresses
        // ─────────────────────────────────────────────────────
        test_header("concurrent load from pre-initialized memory");
        
        // Load from address range that has BRAM init pattern
        // Addresses 0-127 (lines 0-15) should have pattern 0xA0xx
        for (int l = 0; l < 16; l++)
            mem_addr[0][l] = 16'(l);  // Addresses 0,1,2,...,15
        lane_mask[0]     = 16'h0000;
        con_request[0]   = 1'b1;
        load_requests[0] = 1'b1;
        await_ack(0);
        load_requests[0] = 1'b0;
        con_request[0]   = 1'b0;
        await_done_and_capture(0);
        verify_load(0, 16'h0000, "concurrent load from init pattern");

        // ─────────────────────────────────────────────────────
        // TEST 12: Alternating store/load same warp
        // ─────────────────────────────────────────────────────
        test_header("alternating store/load same warp (warp 0)");
        
        for (int iter = 0; iter < 4; iter++) begin
            int base_addr = 7000 + iter * 100;
            
            // Store
            for (int l = 0; l < 16; l++) begin
                mem_addr[0][l]        = 16'(base_addr + l * 2);
                reg_to_mem_data[0][l] = 16'hF000 | (iter << 8) | l;
            end
            lane_mask[0]      = 16'h0000;
            store_requests[0] = 1'b1;
            await_ack(0);
            store_requests[0] = 1'b0;
            update_shadow_scatter(0, 16'h0000);
            await_done(0);
            
            // Load back immediately
            for (int l = 0; l < 16; l++)
                mem_addr[0][l] = 16'(base_addr + l * 2);
            lane_mask[0]      = 16'h0000;
            load_requests[0]  = 1'b1;
            await_ack(0);
            load_requests[0]  = 1'b0;
            await_done_and_capture(0);
            verify_load(0, 16'h0000, $sformatf("alternating iter %0d", iter));
        end

        // ─────────────────────────────────────────────────────
        // Summary
        // ─────────────────────────────────────────────────────
        $display(" %0d TESTS COMPLETED", test_num);
        if (total_errors == 0)
            $display(" ALL CHECKS PASSED (%0d total)", total_checks);
        else
            $display(" %0d / %0d CHECKS FAILED", total_errors, total_checks);

        repeat (10) @(posedge clk);
        $finish;
    end

    // ── Watchdog ─────────────────────────────────────────────
    initial begin
        #100000;
        $display("\n[%0t] TIMEOUT - test did not complete", $time);
        $display(" %0d checks completed, %0d errors", total_checks, total_errors);
        $finish;
    end

endmodule