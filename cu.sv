//This module consists of combinational logic to set the control signals for the pipeline
//based on instruction received and holds the masking LIFO structure.
module cu (
    // Inputs
    input  logic             clk,
    input  logic             rst,
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
    output logic             sel_imm,
    output logic             br,
    output logic             set_nzp,
    output logic             done
);
    
    assign op = instr[15:12];
    assign rd = instr[11:8];
    assign rs = instr[7:4];
    assign rt = instr[3:0];
    assign bimm = {8'd0, instr[7:0]};
    
    //Decoding combination block; Determines which control signals
    //should be high given the instruction
    always_comb begin
        regwe = 0;
        sel_imm = 0;
        load_request = 0;
        store_request = 0;
        br = 0;
        set_nzp = 0;
        done = 0;
        case(op)
            4'b0000: regwe = 0; //NOP
            4'b0011: regwe = 1; //ADD
            4'b0100: regwe = 1; //SUB
            4'b0101: regwe = 1; //MUL
            4'b0110: regwe = 1; //DIV
            4'b0111: begin      //LDR
                     regwe = 1;
                     load_request = 1;
                     end
            4'b1000: store_request = 1; //STR
            4'b1001: begin      //CONST
                     regwe = 1;
                     sel_imm = 1;
                     end
            4'b1010: set_nzp = 1;
            //Note on Branching: If a conditional branch is attempted while the stack of masking (max: 8) 
            //is full, it will be treated as unconditional
            4'b1011: br = (mask_in != 16'hFFFF); // BRnzp - NOP if no lanes meet condition      
            4'b1100: regwe = 0; //Sync
            4'b1111: done = 1;
            default: regwe = 0; 
        endcase
    end
    
    //Mask Stack
    logic [15:0] stack [0:7];
    logic [3:0] sp; //Stack Pointer
    logic [15:0] mask_in;
   
    //Combination block determining what mask should be, given flags of each branch
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
    
    //Combination block setting mask based on stack
    always_comb begin
        mask = '0;
        for (int i = 0; i < 8; i++) begin
            mask |= stack[i];
        end
    end

    //Simple LIFO, stack architecture for masks 
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            stack <= '{default: '0};
            sp <= '0;
        end else begin
            if ((op == 4'b1011) & (instr[11:9] != 3'b111) & (mask_in != 16'hFFFF)) begin
                stack[sp] <= mask_in;
                sp <= sp + 1;
            end else if ((op == 4'b1100) & (sp != '0)) begin
                stack[sp - 1] <= '0;
                sp <= sp - 1;
            end
        end
    end
endmodule