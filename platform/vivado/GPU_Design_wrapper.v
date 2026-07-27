//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
//Date        : Sat Jun  6 16:28:09 2026
//Host        : Kezar running 64-bit major release  (build 9200)
//Command     : generate_target GPU_Design_wrapper.bd
//Design      : GPU_Design_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module GPU_Design_wrapper
   (BRAM_PORTA_0_addr,
    BRAM_PORTA_0_clk,
    BRAM_PORTA_0_din,
    BRAM_PORTA_0_dout,
    BRAM_PORTA_0_en,
    BRAM_PORTA_0_rst,
    BRAM_PORTA_0_we,
    DataMem_Port_addr,
    DataMem_Port_clk,
    DataMem_Port_din,
    DataMem_Port_dout,
    DataMem_Port_en,
    DataMem_Port_we,
    diff_clock_rtl_0_clk_n,
    diff_clock_rtl_0_clk_p,
    gpio_rtl_0_tri_o,
    gpio_rtl_1_tri_i,
    reset_rtl_0,
    uart_rtl_0_rxd,
    uart_rtl_0_txd);
  output [12:0]BRAM_PORTA_0_addr;
  output BRAM_PORTA_0_clk;
  output [31:0]BRAM_PORTA_0_din;
  input [31:0]BRAM_PORTA_0_dout;
  output BRAM_PORTA_0_en;
  output BRAM_PORTA_0_rst;
  output [3:0]BRAM_PORTA_0_we;
  input [10:0]DataMem_Port_addr;
  input DataMem_Port_clk;
  input [127:0]DataMem_Port_din;
  output [127:0]DataMem_Port_dout;
  input DataMem_Port_en;
  input [15:0]DataMem_Port_we;
  input diff_clock_rtl_0_clk_n;
  input diff_clock_rtl_0_clk_p;
  output [0:0]gpio_rtl_0_tri_o;
  input [0:0]gpio_rtl_1_tri_i;
  input reset_rtl_0;
  input uart_rtl_0_rxd;
  output uart_rtl_0_txd;

  wire [12:0]BRAM_PORTA_0_addr;
  wire BRAM_PORTA_0_clk;
  wire [31:0]BRAM_PORTA_0_din;
  wire [31:0]BRAM_PORTA_0_dout;
  wire BRAM_PORTA_0_en;
  wire BRAM_PORTA_0_rst;
  wire [3:0]BRAM_PORTA_0_we;
  wire [10:0]DataMem_Port_addr;
  wire DataMem_Port_clk;
  wire [127:0]DataMem_Port_din;
  wire [127:0]DataMem_Port_dout;
  wire DataMem_Port_en;
  wire [15:0]DataMem_Port_we;
  wire diff_clock_rtl_0_clk_n;
  wire diff_clock_rtl_0_clk_p;
  wire [0:0]gpio_rtl_0_tri_o;
  wire [0:0]gpio_rtl_1_tri_i;
  wire reset_rtl_0;
  wire uart_rtl_0_rxd;
  wire uart_rtl_0_txd;

  GPU_Design GPU_Design_i
       (.BRAM_PORTA_0_addr(BRAM_PORTA_0_addr),
        .BRAM_PORTA_0_clk(BRAM_PORTA_0_clk),
        .BRAM_PORTA_0_din(BRAM_PORTA_0_din),
        .BRAM_PORTA_0_dout(BRAM_PORTA_0_dout),
        .BRAM_PORTA_0_en(BRAM_PORTA_0_en),
        .BRAM_PORTA_0_rst(BRAM_PORTA_0_rst),
        .BRAM_PORTA_0_we(BRAM_PORTA_0_we),
        .DataMem_Port_addr(DataMem_Port_addr),
        .DataMem_Port_clk(DataMem_Port_clk),
        .DataMem_Port_din(DataMem_Port_din),
        .DataMem_Port_dout(DataMem_Port_dout),
        .DataMem_Port_en(DataMem_Port_en),
        .DataMem_Port_we(DataMem_Port_we),
        .diff_clock_rtl_0_clk_n(diff_clock_rtl_0_clk_n),
        .diff_clock_rtl_0_clk_p(diff_clock_rtl_0_clk_p),
        .gpio_rtl_0_tri_o(gpio_rtl_0_tri_o),
        .gpio_rtl_1_tri_i(gpio_rtl_1_tri_i),
        .reset_rtl_0(reset_rtl_0),
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd));
endmodule
