`timescale 1ns / 1ps

//Asynchronous 16 wide alu lanes. All operations assumed to be completed in one clock cycle
//Expected to be one of the largest parts of the footprint to allow for 16 parallel wallace tree multiplier or similar implementation
//Real hardware will likely take a few clock cycles for harder math (MUL/DIV)
module alu_lanes (
    // Inputs
    input  logic [15:0][15:0] data1,
    input  logic [15:0][15:0] data2,
    input  logic [3:0]        alu_op,

    // Outputs
    output logic [15:0][15:0] exe_out
);

    always_comb begin
        for (int i = 0; i < 16; i++) begin
            case(alu_op)
                4'b0011: exe_out[i] = data1[i] + data2[i]; //ADD
                4'b0100: exe_out[i] = data1[i] - data2[i]; //SUB
                4'b0101: exe_out[i] = data1[i] * data2[i]; //MUL
                4'b0110: exe_out[i] = data1[i] / data2[i]; //DIV
                4'b1001: exe_out[i] = data2[i];            //IMM
                4'b1010: exe_out[i] = data1[i] - data2[i]; //CMP
                default: exe_out[i] = data2[i]; 
            endcase
        end
    end
endmodule
