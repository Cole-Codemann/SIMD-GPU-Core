`timescale 1ns / 1ps

// Comprehensive Control Unit Testbench
// Tests: Instruction decode, mask stack, branch conditions, all opcodes

module cu_tb;

    // =========================================================================
    // Testbench Signals
    // =========================================================================
    
    logic             clk;
    logic             rst;
    logic [15:0]      instr;
    logic [15:0][2:0] nzp_flags;
    
    logic [3:0]       op;
    logic [3:0]       rd;
    logic [3:0]       rs;
    logic [3:0]       rt;
    logic [15:0]      bimm;
    logic [15:0]      mask;
    logic             regwe;
    logic             store_request;
    logic             load_request;
    logic             sel_imm;
    logic             br;
    logic             set_nzp;
    logic             done;
    logic             alu_req_de;
    logic             conc_request;
        
    logic [15:0] expected_masks [0:7];
    logic [15:0] cumulative_mask;
    logic [3:0] sp_before_overflow;
    logic [15:0] mask_before_overflow;
    int expected_sp;
    logic halt;
    
    // Test tracking
    int test_num;
    int error_count;
    int pass_count;
    
    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    
    cu dut (
        .clk           (clk),
        .rst           (rst),
        .halt          (halt),    
        .scoreboard_stall (1'b0),
        .instr         (instr),   
        .nzp_flags     (nzp_flags),
        .op            (op),
        .rd            (rd),
        .rs            (rs),
        .rt            (rt),
        .bimm          (bimm),
        .mask          (mask),
        .regwe         (regwe),
        .store_request (store_request),
        .load_request  (load_request),
        .conc_request  (conc_request),
        .sel_imm       (sel_imm),
        .br            (br),
        .set_nzp       (set_nzp),
        .done          (done),
        .alu_req_de    (alu_req_de)
    );
        
    // =========================================================================
    // Clock Generation (100 MHz = 10ns period)
    // =========================================================================
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // =========================================================================
    // Helper Tasks
    // =========================================================================
    
    // Task: Apply instruction and wait for decode
    task automatic apply_instr(
        input logic [15:0] instruction,
        input string       description = ""
    );
        @(posedge clk);
        instr = instruction;
        @(posedge clk);  // CU samples instruction on this edge
        instr = 16'h0000;  // Clear to NOP immediately
        if (description != "")
            $display("[T=%0t] Applied: %s (instr=%h)", $time, description, instruction);
    endtask
    

    
    // Task: Check signal value
    task automatic check_signal(
        input logic actual,
        input logic expected,
        input string signal_name
    );
        if (actual !== expected) begin
            $error("[TEST %0d] FAIL: %s expected=%b, got=%b", 
                   test_num, signal_name, expected, actual);
            error_count++;
        end else begin
            $display("[TEST %0d] PASS: %s = %b", test_num, signal_name, actual);
            pass_count++;
        end
    endtask
    
    // Task: Check 4-bit value
    task automatic check_value_4bit(
        input logic [3:0] actual,
        input logic [3:0] expected,
        input string signal_name
    );
        if (actual !== expected) begin
            $error("[TEST %0d] FAIL: %s expected=%h, got=%h", 
                   test_num, signal_name, expected, actual);
            error_count++;
        end else begin
            $display("[TEST %0d] PASS: %s = %h", test_num, signal_name, actual);
            pass_count++;
        end
    endtask
    
    // Task: Check 16-bit value
    task automatic check_value_16bit(
        input logic [15:0] actual,
        input logic [15:0] expected,
        input string signal_name
    );
        if (actual !== expected) begin
            $error("[TEST %0d] FAIL: %s expected=%h, got=%h", 
                   test_num, signal_name, expected, actual);
            error_count++;
        end else begin
            $display("[TEST %0d] PASS: %s = %h", test_num, signal_name, actual);
            pass_count++;
        end
    endtask
    
    // Task: Set NZP flags for all lanes
    task automatic set_all_flags(input logic [2:0] flag_value);
        for (int i = 0; i < 16; i++) begin
            nzp_flags[i] = flag_value;
        end
    endtask
    
    // Task: Set NZP flags for specific lane
    task automatic set_lane_flag(input int lane, input logic [2:0] flag_value);
        nzp_flags[lane] = flag_value;
    endtask
    
    // Task: Print test header
    task automatic print_header(input string test_name);
        $display("");
        $display("================================================================================");
        $display("TEST %0d: %s", test_num, test_name);
        $display("================================================================================");
        test_num++;
    endtask
    
    // Task: Wait cycles
    task automatic wait_cycles(input int num);
        repeat(num) @(posedge clk);
    endtask
    
    // =========================================================================
    // Test Stimulus
    // =========================================================================
    
    initial begin
        // Initialize
        rst = 1;
        instr = 16'h0000;
        nzp_flags = '{default: 3'b010};  // All zero initially
        test_num = 1;
        halt = 0;
        error_count = 0;
        pass_count = 0;
        
        $display("");
        $display("================================================================================");
        $display("CONTROL UNIT TESTBENCH - Comprehensive Verification");
        $display("================================================================================");
        $display("");
        
        // Reset
        repeat(3) @(posedge clk);
        rst = 0;
        @(posedge clk);
        
        // =====================================================================
        // TEST 1: NOP Instruction
        // =====================================================================
        print_header("NOP Instruction (0x0000)");
        
        apply_instr(16'h0000, "NOP");
        
        check_value_4bit(op, 4'h0, "op");
        check_signal(regwe, 1'b0, "regwe");
        check_signal(alu_req_de, 1'b0, "alu_req_de");
        check_signal(br, 1'b0, "br");
        check_signal(done, 1'b0, "done");
        
        // =====================================================================
        // TEST 2: ADD Instruction
        // =====================================================================
        print_header("ADD Instruction (R5 = R3 + R2)");
        
        // Opcode=0011, Rd=5, Rs=3, Rt=2
        apply_instr(16'h3532, "ADD R5, R3, R2");
        
        check_value_4bit(op, 4'h3, "op");
        check_value_4bit(rd, 4'h5, "rd");
        check_value_4bit(rs, 4'h3, "rs");
        check_value_4bit(rt, 4'h2, "rt");
        check_signal(regwe, 1'b1, "regwe");
        check_signal(alu_req_de, 1'b1, "alu_req_de");
        check_signal(sel_imm, 1'b0, "sel_imm");
        
        // =====================================================================
        // TEST 3: SUB Instruction
        // =====================================================================
        print_header("SUB Instruction (R7 = R6 - R1)");
        
        apply_instr(16'h4761, "SUB R7, R6, R1");
        
        check_value_4bit(op, 4'h4, "op");
        check_value_4bit(rd, 4'h7, "rd");
        check_value_4bit(rs, 4'h6, "rs");
        check_value_4bit(rt, 4'h1, "rt");
        check_signal(regwe, 1'b1, "regwe");
        check_signal(alu_req_de, 1'b1, "alu_req_de");
        
        // =====================================================================
        // TEST 4: MUL Instruction
        // =====================================================================
        print_header("MUL Instruction (R4 = R2 * R3)");
        
        apply_instr(16'h5423, "MUL R4, R2, R3");
        
        check_value_4bit(op, 4'h5, "op");
        check_signal(regwe, 1'b1, "regwe");
        check_signal(alu_req_de, 1'b1, "alu_req_de");
        
        // =====================================================================
        // TEST 5: DIV Instruction
        // =====================================================================
        print_header("DIV Instruction (R8 = R9 / R2)");
        
        apply_instr(16'h6892, "DIV R8, R9, R2");
        
        check_value_4bit(op, 4'h6, "op");
        check_signal(regwe, 1'b1, "regwe");
        check_signal(alu_req_de, 1'b1, "alu_req_de");
        
        // =====================================================================
        // TEST 6: LOAD Instruction
        // =====================================================================
        print_header("LOAD Instruction (R3 = MEM[R1 + offset])");
        
        apply_instr(16'h7310, "LD R3, R1, #0");
        
        check_value_4bit(op, 4'h7, "op");
        check_signal(regwe, 1'b1, "regwe");
        check_signal(load_request, 1'b1, "load_request");
        check_signal(alu_req_de, 1'b0, "alu_req_de");
        
        // =====================================================================
        // TEST 7: STORE Instruction
        // =====================================================================
        print_header("STORE Instruction (MEM[R2 + offset] = R4)");
        
        apply_instr(16'h8420, "STR R4, R2, #0");
        
        check_value_4bit(op, 4'h8, "op");
        check_signal(regwe, 1'b0, "regwe");
        check_signal(store_request, 1'b1, "store_request");
        check_signal(load_request, 1'b0, "load_request");
        
        // =====================================================================
        // TEST 8: CONST Instruction (Immediate Load)
        // =====================================================================
        print_header("CONST Instruction (R6 = #0x55)");
        
        apply_instr(16'h9655, "CONST R6, #0x55");
        
        check_value_4bit(op, 4'h9, "op");
        check_value_4bit(rd, 4'h6, "rd");
        check_value_16bit(bimm, 16'h0055, "bimm");
        check_signal(regwe, 1'b1, "regwe");
        check_signal(sel_imm, 1'b1, "sel_imm");
        
        // =====================================================================
        // TEST 9: CMP Instruction (Set NZP flags)
        // =====================================================================
        print_header("CMP Instruction (Set NZP flags)");
        
        apply_instr(16'hA000, "CMP");
        
        check_value_4bit(op, 4'hA, "op");
        check_signal(set_nzp, 1'b1, "set_nzp");
        check_signal(regwe, 1'b0, "regwe");
        
        // =====================================================================
        // TEST 10: Unconditional Branch (BRnzp)
        // =====================================================================
        print_header("Unconditional Branch (BRnzp #5)");
        
        set_all_flags(3'b010);  // All lanes zero
        apply_instr(16'hBE05, "BRnzp #5");
        
        check_value_4bit(op, 4'hB, "op");
        check_value_16bit(bimm, 16'h0005, "bimm");
        check_signal(br, 1'b1, "br");  // Should branch (some lanes meet condition)
        
        // =====================================================================
        // TEST 11: Conditional Branch - BRz (Branch if Zero)
        // =====================================================================
        print_header("Conditional Branch - BRz (Branch if Zero)");
        
        set_all_flags(3'b010);  // All lanes zero
        apply_instr(16'hB403, "BRz #3");
        
        check_signal(br, 1'b1, "br");  // Should branch (all zero)
        
        // Check that mask_in was computed correctly
        wait_cycles(1);
        $display("[TEST %0d] mask_in should be all 0s (all lanes take branch)", test_num);
        
        // =====================================================================
        // TEST 12: Conditional Branch - BRp (Branch if Positive)
        // =====================================================================
        print_header("Conditional Branch - BRp (Branch if Positive)");
        
        set_all_flags(3'b001);  // All lanes positive
        apply_instr(16'hB202, "BRp #2");
        
        check_signal(br, 1'b1, "br");  // Should branch
        
        // =====================================================================
        // TEST 13: Conditional Branch - BRn (Branch if Negative)
        // =====================================================================
        print_header("Conditional Branch - BRn (Branch if Negative)");
        
        set_all_flags(3'b100);  // All lanes negative
        apply_instr(16'hB801, "BRn #1");
        
        check_signal(br, 1'b1, "br");  // Should branch
        
        // =====================================================================
        // TEST 14: Mixed Flags - Some Lanes Branch
        // =====================================================================
        print_header("Mixed Flags - Partial Branch");
        
        // Set mixed flags
        for (int i = 0; i < 16; i++) begin
            if (i < 8)
                nzp_flags[i] = 3'b001;  // Positive
            else
                nzp_flags[i] = 3'b100;  // Negative
        end
        
        apply_instr(16'hB204, "BRp #4");  // Only positive lanes should branch
        
        check_signal(br, 1'b1, "br");
        
        // =====================================================================
        // TEST 15: Branch with No Lanes Meeting Condition
        // =====================================================================
        print_header("Branch with No Lanes Meeting Condition");
        
        set_all_flags(3'b010);  // All zero
        apply_instr(16'hB204, "BRp #4");  // Branch if positive (none are)
        
        check_signal(br, 1'b0, "br");  // Should NOT branch
        
        // =====================================================================
        // TEST 16: SYNC Instruction
        // =====================================================================
        print_header("SYNC Instruction (Pop Mask Stack)");
        
        apply_instr(16'hC000, "SYNC");
        
        check_value_4bit(op, 4'hC, "op");
        check_signal(regwe, 1'b0, "regwe");
        check_signal(br, 1'b0, "br");
        
        // =====================================================================
        // TEST 17: DONE Instruction
        // =====================================================================
        print_header("DONE Instruction");
        
        apply_instr(16'hF000, "DONE");
        
        check_value_4bit(op, 4'hF, "op");
        check_signal(done, 1'b1, "done");
        check_signal(regwe, 1'b0, "regwe");
        
        // =====================================================================
        // TEST 18: Mask Stack - Push Operation
        // =====================================================================
        print_header("Mask Stack - PUSH (Conditional Branch)");
        
        rst = 1;
        wait_cycles(2);
        rst = 0;
        wait_cycles(1);
        
        $display("Initial mask: %016b (should be all 0s - all active)", mask);
        check_value_16bit(mask, 16'h0000, "mask (initial)");
        
        // Set up flags: lanes 0-7 positive, lanes 8-15 zero
        for (int i = 0; i < 16; i++) begin
            nzp_flags[i] = (i < 8) ? 3'b001 : 3'b010;
        end
        
        // Branch if positive - only lanes 0-7 should be active
        apply_instr(16'hB203, "BRp #3");
        wait_cycles(1);  // Wait for registered mask update
        
        $display("After BRp: mask = %016b", mask);
        $display("Expected: lanes 8-15 masked (bits 8-15 = 1)");
        
        // Mask should have lanes 8-15 set (they didn't take the branch)
        check_value_16bit(mask, 16'hFF00, "mask (after push)");
        
        // Check stack pointer
        $display("Stack pointer: %0d (should be 1)", dut.sp);
        if (dut.sp !== 1) begin
            $error("Stack pointer should be 1, got %0d", dut.sp);
            error_count++;
        end else begin
            pass_count++;
        end
        
        // =====================================================================
        // TEST 19: Mask Stack - Second Push (Nested Branch)
        // =====================================================================
        print_header("Mask Stack - Second PUSH (Nested Branch)");
        
        // Now branch if zero - only active lanes (0-7) that are zero will branch
        // All active lanes are positive, so none will branch
        for (int i = 0; i < 8; i++) begin
            nzp_flags[i] = 3'b001;  // Positive
        end
        
        apply_instr(16'hB402, "BRz #2");
        wait_cycles(1);
        
        $display("After second branch: mask = %016b", mask);
        // All lanes 0-7 should now be masked (none were zero)
        check_value_16bit(mask, 16'hFFFF, "mask (after 2nd push)");
        
        $display("Stack pointer: %0d (should be 2)", dut.sp);
        if (dut.sp !== 2) begin
            $error("Stack pointer should be 2, got %0d", dut.sp);
            error_count++;
        end else begin
            pass_count++;
        end
        
        // =====================================================================
        // TEST 20: Mask Stack - Pop Operation
        // =====================================================================
        print_header("Mask Stack - POP (SYNC)");
        
        apply_instr(16'hC000, "SYNC");
        wait_cycles(1);
        
        $display("After SYNC: mask = %016b", mask);
        // Should restore to previous mask (lanes 8-15 masked)
        check_value_16bit(mask, 16'hFF00, "mask (after 1st pop)");
        
        $display("Stack pointer: %0d (should be 1)", dut.sp);
        if (dut.sp !== 1) begin
            $error("Stack pointer should be 1, got %0d", dut.sp);
            error_count++;
        end else begin
            pass_count++;
        end
        
        // =====================================================================
        // TEST 21: Mask Stack - Pop to Empty
        // =====================================================================
        print_header("Mask Stack - POP to Empty");
        
        apply_instr(16'hC000, "SYNC");
        wait_cycles(1);
        
        $display("After 2nd SYNC: mask = %016b", mask);
        check_value_16bit(mask, 16'h0000, "mask (empty stack)");
        
        $display("Stack pointer: %0d (should be 0)", dut.sp);
        if (dut.sp !== 0) begin
            $error("Stack pointer should be 0, got %0d", dut.sp);
            error_count++;
        end else begin
            pass_count++;
        end
        
        // =====================================================================
        // TEST 22: Mask Stack - Underflow Protection
        // =====================================================================
        print_header("Mask Stack - Underflow Protection");
        
        apply_instr(16'hC000, "SYNC (on empty stack)");
        wait_cycles(1);
        
        $display("Stack pointer after underflow attempt: %0d (should stay 0)", dut.sp);
        if (dut.sp !== 0) begin
            $error("Stack pointer changed on empty pop!");
            error_count++;
        end else begin
            $display("[TEST %0d] PASS: Stack underflow prevented", test_num);
            pass_count++;
        end
        
        // =====================================================================
        // TEST 23: Mask Stack - Overflow Test
        // =====================================================================
        print_header("Mask Stack - Fill to Capacity (8 entries)");
        
        rst = 1;
        wait_cycles(2);
        rst = 0;
        wait_cycles(1);
        
        // Push 8 masks (fill the stack)
        for (int i = 0; i < 8; i++) begin
            set_all_flags(3'b001);  // Positive
            apply_instr(16'hB201 + i, $sformatf("BRp #%0d", i+1));
            wait_cycles(1);
            $display("  Push %0d: sp=%0d, mask=%04h", i+1, dut.sp, mask);
        end
        
        $display("Stack pointer after 8 pushes: %0d", dut.sp);
        if (dut.sp !== 8) begin
            $error("Stack pointer should be 8, got %0d", dut.sp);
            error_count++;
        end else begin
            pass_count++;
        end
        
        // Try to push 9th (should be prevented by mask_in check)
        apply_instr(16'hB209, "BRp #9 (overflow attempt)");
        wait_cycles(1);
        $display("Stack pointer after overflow attempt: %0d (should stay 8)", dut.sp);
        
        // =====================================================================
        // TEST 24: All Control Signals Off for Unknown Opcode
        // =====================================================================
        print_header("Unknown Opcode (Default Case)");
        
        apply_instr(16'h2000, "Unknown opcode 0x2");
        
        check_signal(regwe, 1'b0, "regwe");
        check_signal(alu_req_de, 1'b0, "alu_req_de");
        check_signal(br, 1'b0, "br");
        check_signal(done, 1'b0, "done");
        
        
        // =====================================================================
        // Final Report
        // =====================================================================
        wait_cycles(5);
        
        $display("");
        $display("================================================================================");
        $display("TESTBENCH SUMMARY");
        $display("================================================================================");
        $display("Total Tests:    %0d", test_num - 1);
        $display("Checks Passed:  %0d", pass_count);
        $display("Checks Failed:  %0d", error_count);
        $display("Success Rate:   %.1f%%", 100.0 * pass_count / (pass_count + error_count));
        
        if (error_count == 0) begin
            $display("");
            $display("*** ALL TESTS PASSED! ***");
        end else begin
            $display("");
            $display("*** %0d TESTS FAILED ***", error_count);
        end
 
        $finish;
    end
    
    // =========================================================================
    // Timeout Watchdog
    // =========================================================================
    
    initial begin
        #500000;  // 50us timeout
        $error("TIMEOUT: Testbench did not complete!");
        $finish;
    end
    
    // =========================================================================
    // Waveform Dump
    // =========================================================================

endmodule