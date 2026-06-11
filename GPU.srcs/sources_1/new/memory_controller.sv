//──────────────────────────────────────────────────────────────────────────────
// Memory Controller
//──────────────────────────────────────────────────────────────────────────────
// Handles memory requests from all warps via a FIFO queue.
//
// Request Flow:
//   1. Warp asserts store_requests[i] or load_requests[i]
//   2. Controller ACKs with mem_request_ack[i] and queues the request
//   3. Controller processes queue in FIFO order
//   4. On completion, asserts mem_req_done[i]
//      - For loads: mem_to_reg_data contains read values
//
// Operation Modes:
//   - Sequential (con_request=0): Iterates through unmasked lanes one at a time
//   - Concurrent (con_request=1): Accesses all 16 lanes in 2 BRAM cycles
//
// Masking:
//   - lane_mask[warp][lane]=1 means lane is MASKED (skipped)
//   - lane_mask[warp][lane]=0 means lane is ACTIVE (processed)
//   - If all lanes masked (lane_mask=FFFF), operation completes immediately
//──────────────────────────────────────────────────────────────────────────────

module memory_controller (
    // Inputs
    input  logic                     clk,
    input  logic                     rst,
    input  logic [3:0][15:0][15:0]   reg_to_mem_data,  // 4 warps, 16 lanes, 16 bits
    input  logic [3:0][15:0][15:0]   mem_addr,
    input  logic [3:0]               store_requests,    // 1 bit per warp
    input  logic [3:0]               load_requests,     // 1 bit per warp
    input  logic [3:0]               con_request,       // Comes from warp if memory read is concurrent
    input  logic [3:0][15:0]         lane_mask,
    // Outputs
    output logic [3:0]               mem_req_done,
    output logic [15:0][15:0]        mem_to_reg_data,   // 16 lanes of 16-bit words
    output logic [3:0]               mem_request_ack,
   
    // Memory Interface
    output logic [10:0]             addr,
    output logic [127:0]            wdata,
    output logic [15:0]             wen,
    input  logic [127:0]            rdata
);
    //More vigorous testing needed for concurrent R/W

    // ── FSM State ────────────────────────────────────────────
    typedef enum {IDLE, STORE_W, STORE_FINISH, LOAD_W, STORE_CON_1, STORE_CON_2, LOAD_CON_1, LOAD_CON_2, LOAD_STALL, LOAD_FINISH} state_t;
    state_t state, next_state;

    // ── Warp ID Encoder ──────────────────────────────────────
    // Encodes first requesting warp from one-hot store/load inputs
    logic [4:0] warp_id; //first bit: valid, second bit: store/load, third bit: concurrent request, final two: warp_id
    always_comb begin
        warp_id = 5'd0;
        for (int i = 0; i < 4; i++) begin
            if (store_requests[i]) begin
                warp_id = {2'b11, con_request[i], 2'(i)};
                break;
            end else if (load_requests[i]) begin
                warp_id = {2'b10, con_request[i], 2'(i)};
                break;
            end
        end
    end

    // ── FIFO Queue ───────────────────────────────────────────
    logic [3:0][3:0] memory_queue;  // [3]=R/W, [2]=Concurrent, [1:0]=WarpID
    logic [1:0]      wr_ptr, rd_ptr;
    logic [1:0]      curr_warp_id;
    logic [2:0]      queue_count;
    logic [3:0]      warp_waiting;

    assign curr_warp_id = memory_queue[rd_ptr][1:0];

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            memory_queue    <= '{default: '0};
            rd_ptr          <= '0;
            wr_ptr          <= '0;
            warp_waiting    <= '0;
            queue_count     <= '0;
            mem_request_ack <= '0;
        end else begin
            if ((state == STORE_FINISH) || (state == LOAD_FINISH)) begin
                rd_ptr                     <= rd_ptr + 1;
                warp_waiting[curr_warp_id] <= 1'b0;
            end
           
            mem_request_ack <= '0;
            if (warp_id[4] == 1'b1 && !warp_waiting[warp_id[1:0]]) begin
                memory_queue[wr_ptr]     <= warp_id[3:0];
                wr_ptr                   <= wr_ptr + 1;
                warp_waiting[warp_id[1:0]]    <= 1'b1;
                mem_request_ack[warp_id[1:0]] <= 1'b1;
            end
           
            queue_count <= queue_count
                + ((warp_waiting[warp_id[1:0]] == 1'b0) & (|store_requests | |load_requests) ? 1 : 0)
                - ((state == STORE_FINISH || state == LOAD_FINISH) ? 1 : 0);
        end
    end

    // ── FSM Next State Logic ─────────────────────────────────
    logic [3:0] index, next_index;
    logic [15:0][15:0] mem_to_reg_data_int;
    logic last_mem_op, done_mem;

    always_comb begin
        case (state)
            IDLE: begin
                if (queue_count == 0) next_state = IDLE;
                else if (lane_mask[curr_warp_id] == 16'hFFFF) next_state = STORE_FINISH;
                else if (memory_queue[rd_ptr][2])
                    next_state = (memory_queue[rd_ptr][3]) ? STORE_CON_1 : LOAD_CON_1;
                else
                    next_state = (memory_queue[rd_ptr][3]) ? STORE_W : LOAD_W;  
            end
            STORE_CON_1:  next_state = STORE_CON_2;    
            STORE_CON_2:  next_state = STORE_FINISH;                        
            STORE_W:      next_state = (last_mem_op)       ? STORE_FINISH : state;
            LOAD_CON_1:   next_state = LOAD_CON_2;
            LOAD_CON_2:   next_state = LOAD_STALL;
            LOAD_STALL:   next_state = LOAD_FINISH;
            LOAD_W:       next_state = (done_mem)          ? LOAD_FINISH  : state;
            STORE_FINISH: next_state = IDLE;
            LOAD_FINISH:  next_state = IDLE;
            default:      next_state = IDLE;
        endcase
    end

    logic [2:0] LSB_addr, prev_LSB_addr;
    assign LSB_addr = mem_addr[curr_warp_id][index][2:0];
    
    logic [10:0] con_addr;
    assign con_addr = mem_addr[curr_warp_id][0][13:3];
    
    logic [127:0] wdata_con_1, wdata_con_2;
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            wdata_con_1[i*16 +: 16] = reg_to_mem_data[curr_warp_id][i];
            wdata_con_2[i*16 +: 16] = reg_to_mem_data[curr_warp_id][i+8];
        end
    end
    
    always_comb begin
        case (state)
            STORE_CON_1, LOAD_CON_1:              addr = con_addr;
            STORE_CON_2, LOAD_CON_2, LOAD_STALL:  addr = con_addr + 1;
            default:                              addr = mem_addr[curr_warp_id][index][13:3];
        endcase
    end
    
    always_comb begin
        case (state)
            STORE_CON_1: wdata = wdata_con_1;
            STORE_CON_2: wdata = wdata_con_2;
            default:     wdata = {8{reg_to_mem_data[curr_warp_id][index]}};
        endcase
    end
    
    always_comb begin
        case (state)
            STORE_W:                   wen = 16'h0003 << (LSB_addr * 2);
            STORE_CON_1:               wen = 16'hFFFF;
            STORE_CON_2:               wen = 16'hFFFF;
            default:                   wen = 16'h0000;
        endcase
    end

    // ── FSM State + Index + Read Data Skew Registers ────────────────
    // One-deep skew: with synchronous BRAM reads, rdata for the lane
    // addressed on cycle N arrives on cycle N+1. We track which lane
    // was addressed last cycle (prev_index) and whether it was a real
    // load issue (prev_load_w), so we know where to land rdata.
    logic [3:0] prev_index;
    logic       prev_load_w;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            index      <= '0;
            prev_index <= '0;
            prev_load_w <= 1'b0;
            done_mem   <= '0;
            mem_to_reg_data_int <= '0;
            prev_LSB_addr <= '0;
        end else begin
            state      <= next_state;
            index      <= next_index;
            prev_index <= index;
            prev_load_w <= (state == LOAD_W);
            done_mem   <= last_mem_op;
            prev_LSB_addr <= LSB_addr;
            if (prev_load_w)
                mem_to_reg_data_int[prev_index] <= rdata[prev_LSB_addr*16 +: 16];
            if (state == LOAD_CON_2) begin              // rdata from LOAD_CON_1 arrives now
                for (int i = 0; i < 8; i++)
                    mem_to_reg_data_int[i] <= rdata[i*16 +: 16];
            end
            if (state == LOAD_STALL) begin              // rdata from LOAD_CON_2 arrives now
                for (int i = 0; i < 8; i++)
                    mem_to_reg_data_int[i+8] <= rdata[i*16 +: 16];
            end
        end
    end
   
    // ── Lane Priority Iterator ───────────────────
    // Finds next active lane (curr_mask=1) in ascending order.
    // IDLE/FINISH: starts from lane 0. STORE_W/LOAD_W: continues from index+1.
    // last_mem_op=1 when no active lanes remain.
    logic [15:0] curr_mask;
    assign curr_mask = ~lane_mask[curr_warp_id]; //Inverted for simpler logic - **Now a 1 means it is ACTIVE**

    always_comb begin
        logic [15:0] search_bits;
        if (state == IDLE || state == LOAD_FINISH || state == STORE_FINISH) begin
            search_bits = curr_mask;
        end else begin
            search_bits = curr_mask & (16'hFFFF << (index + 1));
        end
        next_index = '0;
        for (int i = 0; i < 16; i++) begin
            if (search_bits[i]) begin
                next_index = i[3:0];
                break;
            end
        end
        last_mem_op = (search_bits == 16'h0000);
    end

    // ── Output Assignments ───────────────────────────────────
   
    assign mem_req_done    = (state == LOAD_FINISH || state == STORE_FINISH) ? (4'b0001 << curr_warp_id) : '0;
    assign mem_to_reg_data = mem_to_reg_data_int;

endmodule