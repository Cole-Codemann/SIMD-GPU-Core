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
    logic              alu_req_ack;
    logic [15:0][15:0] rs_data_exe;
    logic [15:0][15:0] rt_data_exe;
    logic [3:0]        op_exe;
    logic              store_request, load_request, conc_request;
    logic [15:0]       mask_exe;
    logic              alu_req;
    logic              done;
    logic [15:0]       instr_in;
    logic [9:0]        pc;

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
        .instr_in       (instr_in),
        .pc             (pc)
    );

    // ── Instruction memory (loaded from rom_set0.mem) ────────────────────────
    logic [15:0] imem [0:1023];
    initial begin
        for (int i = 0; i < 1024; i++) imem[i] = 16'h0;
        $readmemh("rom_set0.mem", imem);
    end
    assign instr_in = imem[pc];

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
    initial begin
        $display("[%0t] warp_tb starting", $time);
        reset = 1'b1;
        repeat (4) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        $display("[%0t] reset released", $time);

        fork
            begin : wait_done
                @(posedge done);
                $display("[%0t] PASS: done asserted, pc=0x%03X", $time, pc);
                disable timeout;
            end
            begin : timeout
                repeat (10_000) @(posedge clk);
                $display("[%0t] FAIL: timeout, pc=0x%03X done=%b", $time, pc, done);
                disable wait_done;
            end
        join

        repeat (10) @(posedge clk);

        // Dump non-zero entries in 64-160 for inspection
        $display("--- non-zero dmem[64..159] ---");
        for (int i = 64; i < 160; i++) begin
            if (dmem[i] !== 16'h0)
                $display("  dmem[%0d] = 0x%04X (%0d)", i, dmem[i], $signed(dmem[i]));
        end

        $finish;
    end

endmodule
