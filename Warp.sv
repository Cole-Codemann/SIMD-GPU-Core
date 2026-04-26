// Warp Module:
// Handles instruction fetch, decode, and pipeline management for a vector thread group.
// The 'halt' can be overridden by 'mem_to_regwe' to allow loaded data to slot into the pipe.

//Potential upgrade: I think we have a useless clock cycle after going from idling to not idling
//once halt is low, could we force that cycle to happen before manager points to us?
module warp #(
    parameter logic [1:0] WARP_ID = 2'd0
)(
    input  logic              clk,
    input  logic              reset,
    input  logic              mem_req_done,
    input  logic [15:0][15:0] exe_out,         // Result from ALU execute
    input  logic [15:0][15:0] mem_to_reg_data, // Data from memory controller
    input  logic              warp_halt,       // External stall request
    input  logic              mem_request_ack,
    output logic [15:0][15:0] rs_data_exe,     // Source 1 to EXE
    output logic [15:0][15:0] rt_data_exe,     // Source 2 to EXE
    output logic [3:0]        op_exe,          // Opcode to EXE
    output logic              store_request,   // To memory controller
    output logic              load_request,     // To memory controller
    output logic [15:0] 	  mask_exe,
    output logic              idling,
    output logic              done
);

    // --- Signal Declarations ---
    // --- PC & Fetch ---
    logic [9:0]  pc, pc_next, pc_uncon, pc_true;
    logic [15:0] instr;
    logic        rd_en;

    // --- Decode Stage ---
    logic [3:0]  op_de;
    logic [3:0]  rs_addr_de, rt_addr_de, rd_addr_de;
    logic [15:0] bimm_de;
    logic        regwe_de, sel_imm_de, set_nzp_de;
    logic        store_request_de, load_request_de;
    logic        br;
    logic [15:0] mask_de;
    logic        done_de;

    // --- Execute Stage ---
    logic [3:0]  rd_addr_exe;
    logic [15:0] bimm_exe;
    logic [15:0][15:0] bimm_exe_extended;
    logic        regwe_exe, sel_imm_exe, set_nzp_exe;
    logic        mem_ldr_we_exe;
    logic        done_exe;

    // --- Writeback Stage ---
    logic [3:0]  rd_addr_wb;
    logic        regwe_wb, regwe_wb_true;
    logic [15:0] mask_wb;
    logic        done;

    // --- Register File Data ---
    logic [15:0][15:0] rs_data_de, rt_data_de;
    logic [15:0][15:0] rs_data_de_reg, rt_data_de_reg;
    logic [15:0][15:0] rd_data_exe, rd_data_wb;

    // --- NZP Flags & Masking ---
    logic [15:0][2:0]  nzp_flags, nzp_flags_next, nzp_flags_true;

    // --- Pipeline Control ---
    logic        halt;

    // --- Pipeline Control ---
    assign halt = ((warp_halt | load_request | store_request) & ~mem_req_done & ~idling);
    assign rd_en = !halt;
    assign regwe_wb_true = !halt & regwe_wb;
    assign idling = (mask_de == 16'hFFFF);

    // --- Vector Lanes Instantiation ---
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : lane_gen
            lane #(.LANE_ID(i)) lane_inst (
                .clk      (clk),
                .reset    (reset),
                .regwe    (regwe_wb),
                .halt     (halt),
                .mask     (mask_wb[i]),
                .rs_addr  (rs_addr_de),
                .rt_addr  (rt_addr_de),
                .rd_addr  (rd_addr_wb),
                .rd_data  (rd_data_wb[i]),
                .rs_data  (rs_data_de_reg[i]),
                .rt_data  (rt_data_de_reg[i])
            );
        end
    endgenerate

    // --- Fetch Stage ---
    instr_regfile #(.SET_ID(WARP_ID)) u_instr_regfile (
        .clk     (clk),
        .rst     (reset),
        .rd_en   (rd_en),
        .rd_addr (pc_true),
        .rd_data (instr)
    );

    assign pc_next = pc + 1;
    assign pc_uncon = pc - 10'd1 + {{2{bimm_de[7]}}, bimm_de[7:0]};

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= '0;
        end else if (halt) begin
            pc <= pc;
        end else if (br) begin
            pc <= pc + {{2{bimm_de[7]}}, bimm_de[7:0]};
        end else begin
            pc <= pc_next;
        end
    end
    
    assign pc_true = (br) ? pc_uncon : pc;

    // --- Decode Stage ---

    cu cu_inst (
        .clk           (clk),
        .rst           (reset),
        .instr         (instr),
        .nzp_flags     (nzp_flags_true),
        .op            (op_de),
        .rd            (rd_addr_de),
        .rs            (rs_addr_de),
        .rt            (rt_addr_de),
        .bimm          (bimm_de),
        .mask          (mask_de),
        .regwe         (regwe_de),
        .store_request (store_request_de),
        .load_request  (load_request_de),
        .sel_imm       (sel_imm_de),
        .br            (br),
        .set_nzp       (set_nzp_de),
        .done          (done_de)
    );
    
    // --- Data forwarding ---
    always_comb begin
        rs_data_de = rs_data_de_reg;
        rt_data_de = rt_data_de_reg;

        for (int i = 0; i < 16; i++) begin
            if (regwe_wb & (rd_addr_wb > 1) & !mask_wb[i]) begin
                if (rs_addr_de == rd_addr_wb) rs_data_de[i] = rd_data_wb[i];
                if (rt_addr_de == rd_addr_wb) rt_data_de[i] = rd_data_wb[i];
            end

            if (regwe_exe & (rd_addr_exe > 1) & !mask_exe[i]) begin
                if (rs_addr_de == rd_addr_exe) rs_data_de[i] = rd_data_exe[i];
                if (rt_addr_de == rd_addr_exe) rt_data_de[i] = rd_data_exe[i];
            end
        end
    end

    
    // --- Execute Stage Registers ---
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            op_exe          <= '0;
            rs_data_exe     <= '0;
            rt_data_exe     <= '0;
            rd_addr_exe     <= '0;
            bimm_exe        <= '0;
            regwe_exe       <= '0;
            sel_imm_exe     <= '0;
            mem_ldr_we_exe  <= '0;
            store_request   <= '0;
            load_request    <= '0;
            set_nzp_exe     <= '0;
            mask_exe        <= '0;
            done_exe        <= '0;
        end else if (!halt) begin
            op_exe          <= op_de;
            rs_data_exe     <= rs_data_de;
            rt_data_exe     <= rt_data_de;
            rd_addr_exe     <= rd_addr_de;
            bimm_exe        <= bimm_de;
            regwe_exe       <= regwe_de;
            sel_imm_exe     <= sel_imm_de;
            mem_ldr_we_exe  <= load_request_de;
            store_request   <= store_request_de;
            load_request    <= load_request_de;
            set_nzp_exe     <= set_nzp_de;
            mask_exe        <= mask_de;
            done_exe        <= done_de;
        end else if (mem_request_ack) begin
            store_request   <= '0;
            load_request    <= '0;
        end
    end
    // --- Flag Setting ---
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            if (exe_out[i][15])          nzp_flags_next[i] <= 3'b100; // N
            else if (exe_out[i] == 16'd0)    nzp_flags_next[i] <= 3'b010; // Z
            else                         nzp_flags_next[i] <= 3'b001; // P
        end
    end
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            nzp_flags <= '{default: 3'b010};
        end else if (set_nzp_exe) begin
            nzp_flags <= nzp_flags_next;
        end
    end

    //Flag Data Forwarding
    assign nzp_flags_true = (set_nzp_exe) ? nzp_flags_next : nzp_flags;

    // --- Writeback Mux & Registers ---
    assign bimm_exe_extended = {16{bimm_exe}};

    assign rd_data_exe = (mem_ldr_we_exe) ? mem_to_reg_data :
                         (sel_imm_exe)    ? bimm_exe_extended :
                                            exe_out;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            done       <= '0;
            rd_data_wb <= '0;
            rd_addr_wb <= '0;
            regwe_wb   <= '0;
            mask_wb    <= '0;
        end else if (!halt) begin
            rd_data_wb <= rd_data_exe;
            rd_addr_wb <= rd_addr_exe;
            regwe_wb   <= regwe_exe;
            mask_wb    <= mask_exe;
            done       <= done_exe;
        end
    end
endmodule
