`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:    Cole Kaufmann
// Module:      top
// Description: FPGA top-level. Integrates the MicroBlaze block design (clock,
//              reset, AXI infrastructure, BRAM controllers for IMEM/DMEM) with
//              the GPU. IMEM lives here as 4 partitioned BRAMs, one per warp,
//              fed by a single AXI BRAM controller in the block design. DMEM
//              BRAM still lives inside the block design and is exposed via
//              DataMem_Port (port B) to the GPU.
//////////////////////////////////////////////////////////////////////////////////

module top (
    // Differential clock input (Genesys 2: 200 MHz LVDS pair)
    input  logic clk_p,
    input  logic clk_n,

    // Active-high reset (or pass through pushbutton with inversion in XDC)
    input  logic reset_rtl_0,

    // UART to USB bridge (if UART added in BD)
    input  logic uart_rxd,
    output logic uart_txd,

    // Status LED
    output logic led_gpu_done
);
    //ToDO: Confirm interfaces for memory

    // ─────────────────────────────────────────────────────────────────────────
    // Block design boundary signals
    // VERIFY these names against GPU_Design_wrapper.v after running
    // Create HDL Wrapper. Vivado derives them from the BD interface names.
    // ─────────────────────────────────────────────────────────────────────────

    // IMEM AXI BRAM ctrl's BRAM port
    // 32-bit din/dout per BD config; addr is 13-bit byte-addressed
    // (8 KB region = 2048 32-bit words).
    logic [12:0]  bram_porta_0_addr;
    logic         bram_porta_0_clk;
    logic [31:0]  bram_porta_0_din;
    logic [31:0]  bram_porta_0_dout;
    logic         bram_porta_0_en;
    logic         bram_porta_0_rst;
    logic [3:0]   bram_porta_0_we;

    // DMEM BRAM port B (still inside BD, exposed to GPU as DataMem_Port)
    // 128-bit wide for the GPU side.
    logic [10:0]  dmem_port_addr;
    logic         dmem_port_clk;
    logic [127:0] dmem_port_din;
    logic [127:0] dmem_port_dout;
    logic         dmem_port_en;
    logic [15:0]  dmem_port_we;

    // GPIO
    //   gpio_0 (output): MB drives GPU reset
    //   gpio_1 (input):  GPU_done back to MB for polling
    logic         gpu_reset_from_mb;
    logic         gpu_done_to_mb;

    // ─────────────────────────────────────────────────────────────────────────
    // Block design wrapper
    // ─────────────────────────────────────────────────────────────────────────
    GPU_Design_wrapper u_bd (
        // Clock and reset
        .diff_clock_rtl_0_clk_p (clk_p),
        .diff_clock_rtl_0_clk_n (clk_n),
        .reset_rtl_0            (reset_rtl_0),

        // UART
        .uart_rtl_0_txd         (uart_txd),
        .uart_rtl_0_rxd         (uart_rxd),

        // GPIO (after reconfiguring AXI GPIO as unidirectional:
        //   Ch1: All Outputs, 1 bit -> GPU reset
        //   Ch2: All Inputs,  1 bit -> GPU done)
        .gpio_rtl_0_tri_o       (gpu_reset_from_mb),
        .gpio_rtl_1_tri_i       (gpu_done_to_mb),

        // IMEM AXI BRAM ctrl's port A (externalized)
        .BRAM_PORTA_0_addr      (bram_porta_0_addr),
        .BRAM_PORTA_0_clk       (bram_porta_0_clk),
        .BRAM_PORTA_0_din       (bram_porta_0_din),
        .BRAM_PORTA_0_dout      (bram_porta_0_dout),
        .BRAM_PORTA_0_en        (bram_porta_0_en),
        .BRAM_PORTA_0_rst       (bram_porta_0_rst),
        .BRAM_PORTA_0_we        (bram_porta_0_we),

        // DMEM port B (BRAM still inside BD)
        .DataMem_Port_addr      (dmem_port_addr),
        .DataMem_Port_clk       (dmem_port_clk),
        .DataMem_Port_din       (dmem_port_din),
        .DataMem_Port_dout      (dmem_port_dout),
        .DataMem_Port_en        (dmem_port_en),
        .DataMem_Port_we        (dmem_port_we)
    );

    // ─────────────────────────────────────────────────────────────────────────
    // GPU internal nets
    // ─────────────────────────────────────────────────────────────────────────
    logic [10:0]      gpu_dmem_addr;
    logic [127:0]     gpu_dmem_wdata;
    logic [15:0]      gpu_dmem_wen;
    logic [127:0]     gpu_dmem_rdata;

    logic [3:0][9:0]  gpu_imem_addr;
    logic [3:0][15:0] gpu_imem_rdata;

    logic             gpu_done;

    // ─────────────────────────────────────────────────────────────────────────
    // System clock - use the AXI BRAM ctrl's clock (same as MicroBlaze).
    // This keeps GPU and MB on the same clock domain (no CDC needed).
    // ─────────────────────────────────────────────────────────────────────────
    logic sys_clk = bram_porta_0_clk;

    // ─────────────────────────────────────────────────────────────────────────
    // IMEM partition: 4 BRAMs, one per warp.
    //   Port A: shared with the AXI BRAM ctrl (MB writes/reads via bank-mux)
    //   Port B: dedicated read port per warp
    //
    // Address layout from MB (byte-addressed):
    //   [13:12] selects which of 4 banks
    //   [11:2]  word index inside that bank's 1024-deep BRAM
    //   [1:0]   byte select (handled by 32-bit din/dout + we[3:0])
    //
    // Each bank stores 1024 × 32-bit, where each 32-bit word holds two
    // 16-bit GPU instructions. The GPU-side read mux uses the LSB of the
    // warp's 10-bit imem address to pick the lower or upper half-word.
    // ─────────────────────────────────────────────────────────────────────────
    imem_partition u_imem (
        // Block design side
        .bd_clk    (bram_porta_0_clk),
        .bd_addr   (bram_porta_0_addr),
        .bd_din    (bram_porta_0_din),
        .bd_dout   (bram_porta_0_dout),
        .bd_en     (bram_porta_0_en),
        .bd_we     (bram_porta_0_we),

        // GPU side
        .gpu_clk   (sys_clk),
        .gpu_addr  (gpu_imem_addr),
        .gpu_rdata (gpu_imem_rdata)
    );

    // ─────────────────────────────────────────────────────────────────────────
    // DMEM wiring: GPU drives the BRAM port B that the BD exposes.
    // ─────────────────────────────────────────────────────────────────────────
    assign dmem_port_clk  = sys_clk;
    assign dmem_port_addr = gpu_dmem_addr;
    assign dmem_port_din  = gpu_dmem_wdata;
    assign dmem_port_we   = gpu_dmem_wen;
    assign dmem_port_en   = 1'b1;
    assign gpu_dmem_rdata = dmem_port_dout;

    // ─────────────────────────────────────────────────────────────────────────
    // GPU
    // ─────────────────────────────────────────────────────────────────────────
    GPU_top u_gpu (
        .clk        (sys_clk),
        .reset      (gpu_reset_from_mb),
        .GPU_done   (gpu_done),

        .dmem_addr  (gpu_dmem_addr),
        .dmem_wdata (gpu_dmem_wdata),
        .dmem_wen   (gpu_dmem_wen),
        .dmem_rdata (gpu_dmem_rdata),

        .imem_addr  (gpu_imem_addr),
        .imem_rdata (gpu_imem_rdata)
    );

    // Feed GPU status back to MB via GPIO and out to a board LED
    assign gpu_done_to_mb = gpu_done;
    assign led_gpu_done   = gpu_done;

endmodule