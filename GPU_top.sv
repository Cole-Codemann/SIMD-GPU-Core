// Engineer: Cole Kaufmann
// Create Date: 03/24/2026 07:01:48 PM
// Design Name: GPU
// Module Name: GPU_top

module GPU_top(
    input  logic        clk,
    input  logic        reset,
    output logic [3:0]  warp_halt_out
);

    // ── Warp Data Buses ─────────────────────────────────────────────────────
    logic [3:0][15:0][15:0] warp_data1;
    logic [3:0][15:0][15:0] warp_data2;
    logic [3:0][3:0]        warp_alu_op;
    logic [15:0][15:0]      exe_out;

    // ── Warp Control ─────────────────────────────────────────────────────────
    logic [3:0] warp_halt;        // Negation is one-hot of currently running warp
    logic [3:0] warp_idling;
    logic [3:0] warp_done;
    assign warp_halt_out = warp_halt; // Prevents optimizer from trimming design
    

    // ── Memory Interface ─────────────────────────────────────────────────────
    logic [3:0]        store_requests;
    logic [3:0]        load_requests;
    logic [3:0]        mem_req_done;
    logic [3:0]        warps_in_mem_queue;
    logic [3:0]        mem_request_ack;
    logic [15:0][15:0] mem_to_reg_data;
    logic [3:0][15:0]  lane_mask;

    // ── Warp Instantiation ───────────────────────────────────────────────────
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : warp_gen
            warp #(
                .WARP_ID(i[1:0])
            ) warp_inst (
                .clk             (clk),
                .reset           (reset),
                .mem_req_done    (mem_req_done[i]),
                .exe_out         (exe_out),
                .mem_to_reg_data (mem_to_reg_data),
                .warp_halt       (warp_halt[i]),
                .mem_request_ack (mem_request_ack[i]),
                .rs_data_exe     (warp_data1[i]),
                .rt_data_exe     (warp_data2[i]),
                .op_exe          (warp_alu_op[i]),
                .store_request   (store_requests[i]),
                .load_request    (load_requests[i]),
                .mask_exe        (lane_mask[i]),
                .idling          (warp_idling[i]),
                .done            (warp_done[i])
            );
        end
    endgenerate

    // ── Memory Controller ────────────────────────────────────────────────────
    memory_controller mem_ctrl (
        .clk             (clk),
        .rst             (reset),
        .mem_addr        (warp_data1),
        .reg_to_mem_data (warp_data2),
        .store_requests  (store_requests),
        .load_requests   (load_requests),
        .lane_mask       (lane_mask),
        .mem_req_done    (mem_req_done),
        .mem_to_reg_data (mem_to_reg_data),
        .warp_waiting    (warps_in_mem_queue),
        .mem_request_ack (mem_request_ack)
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
        case (warp_halt)
            4'b1110: begin alu_data1 = warp_data1[0]; alu_data2 = warp_data2[0]; alu_op = warp_alu_op[0]; end
            4'b1101: begin alu_data1 = warp_data1[1]; alu_data2 = warp_data2[1]; alu_op = warp_alu_op[1]; end
            4'b1011: begin alu_data1 = warp_data1[2]; alu_data2 = warp_data2[2]; alu_op = warp_alu_op[2]; end
            4'b0111: begin alu_data1 = warp_data1[3]; alu_data2 = warp_data2[3]; alu_op = warp_alu_op[3]; end
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
        .rst                (reset),
        .clk                (clk),
        .store_requests     (store_requests),
        .load_requests      (load_requests),
        .warps_in_mem_queue (warps_in_mem_queue),
        .warp_idling        (warp_idling),
        .warp_done          (warp_done),
        .warp_halt          (warp_halt)
    );

endmodule