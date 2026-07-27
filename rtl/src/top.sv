module top (
    // Differential clock input (Genesys 2: 200 MHz LVDS pair)
    input  logic clk_p,
    input  logic clk_n,
 
    // Active-low reset (or pass through pushbutton with inversion in XDC)
    input  logic reset_rtl_0,
 
    // UART to USB bridge
    input  logic uart_rxd,
    output logic uart_txd,
 
    // Status LED
    output logic led_gpu_done,
    output logic led_ddr3_calib,
 
    // DDR3 physical interface (directly to memory chips on PCB)
    output logic [14:0] ddr3_addr,
    output logic [2:0]  ddr3_ba,
    output logic        ddr3_cas_n,
    output logic [0:0]  ddr3_ck_n,
    output logic [0:0]  ddr3_ck_p,
    output logic [0:0]  ddr3_cke,
    output logic [0:0]  ddr3_cs_n,
    output logic [3:0]  ddr3_dm,
    inout  wire  [31:0] ddr3_dq,
    inout  wire  [3:0]  ddr3_dqs_n,
    inout  wire  [3:0]  ddr3_dqs_p,
    output logic [0:0]  ddr3_odt,
    output logic        ddr3_ras_n,
    output logic        ddr3_reset_n,
    output logic        ddr3_we_n
);
 
    // ─────────────────────────────────────────────────────────────────────────
    // CLOCK
    // sys_clk is driven directly by the BD wrapper's clock output port.
    // This is the ONLY clock declaration in this file. Every clock pin
    // downstream - BD ports, IMEM partition, GPU, DMEM - connects to sys_clk
    // by name, never through an `assign` or intermediate `logic`.
    // ─────────────────────────────────────────────────────────────────────────
    wire sys_clk;
   
 
    // ─────────────────────────────────────────────────────────────────────────
    // IMEM AXI BRAM ctrl port A (externalized; BRAM lives in imem_partition)
    // 32-bit din/dout, 13-bit byte-addressed (8 KB = 2048 32-bit words)
    // ─────────────────────────────────────────────────────────────────────────
    logic [12:0]  bram_porta_0_addr;
    logic [31:0]  bram_porta_0_din;
    logic [31:0]  bram_porta_0_dout;
    logic         bram_porta_0_en;
    logic         bram_porta_0_rst;
    logic [3:0]   bram_porta_0_we;
 
    // ─────────────────────────────────────────────────────────────────────────
    // DMEM BRAM port B (BRAM lives inside BD; port B drives the GPU)
    // 128-bit wide for the GPU side
    // ─────────────────────────────────────────────────────────────────────────
    logic [15:0]  dmem_port_addr;
    logic [127:0] dmem_port_din;
    logic [127:0] dmem_port_dout;
    logic         dmem_port_en;
    logic [15:0]  dmem_port_we;
    
    // Second DMEM port B signals
    logic [15:0]  dmem1_port_addr;
    logic [127:0] dmem1_port_din;
    logic [127:0] dmem1_port_dout;
    logic         dmem1_port_en;
    logic [15:0]  dmem1_port_we;
    
    // Second DMEM port B signals
    logic [15:0]  dmem2_port_addr;
    logic [127:0] dmem2_port_din;
    logic [127:0] dmem2_port_dout;
    logic         dmem2_port_en;
    logic [15:0]  dmem2_port_we;
     
    // ─────────────────────────────────────────────────────────────────────────
    // GPIO
    //   gpio_0[0] (output): MicroBlaze drives GPU reset
    //   gpio_0[1] (output): MicroBlaze drives clock counter reset
    //   gpio_0[2] (output): MicroBlaze chooses dmem address space
    //   gpio_0[3] (output): MicroBlaze chooses imem address space
    //   gpio_1 (input):  GPU_done back to MicroBlaze for polling
    // ─────────────────────────────────────────────────────────────────────────
    (* mark_debug = "true" *) logic gpu_reset_from_mb;
    (* mark_debug = "true" *) logic clock_reset_from_mb;
    (* mark_debug = "true" *) logic dmem_addr_space;
    (* mark_debug = "true" *) logic imem_addr_space;
    logic gpu_done_to_mb;
    
    (* mark_debug = "true" *) logic gpu1_reset_from_mb;
    (* mark_debug = "true" *) logic dmem1_addr_space;
    (* mark_debug = "true" *) logic imem1_addr_space;
    logic gpu1_done_to_mb;
    
    (* mark_debug = "true" *) logic gpu2_reset_from_mb;
    (* mark_debug = "true" *) logic dmem2_addr_space;
    (* mark_debug = "true" *) logic imem2_addr_space;
    logic gpu2_done_to_mb;
    
 
    // ─────────────────────────────────────────────────────────────────────────
    // MIG calibration
    // ─────────────────────────────────────────────────────────────────────────
    logic init_calib_complete;
 
    // ─────────────────────────────────────────────────────────────────────────
    // GPU internal nets
    // ─────────────────────────────────────────────────────────────────────────
    logic [10:0]      gpu_dmem_addr; //from GPU
    logic [127:0]     gpu_dmem_wdata;
    logic [15:0]      gpu_dmem_wen;
    logic [127:0]     gpu_dmem_rdata;
 
    logic [3:0][10:0]  gpu_imem_addr; //11 wide, from GPU
    logic [3:0][11:0]  imem_port_addr; //12 wide, into BRAM
    logic [3:0][15:0] gpu_imem_rdata;
 
    (* mark_debug = "true" *) logic             gpu_done;
    
    // Second GPU core nets
    logic [10:0]      gpu1_dmem_addr;
    logic [127:0]     gpu1_dmem_wdata;
    logic [15:0]      gpu1_dmem_wen;
    logic [127:0]     gpu1_dmem_rdata;
    logic [3:0][10:0] gpu1_imem_addr;
    logic [3:0][11:0] imem1_port_addr;
    logic [3:0][15:0] gpu1_imem_rdata;
    logic             gpu1_done;
    
    // Second GPU core nets
    logic [10:0]      gpu2_dmem_addr;
    logic [127:0]     gpu2_dmem_wdata;
    logic [15:0]      gpu2_dmem_wen;
    logic [127:0]     gpu2_dmem_rdata;
    logic [3:0][10:0] gpu2_imem_addr;
    logic [3:0][11:0] imem2_port_addr;
    logic [3:0][15:0] gpu2_imem_rdata;
    logic             gpu2_done;
    
    
    //Total Program Cycle Counting (Starts at first release of GPU)
    (* mark_debug = "true" *) logic reset_prev;
    (* mark_debug = "true" *) logic [31:0] from_init_duration_count; //Counted in this module, controlled by GPIO
    (* mark_debug = "true" *) logic [31:0] program_duration_count; // Counted in GPU, controlled by reset to GPU
    
    always_ff @(posedge sys_clk) begin
        reset_prev <= clock_reset_from_mb;       
        if (reset_prev && !clock_reset_from_mb) begin
            from_init_duration_count <= '0;
        end else if (!clock_reset_from_mb) begin            
            from_init_duration_count <= from_init_duration_count + 32'd1; 
        end
    end
     
    // ─────────────────────────────────────────────────────────────────────────
    // Block design wrapper
    // All clock-port inputs receive sys_clk directly. The wrapper exposes
    // BRAM_PORTA_0_clk as an OUTPUT (it sources the clock from the Clock
    // Wizard inside the BD), so we capture that into sys_clk and feed it
    // back into every other clock pin.
    // ─────────────────────────────────────────────────────────────────────────
GPU_Design_wrapper u_bd (
        // ── 200 MHz differential system clock (direct to MIG) ──────────────
        .SYS_CLK_0_clk_p        (clk_p),
        .SYS_CLK_0_clk_n        (clk_n),
        .reset_rtl_0            (reset_rtl_0),

        // ── UART ───────────────────────────────────────────────────────────
        .uart_rtl_0_txd         (uart_txd),
        .uart_rtl_0_rxd         (uart_rxd),

        // ── GPIO ───────────────────────────────────────────────────────────
        // Ch0 (output): MicroBlaze → GPU reset, Clock reset
        // Ch1 (input):  GPU done → MicroBlaze
        // Ch2 (input, 32b): from_init_duration_count
        // Ch3 (input, 32b): program_duration_count
        .gpio_rtl_0_tri_o       ({imem2_addr_space, dmem2_addr_space, gpu2_reset_from_mb, imem1_addr_space, dmem1_addr_space, gpu1_reset_from_mb, imem_addr_space, dmem_addr_space, clock_reset_from_mb, gpu_reset_from_mb}),
        .gpio_rtl_1_tri_i       ({gpu2_done_to_mb, gpu1_done_to_mb, gpu_done_to_mb}),
        .gpio_rtl_2_tri_i       (from_init_duration_count),
        .gpio_rtl_3_tri_i       (program_duration_count),

        // ── IMEM AXI BRAM ctrl port A ──────────────────────────────────────
        // BRAM_PORTA_0_clk is now an OUTPUT from the BD (MIG's ui_clk).
        // Capture it into sys_clk and feed everything else with it.
        .BRAM_PORTA_0_clk       (sys_clk),
        .BRAM_PORTA_0_addr      (bram_porta_0_addr), //13 wide
        .BRAM_PORTA_0_din       (bram_porta_0_din),
        .BRAM_PORTA_0_dout      (bram_porta_0_dout),
        .BRAM_PORTA_0_en        (bram_porta_0_en),
        .BRAM_PORTA_0_rst       (bram_porta_0_rst),
        .BRAM_PORTA_0_we        (bram_porta_0_we), //4 wide

        // ── DMEM port B ────────────────────────────────────────────────────
        .DataMem_Port_clk       (sys_clk),
        .DataMem_Port_addr      ({16'd0, dmem_port_addr}), //16 wide
        .DataMem_Port_din       (dmem_port_din),
        .DataMem_Port_dout      (dmem_port_dout),
        .DataMem_Port_en        (dmem_port_en),
        .DataMem_Port_rst       (1'b0),
        .DataMem_Port_we        (dmem_port_we),
        
        //DMEM1 port B
        .DataMem1_Port_clk   (sys_clk),
        .DataMem1_Port_addr  ({16'd0, dmem1_port_addr}),
        .DataMem1_Port_din   (dmem1_port_din),
        .DataMem1_Port_dout  (dmem1_port_dout),
        .DataMem1_Port_en    (dmem1_port_en),
        .DataMem1_Port_rst   (1'b0),
        .DataMem1_Port_we    (dmem1_port_we),
        
        //DMEM2 port B
        .DataMem2_Port_clk   (sys_clk),
        .DataMem2_Port_addr  ({16'd0, dmem2_port_addr}),
        .DataMem2_Port_din   (dmem2_port_din),
        .DataMem2_Port_dout  (dmem2_port_dout),
        .DataMem2_Port_en    (dmem2_port_en),
        .DataMem2_Port_rst   (1'b0),
        .DataMem2_Port_we    (dmem2_port_we),
        
        // ── DDR3 physical interface ────────────────────────────────────────
        .DDR3_0_addr            (ddr3_addr),
        .DDR3_0_ba              (ddr3_ba),
        .DDR3_0_cas_n           (ddr3_cas_n),
        .DDR3_0_ck_n            (ddr3_ck_n),
        .DDR3_0_ck_p            (ddr3_ck_p),
        .DDR3_0_cke             (ddr3_cke),
        .DDR3_0_cs_n            (ddr3_cs_n),
        .DDR3_0_dm              (ddr3_dm),
        .DDR3_0_dq              (ddr3_dq),
        .DDR3_0_dqs_n           (ddr3_dqs_n),
        .DDR3_0_dqs_p           (ddr3_dqs_p),
        .DDR3_0_odt             (ddr3_odt),
        .DDR3_0_ras_n           (ddr3_ras_n),
        .DDR3_0_reset_n         (ddr3_reset_n),
        .DDR3_0_we_n            (ddr3_we_n),

        // ── MIG calibration status ─────────────────────────────────────────
        .init_calib_complete_0  (init_calib_complete)
    );
 
    // ─────────────────────────────────────────────────────────────────────────
    // IMEM partition: 4 BRAMs, one per warp.
    //   Port A: AXI BRAM ctrl (MB writes broadcast to all 4 banks)
    //   Port B: dedicated read port per warp
    //
    // Both clocks are sys_clk - single clock domain, no CDC needed.
    // ─────────────────────────────────────────────────────────────────────────
    imem_partition u_imem (
        .bd_clk    (sys_clk),
        .bd_addr   (bram_porta_0_addr), //13 wide
        .bd_din    (bram_porta_0_din),
        .bd_dout   (bram_porta_0_dout),
        .bd_en     (bram_porta_0_en),
        .bd_we     (bram_porta_0_we),
 
        .gpu_clk   (sys_clk),
        .gpu_addr  ({imem2_port_addr, imem1_port_addr, imem_port_addr}),
        .gpu_rdata ({gpu2_imem_rdata, gpu1_imem_rdata, gpu_imem_rdata})
    );
 
    // ─────────────────────────────────────────────────────────────────────────
    // DMEM wiring: GPU drives port B inside the BD
    // ─────────────────────────────────────────────────────────────────────────
    assign dmem_port_addr = {dmem_addr_space, gpu_dmem_addr, 4'b0000}; //15 wide
    assign dmem_port_din  = gpu_dmem_wdata;
    assign dmem_port_we   = gpu_dmem_wen;
    assign dmem_port_en   = 1'b1;
    assign gpu_dmem_rdata = dmem_port_dout;
    
    // DMEM1 wiring (no address space bit needed - each core owns its BRAM)
    assign dmem1_port_addr = {dmem1_addr_space, gpu1_dmem_addr, 4'b0000};
    assign dmem1_port_din  = gpu1_dmem_wdata;
    assign dmem1_port_we   = gpu1_dmem_wen;
    assign dmem1_port_en   = 1'b1;
    assign gpu1_dmem_rdata = dmem1_port_dout;
    
    // DMEM1 wiring (no address space bit needed - each core owns its BRAM)
    assign dmem2_port_addr = {dmem2_addr_space, gpu2_dmem_addr, 4'b0000};
    assign dmem2_port_din  = gpu2_dmem_wdata;
    assign dmem2_port_we   = gpu2_dmem_wen;
    assign dmem2_port_en   = 1'b1;
    assign gpu2_dmem_rdata = dmem2_port_dout;
        
    always_comb begin
        for (int w = 0; w < 4; w++) begin
            imem_port_addr[w]  = {imem_addr_space, gpu_imem_addr[w]};
            imem1_port_addr[w] = {imem1_addr_space, gpu1_imem_addr[w]};
            imem2_port_addr[w] = {imem2_addr_space, gpu2_imem_addr[w]};
        end
    end
 
    // ─────────────────────────────────────────────────────────────────────────
    // GPU
    // ─────────────────────────────────────────────────────────────────────────
    GPU_top u_gpu (
        .clk        (sys_clk),
        .reset_in   (gpu_reset_from_mb),
        .GPU_done   (gpu_done), 
        .dmem_addr  (gpu_dmem_addr), //11 wide
        .dmem_wdata (gpu_dmem_wdata),
        .dmem_wen   (gpu_dmem_wen),
        .dmem_rdata (gpu_dmem_rdata),
 
        .imem_addr  (gpu_imem_addr), //11 wide
        .imem_rdata (gpu_imem_rdata),
        .program_duration_count   (program_duration_count)
    );
    
    // Second GPU core
    GPU_top u_gpu1 (
        .clk        (sys_clk),
        .reset_in   (gpu1_reset_from_mb),
        .GPU_done   (gpu1_done),
        .dmem_addr  (gpu1_dmem_addr),
        .dmem_wdata (gpu1_dmem_wdata),
        .dmem_wen   (gpu1_dmem_wen),
        .dmem_rdata (gpu1_dmem_rdata),
        .imem_addr  (gpu1_imem_addr),
        .imem_rdata (gpu1_imem_rdata),
        .program_duration_count ()
    );
    
        GPU_top u_gpu2 (
        .clk        (sys_clk),
        .reset_in   (gpu2_reset_from_mb),
        .GPU_done   (gpu2_done),
        .dmem_addr  (gpu2_dmem_addr),
        .dmem_wdata (gpu2_dmem_wdata),
        .dmem_wen   (gpu2_dmem_wen),
        .dmem_rdata (gpu2_dmem_rdata),
        .imem_addr  (gpu2_imem_addr),
        .imem_rdata (gpu2_imem_rdata),
        .program_duration_count ()
    );
     
    // ─────────────────────────────────────────────────────────────────────────
    // Status feedback
    // ─────────────────────────────────────────────────────────────────────────
    assign gpu_done_to_mb = gpu_done;
    assign gpu1_done_to_mb = gpu1_done;
    assign gpu2_done_to_mb = gpu2_done;
    assign led_gpu_done   = gpu_done;
    assign led_ddr3_calib = init_calib_complete;
 
endmodule