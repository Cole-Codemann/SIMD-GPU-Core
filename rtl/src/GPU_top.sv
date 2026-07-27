// Engineer: Cole Kaufmann
// Create Date: 03/24/2026 07:01:48 PM
// Design Name: GPU
// Module Name: GPU_top
//
// DEBUG VERSION: signals marked with (* mark_debug = "true" *) for ILA capture.
// To revert: comment out the DEBUG block below and uncomment the ORIGINAL block.

module GPU_top(
    input  logic         clk,
    input  logic         reset_in,

    (* mark_debug = "true" *) output logic              GPU_done,
    //(* mark_debug = "false" *) output logic [3:0]        warp_done_dbg,
    (* mark_debug = "false" *) output logic [3:0][10:0]   imem_addr,
    (* mark_debug = "false" *) input  logic [3:0][15:0]  imem_rdata,

    // Data memory - BRAM Port B
    (* mark_debug = "false" *) output logic [10:0]  dmem_addr,
    (* mark_debug = "false" *) output logic [127:0] dmem_wdata,
    (* mark_debug = "false" *) output logic [15:0]  dmem_wen,
                              input  logic [127:0] dmem_rdata,
    
    // Duration Counter
    (* mark_debug = "true" *)output logic [31:0] program_duration_count
);

    // ── Reset synchronizer ──────────────────────────────────────────────────
    // ─── DEBUG: reset marked for ILA ────────────────────────────────────────
    (* mark_debug = "true" *) logic reset;
                              logic reset_meta;
    // ─── ORIGINAL: ─────────────────────────────────────────────────────────
    // logic reset_meta, reset;

    always_ff @(posedge clk) begin
        reset_meta <= reset_in;
        reset      <= reset_meta;
    end

    // ── Warp Data Buses ─────────────────────────────────────────────────────
    (* mark_debug = "false" *) logic [3:0][15:0][15:0] warp_data1;
    (* mark_debug = "false" *) logic [3:0][15:0][15:0] warp_data2;
    logic [3:0][3:0]        warp_alu_op;
    logic [15:0][15:0]      exe_out;

    // ── Warp Control ─────────────────────────────────────────────────────────
    (* mark_debug = "true" *)logic [3:0] alu_req;        // each warp requesting ALU access
    (* mark_debug = "true" *)logic [3:0] alu_access;     // warp controller granting ALU access

    // ─── DEBUG: warp_done marked ───────────────────────────────────────────
    (* mark_debug = "false" *) logic [3:0] warp_done;
    // ─── ORIGINAL: ─────────────────────────────────────────────────────────
    // logic [3:0] warp_done;

    //assign GPU_done = (imem_rdata[0] == 16'hF000) & !reset; WORKS
    //assign warp_done_dbg[0] = (imem_rdata[0] == 16'hF000) & !reset;
    //assign warp_done_dbg[1] = (imem_rdata[1] == 16'hF000) & !reset;
    //assign warp_done_dbg[2] = (imem_rdata[2] == 16'hF000) & !reset;
    //assign warp_done_dbg[3] = (imem_rdata[3] == 16'hF000) & !reset;
    assign GPU_done = &warp_done;

    // ── Memory Interface ────────────────────────────────────────────────────
    // ─── DEBUG: memory handshake signals marked ────────────────────────────
    (* mark_debug = "false" *) logic [3:0]        store_requests;
    (* mark_debug = "false" *) logic [3:0]        load_requests;
    (* mark_debug = "false" *) logic [3:0]        conc_request;
    (* mark_debug = "true" *) logic [3:0]        mem_req_done;
    (* mark_debug = "true" *) logic [3:0]        mem_request_ack;
                              logic [15:0][15:0] mem_to_reg_data;
                              logic [3:0][15:0]  lane_mask;
    
    // ─── Clock Cycle Counting ─────────────────────────────────────────────────────────
    
    logic [3:0] stalled_on_alu, stalled_on_mem, scoreboard_stall;
    logic reset_prev;
    (* mark_debug = "true" *) logic [3:0][31:0] mem_stall_count;
    (* mark_debug = "true" *) logic [3:0][31:0] alu_stall_count;
    (* mark_debug = "true" *) logic [3:0][31:0] scoreboard_stall_count;
    (* mark_debug = "true" *) logic [3:0][31:0] free_run_count;
    (* mark_debug = "true" *) logic [31:0] alu_usage;
    
    
    always_ff @(posedge clk) begin
        reset_prev <= reset;
        if (reset_prev && !reset) begin
            alu_usage <= '0;
            program_duration_count <= '0;
            mem_stall_count <= '{default: '0};
            alu_stall_count <= '{default: '0};
            scoreboard_stall_count <= '{default: '0};
            free_run_count  <= '{default: '0};
        end else if (~reset) begin
            if (!GPU_done) begin
                program_duration_count <= program_duration_count + 1;
                if (|alu_access) alu_usage <= alu_usage + 1;
                for (int i = 0; i < 4; i++) begin
                    if (stalled_on_mem[i]) mem_stall_count[i] <= mem_stall_count[i] + 1;
                    else if (stalled_on_alu[i]) alu_stall_count[i] <= alu_stall_count[i] + 1;
                    else if (scoreboard_stall[i]) scoreboard_stall_count[i] <= scoreboard_stall_count[i] + 1;
                    else if (~warp_done[i]) free_run_count[i] <= free_run_count[i] + 1;
                end
            end
        end     
    end

    // ── Warp Instantiation ───────────────────────────────────────────────────
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : warp_gen
            warp #(
                .WARP_ID(i[1:0])
            ) warp_inst (
                .clk                (clk),
                .reset              (reset),
                .mem_req_done       (mem_req_done[i]),
                .exe_out            (exe_out),
                .mem_to_reg_data    (mem_to_reg_data),
                .mem_request_ack    (mem_request_ack[i]),
                .alu_access         (alu_access[i]),
                .rs_data_exe        (warp_data1[i]),
                .rt_data_exe        (warp_data2[i]),
                .op_exe             (warp_alu_op[i]),
                .store_request      (store_requests[i]),
                .load_request       (load_requests[i]),
                .conc_request       (conc_request[i]),
                .mask_exe           (lane_mask[i]),
                .alu_req            (alu_req[i]),
                .done               (warp_done[i]),
                .stalled_on_alu_out (stalled_on_alu[i]),
                .stalled_on_mem_out (stalled_on_mem[i]),
                .scoreboard_stall_out(scoreboard_stall[i]),
                .instr_in           (imem_rdata[i]),
                .pc                 (imem_addr[i])
            );
        end
    endgenerate

    // ── Memory Controller ────────────────────────────────────────────────────
    memory_controller u_memory_controller (
        // Inputs
        .clk                (clk),
        .rst                (reset),
        .reg_to_mem_data    (warp_data2),
        .mem_addr           (warp_data1),
        .store_requests     (store_requests),
        .load_requests      (load_requests),
        .con_request        (conc_request),
        .lane_mask          (lane_mask),

        // Outputs
        .mem_req_done       (mem_req_done),
        .mem_to_reg_data    (mem_to_reg_data),
        .mem_request_ack    (mem_request_ack),

        // Memory Interface
        .addr          (dmem_addr),
        .wdata         (dmem_wdata),
        .wen           (dmem_wen),
        .rdata         (dmem_rdata)
    );

    // ── ALU Lane Mux ─────────────────────────────────────────────────────────
    // Selects which warp drives the shared ALU lanes based on warp_halt one-hot
    logic [15:0][15:0] alu_data1;
    logic [15:0][15:0] alu_data2;
    logic [3:0]        alu_op;

    always_comb begin
        alu_data1 = '0;
        alu_data2 = '0;
        alu_op    = '0;
        case (alu_access)
            4'b0001: begin alu_data1 = warp_data1[0]; alu_data2 = warp_data2[0]; alu_op = warp_alu_op[0]; end
            4'b0010: begin alu_data1 = warp_data1[1]; alu_data2 = warp_data2[1]; alu_op = warp_alu_op[1]; end
            4'b0100: begin alu_data1 = warp_data1[2]; alu_data2 = warp_data2[2]; alu_op = warp_alu_op[2]; end
            4'b1000: begin alu_data1 = warp_data1[3]; alu_data2 = warp_data2[3]; alu_op = warp_alu_op[3]; end
            default: begin alu_data1 = warp_data1[0]; alu_data2 = warp_data2[0]; alu_op = warp_alu_op[0]; end
        endcase
    end

    // ── ALU Lanes ────────────────────────────────────────────────────────────
    alu_lanes alu_lanes_inst (
        .data1   (alu_data1),
        .data2   (alu_data2),
        .alu_op  (alu_op),
        .exe_out (exe_out)
    );

    // ── Warp Controller ──────────────────────────────────────────────────────
    warp_controller warp_ctrl (
        .rst         (reset),
        .clk         (clk),
        .alu_req     (alu_req),
        .alu_access  (alu_access)
    );

endmodule