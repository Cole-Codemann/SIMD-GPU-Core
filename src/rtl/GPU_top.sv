// Engineer: Cole Kaufmann
// Create Date: 03/24/2026 07:01:48 PM
// Design Name: GPU
// Module Name: GPU_top

module GPU_top(
    input  logic         clk,
    input  logic         reset,
    output logic         GPU_done,

    // Data memory - BRAM Port B
    output logic [10:0]  dmem_addr,
    output logic [127:0] dmem_wdata,
    output logic [15:0]  dmem_wen,
    input  logic [127:0] dmem_rdata,
    
    // Intruction memory - BRAM Port B
    output logic [3:0][9:0]   imem_addr,
    input  logic [3:0][15:0]  imem_rdata
);

    // ── Warp Data Buses ─────────────────────────────────────────────────────
    logic [3:0][15:0][15:0] warp_data1;
    logic [3:0][15:0][15:0] warp_data2;
    logic [3:0][3:0]        warp_alu_op;
    logic [15:0][15:0]      exe_out;
    logic [15:0][15:0]      exe_out_reg;

    // ── Warp Control ─────────────────────────────────────────────────────────
    logic [3:0] alu_req;        // each warp requesting ALU access
    logic [3:0] alu_access;     // warp controller granting ALU access
    logic [3:0] alu_data_ready; // signals which warps data is on register
    logic [3:0] warp_done;
    assign GPU_done = &warp_done;

    // ── Memory Interface ─────────────────────────────────────────────────────
    logic [3:0]        store_requests;
    logic [3:0]        load_requests; 
    logic [3:0]        conc_request;
    logic [3:0]        mem_req_done;
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