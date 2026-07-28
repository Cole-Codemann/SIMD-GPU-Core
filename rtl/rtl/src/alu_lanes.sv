`timescale 1ns / 1ps

//Asynchronous 16 wide alu lanes. All operations assumed to be completed in one clock cycle
//Expected to be one of the largest parts of the footprint to allow for 16 parallel wallace tree multiplier or similar implementation
//Need to implement multicycle div still, single cycle fails on timing.
module alu_lanes (
    // Inputs
    input  logic [15:0][15:0] data1,
    input  logic [15:0][15:0] data2,
    input  logic [3:0]        alu_op,

    // Outputs
    output logic [15:0][15:0] exe_out
);
    localparam ADD = 4'b0011;
    localparam SUB = 4'b0100;
    localparam MUL = 4'b0101;
    localparam DIV = 4'b0110;
    localparam IMM = 4'b1001;
    localparam CMP = 4'b1010;

    always_comb begin
        for (int i = 0; i < 16; i++) begin
            case(alu_op)
                ADD: exe_out[i] = data1[i] + data2[i]; //ADD
                SUB: exe_out[i] = data1[i] - data2[i]; //SUB
                MUL: exe_out[i] = data1[i] * data2[i]; //MUL
                DIV: exe_out[i] = data1[i] * data2[i]; //Not currently configured
                IMM: exe_out[i] = data2[i];            //IMM
                CMP: exe_out[i] = data1[i] - data2[i]; //CMP
                default: exe_out[i] = data2[i]; 
            endcase
        end
    end
endmodule
