// Warp Module with EXE2 Stage and Branch Penalty:
// Handles instruction fetch, decode, and pipeline management for a vector thread group.
// Pipeline: FETCH -> DECODE -> EXE -> EXE2 -> WB
// Branch penalty: 1 cycle (bubble inserted after branch)

module warp #(
    parameter logic [1:0] WARP_ID = 2'd0
)(
    input  logic              clk,
    input  logic              reset,
    input  logic              mem_req_done,
    input  logic [15:0][15:0] exe_out,         // Result from ALU execute
    input  logic [15:0][15:0] mem_to_reg_data, // Data from memory controller 
    input  logic              mem_request_ack,
    input  logic              alu_access,
    output logic [15:0][15:0] rs_data_exe,     // Source 1 to EXE
    output logic [15:0][15:0] rt_data_exe,     // Source 2 to EXE
    output logic [3:0]        op_exe,          // Opcode to EXE
    output logic              store_request,   // To memory controller
    output logic              load_request,    // To memory controller
    output logic              conc_request,    // To memory controller
    output logic [15:0]       mask_exe,
    output logic              alu_req,
    output logic              done,
    output logic              stalled_on_alu_out,
    output logic              stalled_on_mem_out,
    output logic              scoreboard_stall_out,
    
    input logic  [15:0]       instr_in, 
    (* mark_debug = "true" *) output logic [10:0]        pc
);
    // --- Signal Declarations ---
    
    // --- PC & Fetch ---
    logic [10:0]  pc_next;
    logic [15:0] instr;
    //BRANCH PENALTY 
    logic        branch_taken;        // Registered version of br for penalty tracking
    logic        insert_bubble;       // Signal to insert NOP after branch
    logic [15:0] bubble_instr;        // NOP instruction (all zeros or actual NOP encoding)
    (* mark_debug = "false" *) logic [15:0] instr_muxed;         // Instruction after bubble insertion
    

    // --- Decode Stage ---
    logic [3:0]  op_de;
    (* mark_debug = "false" *) logic [3:0]  rs_addr_de, rt_addr_de, rd_addr_de;
    logic [15:0] bimm_de;
    logic        regwe_de, sel_imm_de, set_nzp_de;
    logic        store_request_de, load_request_de, conc_request_de;
    logic        br;
    logic [15:0] mask_de;
    logic        done_de;
    logic        alu_req_de;

    // --- Execute Stage ---
    (* mark_debug = "false" *) logic [3:0]  rd_addr_exe;
    logic [15:0] bimm_exe;
    
    logic [3:0]  rs_addr_exe, rt_addr_exe;
    (* mark_debug = "false" *) logic        regwe_exe,  sel_imm_exe, set_nzp_exe;
    logic        mem_ldr_we_exe;
    logic        done_exe;
    logic        alu_req_exe; 
    
    // --- Execute 2 Stage ---
    logic [15:0][15:0] exe_out_reg;         // Result from ALU execute
    logic [15:0][15:0] mem_data_reg, rd_data_exe2; //**mem_data_reg not needed anymore
    (* mark_debug = "false" *) logic        regwe_exe2, sel_imm_exe2, set_nzp_exe2;
    logic        mem_ldr_we_exe2;
    logic [15:0] bimm_exe2;
    logic [3:0]  rd_addr_exe2;
    logic [15:0] mask_exe2;
    logic        done_exe2;
    

    // --- Writeback Stage ---
    logic [3:0]  rd_addr_wb;
    logic        regwe_wb;
    logic [15:0] mask_wb;
    logic        done_wb;

    // --- Register File Data ---
    logic [15:0][15:0] rs_data_de, rt_data_de;
    logic [15:0][15:0] rd_data_wb;

    // --- NZP Flags & Masking ---
    (* mark_debug = "false" *) logic [15:0][2:0]  nzp_flags, nzp_flags_next, nzp_flags_true;

    // --- Scoreboard Control ---
    (* mark_debug = "false" *) logic        scoreboard_stall;
    (* mark_debug = "false" *) logic [15:0] addrs_not_ready; //Composite one-hot of not ready addresses
    (* mark_debug = "false" *) logic        nzp_not_ready;  
    (* mark_debug = "false", MAX_FANOUT = 16 *)     logic        halt;
    
    always_ff @(posedge clk or posedge reset) begin //Currently at most forces a one clock stall, allows for future pipelining additions and easier update to arch.
        if (reset) begin
            addrs_not_ready <= '0;
            nzp_not_ready <= 1'b0;
        end else if (!halt) begin //new if statement
            if (regwe_exe) addrs_not_ready[rd_addr_exe] <= 1'b0;
            if (set_nzp_exe) nzp_not_ready <= 1'b0;
            if (!scoreboard_stall) begin
                if (regwe_de) addrs_not_ready[rd_addr_de] <= 1'b1;
                if (set_nzp_de) nzp_not_ready <= 1'b1;
            end
        end
    end
    
    always_comb begin
        scoreboard_stall = 1'b0;
        // CMP: reads rs and rt, no regwe
        if (set_nzp_de & (addrs_not_ready[rs_addr_de] | addrs_not_ready[rt_addr_de]))
            scoreboard_stall = 1'b1;
        // LDR/LDC: only reads rs (address)
        if (load_request_de & addrs_not_ready[rs_addr_de])
            scoreboard_stall = 1'b1;
        // STR/STRC: reads rs (addr) and rt (data)
        if (store_request_de & (addrs_not_ready[rs_addr_de] | addrs_not_ready[rt_addr_de]))
            scoreboard_stall = 1'b1;
        // ALU ops (ADD/SUB/MUL/DIV): reads rs and rt - but NOT CONST
        if (alu_req_de & (addrs_not_ready[rs_addr_de] | addrs_not_ready[rt_addr_de]))
            scoreboard_stall = 1'b1;
        // Conditional branch: stall if flags pending
        if ((instr_muxed[15:12] == 4'b1011) & (instr_muxed[11:9] != 3'b111) & nzp_not_ready)
            scoreboard_stall = 1'b1;
    end
    
    assign scoreboard_stall_out = scoreboard_stall;
           
    // --- Pipeline Control ---
    
    logic        waiting_on_mem;
    logic        stalled_on_alu, stalled_on_mem;
    logic        alu_req_exe_true, alu_req_de_true;
    logic        alu_req_state, alu_req_state_next;

    assign stalled_on_alu    = (alu_req_exe_true) & !alu_access;
    assign stalled_on_mem    = (waiting_on_mem | load_request | store_request) & !mem_req_done;
    assign halt              = stalled_on_alu | stalled_on_mem | done;
    assign alu_req_exe_true  = ((alu_req_exe & (mask_exe != 16'hFFFF)));
    assign alu_req_de_true   = (alu_req_de & (mask_de != 16'hFFFF) & !stalled_on_mem & !scoreboard_stall); //played with this too
    
    assign stalled_on_alu_out = stalled_on_alu;
    assign stalled_on_mem_out = stalled_on_mem;

    always_comb begin //basic idea is, we ask for alu. When warp controller says our data is next clock cycle, we either stop asking for alu
                      //or if we have another request next cycle, we keep asking. That way we can chain multiple accesses in a row.
        if (alu_req_state == 0) begin
            if (alu_req_de_true) begin
                alu_req_state_next = 1;
                alu_req = 1;
            end else begin
                alu_req_state_next = 0;
                alu_req = 0;
            end
        end else begin
            if (alu_access) begin
                if (alu_req_de_true) begin
                    alu_req_state_next = 1;
                    alu_req = 1;
                end else begin
                    alu_req_state_next = 0;
                    alu_req = 0;
                end
            end else begin
                alu_req_state_next = 1;
                alu_req = 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) alu_req_state <= '0;
        else       alu_req_state <= alu_req_state_next;
    end

    always_ff @(posedge clk) begin
        if      (reset)                        waiting_on_mem <= 0;
        else if (mem_req_done)                 waiting_on_mem <= 0;
        else if (load_request | store_request) waiting_on_mem <= 1;
    end
        //NEW - Tested once, seems to work
    logic pipeline_stall;
    assign pipeline_stall = halt | scoreboard_stall;
    
    logic pipeline_stall_prev;
    logic [15:0] instr_missed; 
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pipeline_stall_prev <= '0;
            instr_missed <= '0;
        end else begin
            pipeline_stall_prev <= pipeline_stall;
            if (!pipeline_stall_prev & pipeline_stall)
                instr_missed <= instr_in;
        end
    end
    assign instr = (pipeline_stall_prev) ? instr_missed : instr_in; //Recently changed
    //assign instr = (pipeline_stall_prev & !pipeline_stall) ? instr_missed : instr_in;
    // --- Vector Lanes Instantiation ---
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : lane_gen
            lane #(.LANE_ID(i), .WARP_ID(WARP_ID)) lane_inst (
                .clk      (clk),
                .reset    (reset),
                .regwe    (regwe_wb),
                .halt     (halt),
                .mask     (mask_wb[i]),
                .rs_addr  (rs_addr_de),
                .rt_addr  (rt_addr_de),
                .rd_addr  (rd_addr_wb),
                .rd_data  (rd_data_wb[i]),
                .rs_data  (rs_data_de[i]),
                .rt_data  (rt_data_de[i])
            );
        end
    endgenerate

    //BRANCH PENALTY IMPLEMENTATION
    assign bubble_instr = 16'h0000;
    always_ff @(posedge clk) begin
        if (reset) begin
            branch_taken <= 1'b0;
        end else if (!halt & !scoreboard_stall) begin
            branch_taken <= br;  // Register the branch signal
        end
    end
    
    // Insert bubble the cycle after a branch
    assign insert_bubble = branch_taken & !halt; //cut the halt?
    assign instr_muxed = insert_bubble ? bubble_instr : instr;
    
    // PC Logic Register
    assign pc_next = pc + 1;
    always_ff @(posedge clk) begin
        if (reset) begin
            pc <= '0;
        end else if (halt | scoreboard_stall) begin
            pc <= pc;  // Hold during stalls
        end else if (br) begin
            pc <= pc - 1 + {{3{bimm_de[7]}}, bimm_de[7:0]};
        end else begin
            pc <= pc_next;
        end
    end

    // --- Decode Stage ---
    cu cu_inst (
        .clk           (clk),
        .rst           (reset),
        .halt          (halt),
        .scoreboard_stall (scoreboard_stall),
        .instr         (instr_muxed),
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
        .conc_request  (conc_request_de),
        .sel_imm       (sel_imm_de),
        .br            (br),
        .set_nzp       (set_nzp_de),
        .done          (done_de),
        .alu_req_de    (alu_req_de)
    );
    
// --- Data Forwarding (in Decode) ---
    logic [15:0][15:0] rs_data_forwarded, rt_data_forwarded;
    always_comb begin
        // Default: use data from decode stage
        rs_data_forwarded = rs_data_de;
        rt_data_forwarded = rt_data_de;
    
        for (int i = 0; i < 16; i++) begin
            // Forward from WB stage (2 cycles old)
            if (regwe_wb && (rd_addr_wb > 4'd2) && !mask_wb[i]) begin
                if (rs_addr_de == rd_addr_wb) rs_data_forwarded[i] = rd_data_wb[i];
                if (rt_addr_de == rd_addr_wb) rt_data_forwarded[i] = rd_data_wb[i];
            end
    
            // Forward from EXE2 stage (1 cycle old) - HIGHEST PRIORITY
            if (regwe_exe2 && (rd_addr_exe2 > 4'd2) && !mask_exe2[i]) begin
                if (rs_addr_de == rd_addr_exe2) rs_data_forwarded[i] = rd_data_exe2[i];
                if (rt_addr_de == rd_addr_exe2) rt_data_forwarded[i] = rd_data_exe2[i];
            end
        end
    end
    
    // --- Execute Stage Registers ---
    always_ff @(posedge clk) begin
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
            conc_request    <= '0;
            set_nzp_exe     <= '0;
            mask_exe        <= '0;
            done_exe        <= '0;
            alu_req_exe     <= '0;
            rs_addr_exe     <= '0;
            rt_addr_exe     <= '0;
        end else if (!scoreboard_stall & !halt) begin
            op_exe          <= op_de;
            rs_data_exe     <= rs_data_forwarded;
            rt_data_exe     <= rt_data_forwarded;
            rd_addr_exe     <= rd_addr_de;
            bimm_exe        <= bimm_de;
            regwe_exe       <= regwe_de;
            sel_imm_exe     <= sel_imm_de;
            mem_ldr_we_exe  <= load_request_de;
            store_request   <= store_request_de;
            load_request    <= load_request_de;
            conc_request    <= conc_request_de;
            set_nzp_exe     <= set_nzp_de;
            mask_exe        <= mask_de;
            done_exe        <= done_de;
            alu_req_exe     <= alu_req_de;
            rs_addr_exe     <= rs_addr_de;
            rt_addr_exe     <= rt_addr_de;
        end else if (scoreboard_stall & !halt) begin
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
            conc_request    <= '0;
            set_nzp_exe     <= '0;
            mask_exe        <= '0;
            done_exe        <= '0;
            alu_req_exe     <= '0;
            rs_addr_exe     <= '0;
            rt_addr_exe     <= '0;
        end else if (mem_request_ack) begin
            store_request   <= '0;
            load_request    <= '0;
        end
    end
    
        // --- Execute 2 Stage Registers ---
    always_ff @(posedge clk) begin
        if (reset) begin
            exe_out_reg    <= '0;
            mem_data_reg <= '0;
            regwe_exe2 <= '0;
            sel_imm_exe2   <= '0;
            set_nzp_exe2    <= '0;
            mem_ldr_we_exe2    <= '0;
            rd_addr_exe2    <= '0;
            mask_exe2    <= '0;
            done_exe2    <= '0;
            bimm_exe2    <= '0;
        end else if (!halt) begin
            exe_out_reg      <= exe_out;
            mem_data_reg     <= mem_to_reg_data;
            regwe_exe2       <= regwe_exe;
            sel_imm_exe2     <= sel_imm_exe;
            set_nzp_exe2     <= set_nzp_exe;
            mem_ldr_we_exe2  <= mem_ldr_we_exe;
            rd_addr_exe2     <= rd_addr_exe;
            mask_exe2        <= mask_exe;
            done_exe2        <= done_exe;
            bimm_exe2        <= bimm_exe;
        end
    end
    
    // --- Writeback Mux ---
    assign rd_data_exe2 = (mem_ldr_we_exe2) ? mem_data_reg :
                          (sel_imm_exe2)   ? {16{bimm_exe2}} :
                                            exe_out_reg;

    // --- Flag Setting ---
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            if (exe_out_reg[i][15])           nzp_flags_next[i] = 3'b100; // N
            else if (exe_out_reg[i] == 16'd0) nzp_flags_next[i] = 3'b010; // Z
            else                              nzp_flags_next[i] = 3'b001; // P
        end
    end
    
    //Flag register set
    always_ff @(posedge clk) begin
        if (reset) begin
            nzp_flags <= '{default: 3'b010};
        end else if (set_nzp_exe2) begin
            nzp_flags <= nzp_flags_next;
        end
    end
    
     //Flag data forwarding, combinational
    always_comb begin
        if (set_nzp_exe2)
            nzp_flags_true = nzp_flags_next;
        else
            nzp_flags_true = nzp_flags;
    end  

    // --- Writeback Stage Registers ---
    always_ff @(posedge clk) begin
        if (reset) begin
            done_wb    <= '0;
            rd_data_wb <= '0;
            rd_addr_wb <= '0;
            regwe_wb   <= '0;
            mask_wb    <= '0;
        end else if (!halt) begin
            rd_data_wb <= rd_data_exe2;
            rd_addr_wb <= rd_addr_exe2;
            regwe_wb   <= regwe_exe2;
            mask_wb    <= mask_exe2;
            done_wb    <= done_exe2;
            //if (done_wb) done <= 1; 
        end
    end
        
    always_ff @(posedge clk) begin
        if (reset)        done <= 1'b0;
        else if (done_wb) done <= 1'b1;
    end
endmodule