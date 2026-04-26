module warp_controller (
    input  logic        rst,
    input  logic        clk,
    input  logic [3:0]  store_requests,
    input  logic [3:0]  load_requests,
    input  logic [3:0]  warps_in_mem_queue,
    input  logic [3:0]  warp_idling,
    input  logic [3:0]  warp_done,
    output logic [3:0]  warp_halt
);

    // ── Unified Busy Signal ──────────────────────────────────
    logic [3:0] warp_finished;
    logic [3:0] warp_busy;
    
    assign warp_busy = store_requests 
                     | load_requests 
                     | warps_in_mem_queue 
                     | warp_idling
                     | warp_finished;


    always_ff @(posedge clk or posedge rst) begin
        warp_finished <= rst ? '0 : (warp_done | warp_finished);
    end
    // ── FSM ──────────────────────────────────────────────────
    typedef enum {FULL_HALT, WARP0, WARP1, WARP2, WARP3} state_t;
    state_t state, next_state;

    always_comb begin
        case (state)
            FULL_HALT: begin
                warp_halt = 4'b1111;
                next_state = (~warp_busy[0]) ? WARP0 :
                             (~warp_busy[1]) ? WARP1 :
                             (~warp_busy[2]) ? WARP2 :
                             (~warp_busy[3]) ? WARP3 :
                                               FULL_HALT;
            end

            WARP0: begin
                warp_halt = 4'b1110;
                next_state = (~warp_busy[0]) ? WARP0 :
                             (~warp_busy[1]) ? WARP1 :
                             (~warp_busy[2]) ? WARP2 :
                             (~warp_busy[3]) ? WARP3 :
                                               FULL_HALT;
            end

            WARP1: begin
                warp_halt = 4'b1101;
                next_state = (~warp_busy[1]) ? WARP1 :
                             (~warp_busy[2]) ? WARP2 :
                             (~warp_busy[3]) ? WARP3 :
                             (~warp_busy[0]) ? WARP0 :
                                               FULL_HALT;
            end

            WARP2: begin
                warp_halt = 4'b1011;
                next_state = (~warp_busy[2]) ? WARP2 :
                             (~warp_busy[3]) ? WARP3 :
                             (~warp_busy[0]) ? WARP0 :
                             (~warp_busy[1]) ? WARP1 :
                                               FULL_HALT;
            end

            WARP3: begin
                warp_halt = 4'b0111;
                next_state = (~warp_busy[3]) ? WARP3 :
                             (~warp_busy[0]) ? WARP0 :
                             (~warp_busy[1]) ? WARP1 :
                             (~warp_busy[2]) ? WARP2 :
                                               FULL_HALT;
            end

            default: begin
                warp_halt = 4'b1111;
                next_state = FULL_HALT;
            end
        endcase
    end

    // ── State Register ───────────────────────────────────────
    always_ff @(posedge clk or posedge rst) begin
        state <= rst ? FULL_HALT : next_state;
    end

endmodule