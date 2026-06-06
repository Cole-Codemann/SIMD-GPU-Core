module warp_controller (
    input  logic        rst,
    input  logic        clk,
    input  logic [3:0]  alu_req,
    output logic [3:0]  alu_access
    
);
    typedef enum {FULL_HALT, WARP0, WARP1, WARP2, WARP3} state_t;
    state_t state, next_state;
    (* MAX_FANOUT = 24 *) logic [3:0] next_alu_access;

    always_comb begin
        case (state)
            FULL_HALT: begin
                next_alu_access = 4'b0000;
                next_state = (alu_req[0]) ? WARP0 :
                             (alu_req[1]) ? WARP1 :
                             (alu_req[2]) ? WARP2 :
                             (alu_req[3]) ? WARP3 :
                                            FULL_HALT;
            end
            WARP0: begin
                next_alu_access = 4'b0001;
                next_state = (alu_req[1]) ? WARP1 :
                             (alu_req[2]) ? WARP2 :
                             (alu_req[3]) ? WARP3 :
                             (alu_req[0]) ? WARP0 :
                                            FULL_HALT;
            end
            WARP1: begin
                next_alu_access = 4'b0010;
                next_state = (alu_req[2]) ? WARP2 :
                             (alu_req[3]) ? WARP3 :
                             (alu_req[0]) ? WARP0 :
                             (alu_req[1]) ? WARP1 :
                                            FULL_HALT;
            end
            WARP2: begin
                next_alu_access = 4'b0100;
                next_state = (alu_req[3]) ? WARP3 :
                             (alu_req[0]) ? WARP0 :
                             (alu_req[1]) ? WARP1 :
                             (alu_req[2]) ? WARP2 :
                                            FULL_HALT;
            end
            WARP3: begin
                next_alu_access = 4'b1000;
                next_state = (alu_req[0]) ? WARP0 :
                             (alu_req[1]) ? WARP1 :
                             (alu_req[2]) ? WARP2 :
                             (alu_req[3]) ? WARP3 :
                                            FULL_HALT;
            end
            default: begin
                next_alu_access = 4'b0000;
                next_state = FULL_HALT;
            end
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= FULL_HALT;
            alu_access <= 4'b0000;
        end else begin
            state      <= next_state;
            alu_access <= next_alu_access;
        end
    end
endmodule