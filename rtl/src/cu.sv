//This module consists of combinational logic to set the control signals for the pipeline
//based on instruction received and holds the masking LIFO structure.
module cu (
    // Inputs
    input  logic             clk,
    input  logic             rst,
    input  logic             halt,
    input  logic             scoreboard_stall,
    input  logic [15:0]      instr,
    input  logic [15:0][2:0] nzp_flags,
    // Outputs
    output logic [3:0]       op, 
    output logic [3:0]       rd, 
    output logic [3:0]       rs, 
    output logic [3:0]       rt,
    output logic [15:0]      bimm,
    output logic [15:0]      mask,
    output logic             regwe,
    output logic             store_request,
    output logic             load_request,
    output logic             conc_request,
    output logic             sel_imm,
    output logic             br,
    output logic             set_nzp,
    output logic             done,
    output logic             alu_req_de
);
    localparam NOP   = 4'b0000;
    localparam ADD   = 4'b0011;
    localparam SUB   = 4'b0100;
    localparam MUL   = 4'b0101;
    localparam DIV   = 4'b0110;
    localparam LD    = 4'b0111;
    localparam STR   = 4'b1000;
    localparam IMM   = 4'b1001;
    localparam CMP   = 4'b1010;
    localparam BRnzp = 4'b1011;
    localparam SYNC  = 4'b1100;
    localparam LDC   = 4'b1101;
    localparam STRC  = 4'b1110;
    localparam DONE  = 4'b1111;
    
    assign op = instr[15:12];
    assign rd = instr[11:8];
    assign rs = instr[7:4];
    assign rt = instr[3:0];
    assign bimm = {8'd0, instr[7:0]};
    logic [15:0] mask_in;
    
    //Decoding combination block; Determines which control signals
    //should be high given the instruction
    always_comb begin
        regwe = 0;
        sel_imm = 0;
        load_request = 0;
        store_request = 0;
        conc_request = 0;
        br = 0;
        set_nzp = 0;
        done = 0;
        alu_req_de = 0;
        case(op)
            NOP: 
                regwe = 0;
            ADD: begin
                regwe = 1;
                alu_req_de = 1;
                end
            SUB: begin
                regwe = 1;
                alu_req_de = 1;
                end
            MUL: begin
                regwe = 1;
                alu_req_de = 1;
                end
            DIV: begin
                regwe = 1; 
                alu_req_de = 1;
                end
            LD: begin
                regwe = 1;
                load_request = 1;
                end
            STR:
                store_request = 1;
            IMM: begin 
                regwe = 1;
                sel_imm = 1;
                end

            //Subtraction based comparison instruction
            CMP: begin
                set_nzp = 1;
                alu_req_de = 1;
            end

            //Notes on Branching: If a conditional branch is attempted while the stack of masking (max: 8) 
            //is full, it will be treated as unconditional
            //Additionally, unconditional branches (nzp = 111) do not go to on mask stack
            BRnzp: 
                br = (mask_in != 16'hFFFF); // BRnzp - NOP if no lanes meet condition   

            //Sync pops top mask from stack   
            SYNC: 
                regwe = 0;
  
            //Performs wide load, filling destination register across all threads with consecutive words, starting at address
            //pointed to by associated register in thread 0
            LDC: begin
                regwe = 1;
                load_request = 1;
                conc_request = 1;
                end
            
            //Follows identical logic to LDC for determining addresses to write to
            STRC: begin
                store_request = 1;
                conc_request = 1;
                end
            DONE: 
                done = 1;
            default: 
                regwe = 0; 
        endcase
    end
    
    // Masking Logic 
    // Compute mask for current branch instruction
    always_comb begin
        mask_in = '1;
        for (int i = 0; i < 16; i++) begin
            if ((nzp_flags[i][2] & instr[11]) |
                (nzp_flags[i][1] & instr[10]) |
                (nzp_flags[i][0] & instr[9])) begin
                mask_in[i] = 1'b0;
            end
        end
    end

    //Top memory location on stack doesn't actually get read ever, but to check if thats what we are writing to forces additional
    //logic on timing constrained path
    logic [15:0] stack [0:7];
    logic [3:0]  sp;

    // Stack and mask management
    always_ff @(posedge clk) begin
        if (rst) begin
            stack <= '{default: '0};
            sp    <= '0;
            mask  <= 16'h0000;
        end else if (!halt & !scoreboard_stall) begin
            // Branch: Push mask, doesn't occur if unconditional branch is called
            if ((op == 4'b1011) && (instr[11:9] != 3'b111) && (mask_in != 16'hFFFF) && (sp < 4'd8)) begin
                stack[sp] <= mask_in; 
                sp   <= sp + 1;
                mask <= mask | mask_in;
            end 
            // Sync: Pop mask - recompute from remaining entries
            else if ((op == 4'b1100) && (sp != '0)) begin
                stack[sp - 1] <= '0;
                sp <= sp - 1;
            
                // Recompute mask from entries 0 to sp-2
                case (sp)
                    4'd1: mask <= 16'h0000;
                    4'd2: mask <= stack[0];
                    4'd3: mask <= stack[0] | stack[1];
                    4'd4: mask <= stack[0] | stack[1] | stack[2];
                    4'd5: mask <= stack[0] | stack[1] | stack[2] | stack[3];
                    4'd6: mask <= stack[0] | stack[1] | stack[2] | stack[3] | stack[4];
                    4'd7: mask <= stack[0] | stack[1] | stack[2] | stack[3] | stack[4] | stack[5];
                    4'd8: mask <= stack[0] | stack[1] | stack[2] | stack[3] | stack[4] | stack[5] | stack[6];
                    default: mask <= 16'h0000;
                endcase
            end
        end
    end
endmodule