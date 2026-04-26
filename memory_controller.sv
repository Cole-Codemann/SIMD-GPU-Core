//This controller is in charge of facilitating memory accesses for each thread. 
//As requests come in, this controller will add them to a FIFO queue, responding with an acknoledgement pulse upon doing so
//The controller will then complete each memory request (that isn't masked)
//For stores, it will send a pulse saying the memory request is completed
//For loads, it will accompany the pulse with the full data collected from memory, to be written into the register

// TO-DO / Potential Upgrades:
// 1. Memory coalescing - modern GPUs allow scattered memory access and optimize it. Could be implemented with custom
//    register files to batch non-contiguous lane accesses.
//    a.) This would likely need to be done by changing the Mask reading to load in a queue of addresses at start of STORE_W/LOAD_W
// 2. LOAD_FINISH/STORE_FINISH transitions - investigate whether LOAD_FINISH or STORE_FINISH could skip IDLE and transition
//    directly to STORE_W or LOAD_W if the queue is non-empty, saving one cycle per operation.
module memory_controller (
    // Inputs
    input  logic                     clk,
    input  logic                     rst,
    input  logic [3:0][15:0][15:0]   reg_to_mem_data,  // 4 warps, 16 lanes, 16 bits
    input  logic [3:0][15:0][15:0]   mem_addr,
    input  logic [3:0]               store_requests,    // 1 bit per warp
    input  logic [3:0]               load_requests,     // 1 bit per warp
    input  logic [3:0][15:0]         lane_mask,
    // Outputs
    output logic [3:0]               mem_req_done,
    output logic [15:0][15:0]        mem_to_reg_data,   // 16 lanes of 16-bit words
    output logic [3:0]               warp_waiting,
    output logic [3:0]               mem_request_ack
);

    // ── FSM State ────────────────────────────────────────────
    typedef enum {IDLE, STORE_W, STORE_FINISH, LOAD_W, LOAD_FINISH} state_t;
    state_t state, next_state;

    // ── Warp ID Encoder ──────────────────────────────────────
    // Encodes first requesting warp from one-hot store/load inputs
    logic [1:0] warp_id;
    always_comb begin
        warp_id = 2'd0;
        for (int i = 0; i < 4; i++) begin
            if (store_requests[i] || load_requests[i]) begin
                warp_id = 2'(i);
                break;
            end
        end
    end

    // ── FIFO Queue ───────────────────────────────────────────
    logic [3:0][2:0] memory_queue;  // [2]=Type, [1:0]=WarpID
    logic [1:0]      wr_ptr, rd_ptr;
    logic [1:0]      curr_warp_id;
    logic [2:0]      queue_count;

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
            mem_request_ack <= '0;

            if ((state == STORE_FINISH) || (state == LOAD_FINISH)) begin
                rd_ptr                     <= rd_ptr + 1;
                warp_waiting[curr_warp_id] <= 1'b0;
            end

            if (warp_waiting[warp_id] == 1'b0) begin
                if (|store_requests) begin
                    memory_queue[wr_ptr]     <= {1'b1, warp_id};
                    wr_ptr                   <= wr_ptr + 1;
                    warp_waiting[warp_id]    <= 1'b1;
                    mem_request_ack[warp_id] <= 1'b1;
                end else if (|load_requests) begin
                    memory_queue[wr_ptr]     <= {1'b0, warp_id};
                    wr_ptr                   <= wr_ptr + 1;
                    warp_waiting[warp_id]    <= 1'b1;
                    mem_request_ack[warp_id] <= 1'b1;
                end
            end
            queue_count <= queue_count
                + ((warp_waiting[warp_id] == 1'b0) & (|store_requests | |load_requests) ? 1 : 0)
                - ((state == STORE_FINISH || state == LOAD_FINISH) ? 1 : 0);
        end
    end

    // ── Memory File Instance ─────────────────────────────────
    // Represents full physical memory - demonstrative, can be scaled
    logic        wen;
    logic [15:0] waddr, wdata, raddr, rdata;

    memory_file mem (
        .clk   (clk),
        .rst   (rst),
        .wen   (wen),
        .waddr (waddr),
        .wdata (wdata),
        .raddr (raddr),
        .rdata (rdata)
    );

    // ── FSM Next State Logic ─────────────────────────────────
    logic [3:0] index, next_index;
    logic [15:0][15:0] mem_to_reg_data_int;
    logic last_mem_op, last_mem_op_next;

    always_comb begin
        case (state)
            IDLE:         next_state = (queue_count == 0)             ? IDLE       :
                                       (lane_mask[curr_warp_id] == 16'hFFFF) ? STORE_FINISH :
                                       (memory_queue[rd_ptr][2])      ? STORE_W    : LOAD_W;
            STORE_W:      next_state = (last_mem_op)        ? STORE_FINISH : state;
            STORE_FINISH: next_state = IDLE;
            LOAD_W:       next_state = (last_mem_op)        ? LOAD_FINISH  : state;
            LOAD_FINISH:  next_state = IDLE;
            default:      next_state = IDLE;
        endcase
    end

    // ── FSM State + Counter + Read Data Registers ───────────────────
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            index             <= '0;
            state               <= IDLE;
            mem_to_reg_data_int <= '0;
            last_mem_op         <= '0;
        end else begin
            state               <= next_state;
            index             <= next_index;
            last_mem_op         <= last_mem_op_next;
            if (state == LOAD_W)
                mem_to_reg_data_int[index] <= rdata;
            
        end
    end
    
    // ── Mask Priority Reader ───────────────────
    // search_bits computes the NEXT active lane after the current one.
    // On the first cycle of STORE_W/LOAD_W, counter was seeded by the IDLE
    // priority search (full unshifted mask), so shifting by (counter+1) here
    // correctly finds the second active lane - which is the right next target.
    // On subsequent cycles counter already holds the lane just processed,
    // so (counter+1) continues walking forward through remaining active lanes.
    logic [15:0] curr_mask;
    assign curr_mask = ~lane_mask[curr_warp_id]; //Inverted for simpler logic

    always_comb begin
        logic [15:0] search_bits;
        if (state == IDLE || state == LOAD_FINISH || state == STORE_FINISH) begin
            search_bits = curr_mask;
        end else begin
            search_bits = curr_mask & (16'hFFFF << (index + 1));
        end
        next_index = '0; 
        last_mem_op_next = 1'b1;
        for (int i = 0; i < 16; i++) begin
            if (search_bits[i]) begin
                next_index = i[3:0];
                if ((search_bits & (16'hFFFF << (i + 1))) != 0) begin
                    last_mem_op_next = 1'b0;
                end
                break;
            end
        end
        //if (state == LOAD_FINISH || state == STORE_FINISH) begin
        //    next_counter = '0; 
        //    last_mem_op_next = '0;
        //end
    end

    // ── Output Assignments ───────────────────────────────────
    assign wen             = (state == STORE_W);
    assign waddr           = mem_addr[curr_warp_id][index];
    assign wdata           = reg_to_mem_data[curr_warp_id][index];
    assign raddr           = mem_addr[curr_warp_id][index];
    assign mem_req_done    = (state == LOAD_FINISH || state == STORE_FINISH) ? (4'b0001 << curr_warp_id) : '0;
    assign mem_to_reg_data = mem_to_reg_data_int;

endmodule