# top.xdc - Genesys 2 (Kintex-7 XC7K325T-2FFG900C)
#
# Top-level ports defined in top.sv:
#   clk_p, clk_n   - 200 MHz LVDS system clock (bank 33)
#   reset_rtl_0    - CPU reset pushbutton (active-low; see note)
#   uart_rxd       - FPGA UART receive  (from USB-UART bridge)
#   uart_txd       - FPGA UART transmit (to USB-UART bridge)
#   led_gpu_done   - LED0 mirror of GPU_done

# ── 200 MHz differential system clock (LVDS, bank 33) ─────────────────────
set_property -dict {PACKAGE_PIN AD12 IOSTANDARD LVDS} [get_ports clk_p]
set_property -dict {PACKAGE_PIN AD11 IOSTANDARD LVDS} [get_ports clk_n]

# ── CPU reset (CPU_RESETN, active-low pushbutton) ─────────────────────────
# NOTE: This pin is active LOW. The Processor System Reset block in your
# BD must have Ext_Reset_High = 0 (active-low ext_reset_in). If the BD is
# currently configured active-high, either change that parameter or move
# this constraint to a regular pushbutton (e.g. BTNC at E18 LVCMOS12).
set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVCMOS33} [get_ports reset_rtl_0]

# ── UART (USB-UART bridge) ────────────────────────────────────────────────
# Digilent uses terminal-centric naming on the board: their uart_rxd_out
# is the FPGA's TX, and their uart_txd_in is the FPGA's RX.
set_property -dict {PACKAGE_PIN Y20 IOSTANDARD LVCMOS33} [get_ports uart_rxd]
set_property -dict {PACKAGE_PIN Y23 IOSTANDARD LVCMOS33} [get_ports uart_txd]

# ── Status LEDs ───────────────────────────────────────────────────────────
set_property -dict {PACKAGE_PIN T28 IOSTANDARD LVCMOS33} [get_ports led_gpu_done]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {led_warp_done[0]}]
set_property -dict {PACKAGE_PIN U30 IOSTANDARD LVCMOS33} [get_ports {led_warp_done[1]}]
set_property -dict {PACKAGE_PIN U29 IOSTANDARD LVCMOS33} [get_ports {led_warp_done[2]}]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS33} [get_ports {led_warp_done[3]}]
set_property -dict {PACKAGE_PIN W24 IOSTANDARD LVCMOS33} [get_ports led_ddr3_calib]


# ── False paths ───────────────────────────────────────────────────────────
# Async reset input - synchronized by the Processor System Reset block.
set_false_path -from [get_ports reset_rtl_0]
# LED output - visual indicator, no real timing requirement.
set_false_path -to [get_ports led_gpu_done]

# ── Bitstream config (Genesys 2 boots from 1.8 V QSPI flash) ──────────────
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 2 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list u_bd/GPU_Design_i/mig_7series_0/u_GPU_Design_mig_7series_0_2_mig/u_ddr3_infrastructure/CLK]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 11 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {u_gpu1/warp_gen[1].warp_inst/pc[0]} {u_gpu1/warp_gen[1].warp_inst/pc[1]} {u_gpu1/warp_gen[1].warp_inst/pc[2]} {u_gpu1/warp_gen[1].warp_inst/pc[3]} {u_gpu1/warp_gen[1].warp_inst/pc[4]} {u_gpu1/warp_gen[1].warp_inst/pc[5]} {u_gpu1/warp_gen[1].warp_inst/pc[6]} {u_gpu1/warp_gen[1].warp_inst/pc[7]} {u_gpu1/warp_gen[1].warp_inst/pc[8]} {u_gpu1/warp_gen[1].warp_inst/pc[9]} {u_gpu1/warp_gen[1].warp_inst/pc[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 11 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {u_gpu1/warp_gen[2].warp_inst/pc[0]} {u_gpu1/warp_gen[2].warp_inst/pc[1]} {u_gpu1/warp_gen[2].warp_inst/pc[2]} {u_gpu1/warp_gen[2].warp_inst/pc[3]} {u_gpu1/warp_gen[2].warp_inst/pc[4]} {u_gpu1/warp_gen[2].warp_inst/pc[5]} {u_gpu1/warp_gen[2].warp_inst/pc[6]} {u_gpu1/warp_gen[2].warp_inst/pc[7]} {u_gpu1/warp_gen[2].warp_inst/pc[8]} {u_gpu1/warp_gen[2].warp_inst/pc[9]} {u_gpu1/warp_gen[2].warp_inst/pc[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 11 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {u_gpu2/warp_gen[0].warp_inst/pc[0]} {u_gpu2/warp_gen[0].warp_inst/pc[1]} {u_gpu2/warp_gen[0].warp_inst/pc[2]} {u_gpu2/warp_gen[0].warp_inst/pc[3]} {u_gpu2/warp_gen[0].warp_inst/pc[4]} {u_gpu2/warp_gen[0].warp_inst/pc[5]} {u_gpu2/warp_gen[0].warp_inst/pc[6]} {u_gpu2/warp_gen[0].warp_inst/pc[7]} {u_gpu2/warp_gen[0].warp_inst/pc[8]} {u_gpu2/warp_gen[0].warp_inst/pc[9]} {u_gpu2/warp_gen[0].warp_inst/pc[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 11 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {u_gpu2/warp_gen[1].warp_inst/pc[0]} {u_gpu2/warp_gen[1].warp_inst/pc[1]} {u_gpu2/warp_gen[1].warp_inst/pc[2]} {u_gpu2/warp_gen[1].warp_inst/pc[3]} {u_gpu2/warp_gen[1].warp_inst/pc[4]} {u_gpu2/warp_gen[1].warp_inst/pc[5]} {u_gpu2/warp_gen[1].warp_inst/pc[6]} {u_gpu2/warp_gen[1].warp_inst/pc[7]} {u_gpu2/warp_gen[1].warp_inst/pc[8]} {u_gpu2/warp_gen[1].warp_inst/pc[9]} {u_gpu2/warp_gen[1].warp_inst/pc[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 32 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {u_gpu2/u_memory_controller/mem_controller_usage[0]} {u_gpu2/u_memory_controller/mem_controller_usage[1]} {u_gpu2/u_memory_controller/mem_controller_usage[2]} {u_gpu2/u_memory_controller/mem_controller_usage[3]} {u_gpu2/u_memory_controller/mem_controller_usage[4]} {u_gpu2/u_memory_controller/mem_controller_usage[5]} {u_gpu2/u_memory_controller/mem_controller_usage[6]} {u_gpu2/u_memory_controller/mem_controller_usage[7]} {u_gpu2/u_memory_controller/mem_controller_usage[8]} {u_gpu2/u_memory_controller/mem_controller_usage[9]} {u_gpu2/u_memory_controller/mem_controller_usage[10]} {u_gpu2/u_memory_controller/mem_controller_usage[11]} {u_gpu2/u_memory_controller/mem_controller_usage[12]} {u_gpu2/u_memory_controller/mem_controller_usage[13]} {u_gpu2/u_memory_controller/mem_controller_usage[14]} {u_gpu2/u_memory_controller/mem_controller_usage[15]} {u_gpu2/u_memory_controller/mem_controller_usage[16]} {u_gpu2/u_memory_controller/mem_controller_usage[17]} {u_gpu2/u_memory_controller/mem_controller_usage[18]} {u_gpu2/u_memory_controller/mem_controller_usage[19]} {u_gpu2/u_memory_controller/mem_controller_usage[20]} {u_gpu2/u_memory_controller/mem_controller_usage[21]} {u_gpu2/u_memory_controller/mem_controller_usage[22]} {u_gpu2/u_memory_controller/mem_controller_usage[23]} {u_gpu2/u_memory_controller/mem_controller_usage[24]} {u_gpu2/u_memory_controller/mem_controller_usage[25]} {u_gpu2/u_memory_controller/mem_controller_usage[26]} {u_gpu2/u_memory_controller/mem_controller_usage[27]} {u_gpu2/u_memory_controller/mem_controller_usage[28]} {u_gpu2/u_memory_controller/mem_controller_usage[29]} {u_gpu2/u_memory_controller/mem_controller_usage[30]} {u_gpu2/u_memory_controller/mem_controller_usage[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 3 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {u_gpu2/u_memory_controller/queue_count[0]} {u_gpu2/u_memory_controller/queue_count[1]} {u_gpu2/u_memory_controller/queue_count[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 32 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {u_gpu/u_memory_controller/mem_controller_usage[0]} {u_gpu/u_memory_controller/mem_controller_usage[1]} {u_gpu/u_memory_controller/mem_controller_usage[2]} {u_gpu/u_memory_controller/mem_controller_usage[3]} {u_gpu/u_memory_controller/mem_controller_usage[4]} {u_gpu/u_memory_controller/mem_controller_usage[5]} {u_gpu/u_memory_controller/mem_controller_usage[6]} {u_gpu/u_memory_controller/mem_controller_usage[7]} {u_gpu/u_memory_controller/mem_controller_usage[8]} {u_gpu/u_memory_controller/mem_controller_usage[9]} {u_gpu/u_memory_controller/mem_controller_usage[10]} {u_gpu/u_memory_controller/mem_controller_usage[11]} {u_gpu/u_memory_controller/mem_controller_usage[12]} {u_gpu/u_memory_controller/mem_controller_usage[13]} {u_gpu/u_memory_controller/mem_controller_usage[14]} {u_gpu/u_memory_controller/mem_controller_usage[15]} {u_gpu/u_memory_controller/mem_controller_usage[16]} {u_gpu/u_memory_controller/mem_controller_usage[17]} {u_gpu/u_memory_controller/mem_controller_usage[18]} {u_gpu/u_memory_controller/mem_controller_usage[19]} {u_gpu/u_memory_controller/mem_controller_usage[20]} {u_gpu/u_memory_controller/mem_controller_usage[21]} {u_gpu/u_memory_controller/mem_controller_usage[22]} {u_gpu/u_memory_controller/mem_controller_usage[23]} {u_gpu/u_memory_controller/mem_controller_usage[24]} {u_gpu/u_memory_controller/mem_controller_usage[25]} {u_gpu/u_memory_controller/mem_controller_usage[26]} {u_gpu/u_memory_controller/mem_controller_usage[27]} {u_gpu/u_memory_controller/mem_controller_usage[28]} {u_gpu/u_memory_controller/mem_controller_usage[29]} {u_gpu/u_memory_controller/mem_controller_usage[30]} {u_gpu/u_memory_controller/mem_controller_usage[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 3 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {u_gpu/u_memory_controller/queue_count[0]} {u_gpu/u_memory_controller/queue_count[1]} {u_gpu/u_memory_controller/queue_count[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 11 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {u_gpu2/warp_gen[2].warp_inst/pc[0]} {u_gpu2/warp_gen[2].warp_inst/pc[1]} {u_gpu2/warp_gen[2].warp_inst/pc[2]} {u_gpu2/warp_gen[2].warp_inst/pc[3]} {u_gpu2/warp_gen[2].warp_inst/pc[4]} {u_gpu2/warp_gen[2].warp_inst/pc[5]} {u_gpu2/warp_gen[2].warp_inst/pc[6]} {u_gpu2/warp_gen[2].warp_inst/pc[7]} {u_gpu2/warp_gen[2].warp_inst/pc[8]} {u_gpu2/warp_gen[2].warp_inst/pc[9]} {u_gpu2/warp_gen[2].warp_inst/pc[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 11 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {u_gpu2/warp_gen[3].warp_inst/pc[0]} {u_gpu2/warp_gen[3].warp_inst/pc[1]} {u_gpu2/warp_gen[3].warp_inst/pc[2]} {u_gpu2/warp_gen[3].warp_inst/pc[3]} {u_gpu2/warp_gen[3].warp_inst/pc[4]} {u_gpu2/warp_gen[3].warp_inst/pc[5]} {u_gpu2/warp_gen[3].warp_inst/pc[6]} {u_gpu2/warp_gen[3].warp_inst/pc[7]} {u_gpu2/warp_gen[3].warp_inst/pc[8]} {u_gpu2/warp_gen[3].warp_inst/pc[9]} {u_gpu2/warp_gen[3].warp_inst/pc[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 4 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {u_gpu2/alu_req[0]} {u_gpu2/alu_req[1]} {u_gpu2/alu_req[2]} {u_gpu2/alu_req[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 32 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {u_gpu2/alu_stall_count[2][0]} {u_gpu2/alu_stall_count[2][1]} {u_gpu2/alu_stall_count[2][2]} {u_gpu2/alu_stall_count[2][3]} {u_gpu2/alu_stall_count[2][4]} {u_gpu2/alu_stall_count[2][5]} {u_gpu2/alu_stall_count[2][6]} {u_gpu2/alu_stall_count[2][7]} {u_gpu2/alu_stall_count[2][8]} {u_gpu2/alu_stall_count[2][9]} {u_gpu2/alu_stall_count[2][10]} {u_gpu2/alu_stall_count[2][11]} {u_gpu2/alu_stall_count[2][12]} {u_gpu2/alu_stall_count[2][13]} {u_gpu2/alu_stall_count[2][14]} {u_gpu2/alu_stall_count[2][15]} {u_gpu2/alu_stall_count[2][16]} {u_gpu2/alu_stall_count[2][17]} {u_gpu2/alu_stall_count[2][18]} {u_gpu2/alu_stall_count[2][19]} {u_gpu2/alu_stall_count[2][20]} {u_gpu2/alu_stall_count[2][21]} {u_gpu2/alu_stall_count[2][22]} {u_gpu2/alu_stall_count[2][23]} {u_gpu2/alu_stall_count[2][24]} {u_gpu2/alu_stall_count[2][25]} {u_gpu2/alu_stall_count[2][26]} {u_gpu2/alu_stall_count[2][27]} {u_gpu2/alu_stall_count[2][28]} {u_gpu2/alu_stall_count[2][29]} {u_gpu2/alu_stall_count[2][30]} {u_gpu2/alu_stall_count[2][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 32 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {u_gpu2/alu_stall_count[3][0]} {u_gpu2/alu_stall_count[3][1]} {u_gpu2/alu_stall_count[3][2]} {u_gpu2/alu_stall_count[3][3]} {u_gpu2/alu_stall_count[3][4]} {u_gpu2/alu_stall_count[3][5]} {u_gpu2/alu_stall_count[3][6]} {u_gpu2/alu_stall_count[3][7]} {u_gpu2/alu_stall_count[3][8]} {u_gpu2/alu_stall_count[3][9]} {u_gpu2/alu_stall_count[3][10]} {u_gpu2/alu_stall_count[3][11]} {u_gpu2/alu_stall_count[3][12]} {u_gpu2/alu_stall_count[3][13]} {u_gpu2/alu_stall_count[3][14]} {u_gpu2/alu_stall_count[3][15]} {u_gpu2/alu_stall_count[3][16]} {u_gpu2/alu_stall_count[3][17]} {u_gpu2/alu_stall_count[3][18]} {u_gpu2/alu_stall_count[3][19]} {u_gpu2/alu_stall_count[3][20]} {u_gpu2/alu_stall_count[3][21]} {u_gpu2/alu_stall_count[3][22]} {u_gpu2/alu_stall_count[3][23]} {u_gpu2/alu_stall_count[3][24]} {u_gpu2/alu_stall_count[3][25]} {u_gpu2/alu_stall_count[3][26]} {u_gpu2/alu_stall_count[3][27]} {u_gpu2/alu_stall_count[3][28]} {u_gpu2/alu_stall_count[3][29]} {u_gpu2/alu_stall_count[3][30]} {u_gpu2/alu_stall_count[3][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 32 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {u_gpu2/alu_stall_count[1][0]} {u_gpu2/alu_stall_count[1][1]} {u_gpu2/alu_stall_count[1][2]} {u_gpu2/alu_stall_count[1][3]} {u_gpu2/alu_stall_count[1][4]} {u_gpu2/alu_stall_count[1][5]} {u_gpu2/alu_stall_count[1][6]} {u_gpu2/alu_stall_count[1][7]} {u_gpu2/alu_stall_count[1][8]} {u_gpu2/alu_stall_count[1][9]} {u_gpu2/alu_stall_count[1][10]} {u_gpu2/alu_stall_count[1][11]} {u_gpu2/alu_stall_count[1][12]} {u_gpu2/alu_stall_count[1][13]} {u_gpu2/alu_stall_count[1][14]} {u_gpu2/alu_stall_count[1][15]} {u_gpu2/alu_stall_count[1][16]} {u_gpu2/alu_stall_count[1][17]} {u_gpu2/alu_stall_count[1][18]} {u_gpu2/alu_stall_count[1][19]} {u_gpu2/alu_stall_count[1][20]} {u_gpu2/alu_stall_count[1][21]} {u_gpu2/alu_stall_count[1][22]} {u_gpu2/alu_stall_count[1][23]} {u_gpu2/alu_stall_count[1][24]} {u_gpu2/alu_stall_count[1][25]} {u_gpu2/alu_stall_count[1][26]} {u_gpu2/alu_stall_count[1][27]} {u_gpu2/alu_stall_count[1][28]} {u_gpu2/alu_stall_count[1][29]} {u_gpu2/alu_stall_count[1][30]} {u_gpu2/alu_stall_count[1][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 32 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {u_gpu2/alu_usage[0]} {u_gpu2/alu_usage[1]} {u_gpu2/alu_usage[2]} {u_gpu2/alu_usage[3]} {u_gpu2/alu_usage[4]} {u_gpu2/alu_usage[5]} {u_gpu2/alu_usage[6]} {u_gpu2/alu_usage[7]} {u_gpu2/alu_usage[8]} {u_gpu2/alu_usage[9]} {u_gpu2/alu_usage[10]} {u_gpu2/alu_usage[11]} {u_gpu2/alu_usage[12]} {u_gpu2/alu_usage[13]} {u_gpu2/alu_usage[14]} {u_gpu2/alu_usage[15]} {u_gpu2/alu_usage[16]} {u_gpu2/alu_usage[17]} {u_gpu2/alu_usage[18]} {u_gpu2/alu_usage[19]} {u_gpu2/alu_usage[20]} {u_gpu2/alu_usage[21]} {u_gpu2/alu_usage[22]} {u_gpu2/alu_usage[23]} {u_gpu2/alu_usage[24]} {u_gpu2/alu_usage[25]} {u_gpu2/alu_usage[26]} {u_gpu2/alu_usage[27]} {u_gpu2/alu_usage[28]} {u_gpu2/alu_usage[29]} {u_gpu2/alu_usage[30]} {u_gpu2/alu_usage[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 4 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {u_gpu2/alu_access[0]} {u_gpu2/alu_access[1]} {u_gpu2/alu_access[2]} {u_gpu2/alu_access[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 32 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {u_gpu2/alu_stall_count[0][0]} {u_gpu2/alu_stall_count[0][1]} {u_gpu2/alu_stall_count[0][2]} {u_gpu2/alu_stall_count[0][3]} {u_gpu2/alu_stall_count[0][4]} {u_gpu2/alu_stall_count[0][5]} {u_gpu2/alu_stall_count[0][6]} {u_gpu2/alu_stall_count[0][7]} {u_gpu2/alu_stall_count[0][8]} {u_gpu2/alu_stall_count[0][9]} {u_gpu2/alu_stall_count[0][10]} {u_gpu2/alu_stall_count[0][11]} {u_gpu2/alu_stall_count[0][12]} {u_gpu2/alu_stall_count[0][13]} {u_gpu2/alu_stall_count[0][14]} {u_gpu2/alu_stall_count[0][15]} {u_gpu2/alu_stall_count[0][16]} {u_gpu2/alu_stall_count[0][17]} {u_gpu2/alu_stall_count[0][18]} {u_gpu2/alu_stall_count[0][19]} {u_gpu2/alu_stall_count[0][20]} {u_gpu2/alu_stall_count[0][21]} {u_gpu2/alu_stall_count[0][22]} {u_gpu2/alu_stall_count[0][23]} {u_gpu2/alu_stall_count[0][24]} {u_gpu2/alu_stall_count[0][25]} {u_gpu2/alu_stall_count[0][26]} {u_gpu2/alu_stall_count[0][27]} {u_gpu2/alu_stall_count[0][28]} {u_gpu2/alu_stall_count[0][29]} {u_gpu2/alu_stall_count[0][30]} {u_gpu2/alu_stall_count[0][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 32 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {u_gpu2/mem_stall_count[0][0]} {u_gpu2/mem_stall_count[0][1]} {u_gpu2/mem_stall_count[0][2]} {u_gpu2/mem_stall_count[0][3]} {u_gpu2/mem_stall_count[0][4]} {u_gpu2/mem_stall_count[0][5]} {u_gpu2/mem_stall_count[0][6]} {u_gpu2/mem_stall_count[0][7]} {u_gpu2/mem_stall_count[0][8]} {u_gpu2/mem_stall_count[0][9]} {u_gpu2/mem_stall_count[0][10]} {u_gpu2/mem_stall_count[0][11]} {u_gpu2/mem_stall_count[0][12]} {u_gpu2/mem_stall_count[0][13]} {u_gpu2/mem_stall_count[0][14]} {u_gpu2/mem_stall_count[0][15]} {u_gpu2/mem_stall_count[0][16]} {u_gpu2/mem_stall_count[0][17]} {u_gpu2/mem_stall_count[0][18]} {u_gpu2/mem_stall_count[0][19]} {u_gpu2/mem_stall_count[0][20]} {u_gpu2/mem_stall_count[0][21]} {u_gpu2/mem_stall_count[0][22]} {u_gpu2/mem_stall_count[0][23]} {u_gpu2/mem_stall_count[0][24]} {u_gpu2/mem_stall_count[0][25]} {u_gpu2/mem_stall_count[0][26]} {u_gpu2/mem_stall_count[0][27]} {u_gpu2/mem_stall_count[0][28]} {u_gpu2/mem_stall_count[0][29]} {u_gpu2/mem_stall_count[0][30]} {u_gpu2/mem_stall_count[0][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 32 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {u_gpu2/free_run_count[3][0]} {u_gpu2/free_run_count[3][1]} {u_gpu2/free_run_count[3][2]} {u_gpu2/free_run_count[3][3]} {u_gpu2/free_run_count[3][4]} {u_gpu2/free_run_count[3][5]} {u_gpu2/free_run_count[3][6]} {u_gpu2/free_run_count[3][7]} {u_gpu2/free_run_count[3][8]} {u_gpu2/free_run_count[3][9]} {u_gpu2/free_run_count[3][10]} {u_gpu2/free_run_count[3][11]} {u_gpu2/free_run_count[3][12]} {u_gpu2/free_run_count[3][13]} {u_gpu2/free_run_count[3][14]} {u_gpu2/free_run_count[3][15]} {u_gpu2/free_run_count[3][16]} {u_gpu2/free_run_count[3][17]} {u_gpu2/free_run_count[3][18]} {u_gpu2/free_run_count[3][19]} {u_gpu2/free_run_count[3][20]} {u_gpu2/free_run_count[3][21]} {u_gpu2/free_run_count[3][22]} {u_gpu2/free_run_count[3][23]} {u_gpu2/free_run_count[3][24]} {u_gpu2/free_run_count[3][25]} {u_gpu2/free_run_count[3][26]} {u_gpu2/free_run_count[3][27]} {u_gpu2/free_run_count[3][28]} {u_gpu2/free_run_count[3][29]} {u_gpu2/free_run_count[3][30]} {u_gpu2/free_run_count[3][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 32 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {u_gpu2/scoreboard_stall_count[3][0]} {u_gpu2/scoreboard_stall_count[3][1]} {u_gpu2/scoreboard_stall_count[3][2]} {u_gpu2/scoreboard_stall_count[3][3]} {u_gpu2/scoreboard_stall_count[3][4]} {u_gpu2/scoreboard_stall_count[3][5]} {u_gpu2/scoreboard_stall_count[3][6]} {u_gpu2/scoreboard_stall_count[3][7]} {u_gpu2/scoreboard_stall_count[3][8]} {u_gpu2/scoreboard_stall_count[3][9]} {u_gpu2/scoreboard_stall_count[3][10]} {u_gpu2/scoreboard_stall_count[3][11]} {u_gpu2/scoreboard_stall_count[3][12]} {u_gpu2/scoreboard_stall_count[3][13]} {u_gpu2/scoreboard_stall_count[3][14]} {u_gpu2/scoreboard_stall_count[3][15]} {u_gpu2/scoreboard_stall_count[3][16]} {u_gpu2/scoreboard_stall_count[3][17]} {u_gpu2/scoreboard_stall_count[3][18]} {u_gpu2/scoreboard_stall_count[3][19]} {u_gpu2/scoreboard_stall_count[3][20]} {u_gpu2/scoreboard_stall_count[3][21]} {u_gpu2/scoreboard_stall_count[3][22]} {u_gpu2/scoreboard_stall_count[3][23]} {u_gpu2/scoreboard_stall_count[3][24]} {u_gpu2/scoreboard_stall_count[3][25]} {u_gpu2/scoreboard_stall_count[3][26]} {u_gpu2/scoreboard_stall_count[3][27]} {u_gpu2/scoreboard_stall_count[3][28]} {u_gpu2/scoreboard_stall_count[3][29]} {u_gpu2/scoreboard_stall_count[3][30]} {u_gpu2/scoreboard_stall_count[3][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 4 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {u_gpu2/mem_req_done[0]} {u_gpu2/mem_req_done[1]} {u_gpu2/mem_req_done[2]} {u_gpu2/mem_req_done[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 32 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {u_gpu2/mem_stall_count[3][0]} {u_gpu2/mem_stall_count[3][1]} {u_gpu2/mem_stall_count[3][2]} {u_gpu2/mem_stall_count[3][3]} {u_gpu2/mem_stall_count[3][4]} {u_gpu2/mem_stall_count[3][5]} {u_gpu2/mem_stall_count[3][6]} {u_gpu2/mem_stall_count[3][7]} {u_gpu2/mem_stall_count[3][8]} {u_gpu2/mem_stall_count[3][9]} {u_gpu2/mem_stall_count[3][10]} {u_gpu2/mem_stall_count[3][11]} {u_gpu2/mem_stall_count[3][12]} {u_gpu2/mem_stall_count[3][13]} {u_gpu2/mem_stall_count[3][14]} {u_gpu2/mem_stall_count[3][15]} {u_gpu2/mem_stall_count[3][16]} {u_gpu2/mem_stall_count[3][17]} {u_gpu2/mem_stall_count[3][18]} {u_gpu2/mem_stall_count[3][19]} {u_gpu2/mem_stall_count[3][20]} {u_gpu2/mem_stall_count[3][21]} {u_gpu2/mem_stall_count[3][22]} {u_gpu2/mem_stall_count[3][23]} {u_gpu2/mem_stall_count[3][24]} {u_gpu2/mem_stall_count[3][25]} {u_gpu2/mem_stall_count[3][26]} {u_gpu2/mem_stall_count[3][27]} {u_gpu2/mem_stall_count[3][28]} {u_gpu2/mem_stall_count[3][29]} {u_gpu2/mem_stall_count[3][30]} {u_gpu2/mem_stall_count[3][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 4 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {u_gpu2/mem_request_ack[0]} {u_gpu2/mem_request_ack[1]} {u_gpu2/mem_request_ack[2]} {u_gpu2/mem_request_ack[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 32 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list {u_gpu2/free_run_count[0][0]} {u_gpu2/free_run_count[0][1]} {u_gpu2/free_run_count[0][2]} {u_gpu2/free_run_count[0][3]} {u_gpu2/free_run_count[0][4]} {u_gpu2/free_run_count[0][5]} {u_gpu2/free_run_count[0][6]} {u_gpu2/free_run_count[0][7]} {u_gpu2/free_run_count[0][8]} {u_gpu2/free_run_count[0][9]} {u_gpu2/free_run_count[0][10]} {u_gpu2/free_run_count[0][11]} {u_gpu2/free_run_count[0][12]} {u_gpu2/free_run_count[0][13]} {u_gpu2/free_run_count[0][14]} {u_gpu2/free_run_count[0][15]} {u_gpu2/free_run_count[0][16]} {u_gpu2/free_run_count[0][17]} {u_gpu2/free_run_count[0][18]} {u_gpu2/free_run_count[0][19]} {u_gpu2/free_run_count[0][20]} {u_gpu2/free_run_count[0][21]} {u_gpu2/free_run_count[0][22]} {u_gpu2/free_run_count[0][23]} {u_gpu2/free_run_count[0][24]} {u_gpu2/free_run_count[0][25]} {u_gpu2/free_run_count[0][26]} {u_gpu2/free_run_count[0][27]} {u_gpu2/free_run_count[0][28]} {u_gpu2/free_run_count[0][29]} {u_gpu2/free_run_count[0][30]} {u_gpu2/free_run_count[0][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 32 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list {u_gpu2/scoreboard_stall_count[2][0]} {u_gpu2/scoreboard_stall_count[2][1]} {u_gpu2/scoreboard_stall_count[2][2]} {u_gpu2/scoreboard_stall_count[2][3]} {u_gpu2/scoreboard_stall_count[2][4]} {u_gpu2/scoreboard_stall_count[2][5]} {u_gpu2/scoreboard_stall_count[2][6]} {u_gpu2/scoreboard_stall_count[2][7]} {u_gpu2/scoreboard_stall_count[2][8]} {u_gpu2/scoreboard_stall_count[2][9]} {u_gpu2/scoreboard_stall_count[2][10]} {u_gpu2/scoreboard_stall_count[2][11]} {u_gpu2/scoreboard_stall_count[2][12]} {u_gpu2/scoreboard_stall_count[2][13]} {u_gpu2/scoreboard_stall_count[2][14]} {u_gpu2/scoreboard_stall_count[2][15]} {u_gpu2/scoreboard_stall_count[2][16]} {u_gpu2/scoreboard_stall_count[2][17]} {u_gpu2/scoreboard_stall_count[2][18]} {u_gpu2/scoreboard_stall_count[2][19]} {u_gpu2/scoreboard_stall_count[2][20]} {u_gpu2/scoreboard_stall_count[2][21]} {u_gpu2/scoreboard_stall_count[2][22]} {u_gpu2/scoreboard_stall_count[2][23]} {u_gpu2/scoreboard_stall_count[2][24]} {u_gpu2/scoreboard_stall_count[2][25]} {u_gpu2/scoreboard_stall_count[2][26]} {u_gpu2/scoreboard_stall_count[2][27]} {u_gpu2/scoreboard_stall_count[2][28]} {u_gpu2/scoreboard_stall_count[2][29]} {u_gpu2/scoreboard_stall_count[2][30]} {u_gpu2/scoreboard_stall_count[2][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
set_property port_width 32 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list {u_gpu2/mem_stall_count[2][0]} {u_gpu2/mem_stall_count[2][1]} {u_gpu2/mem_stall_count[2][2]} {u_gpu2/mem_stall_count[2][3]} {u_gpu2/mem_stall_count[2][4]} {u_gpu2/mem_stall_count[2][5]} {u_gpu2/mem_stall_count[2][6]} {u_gpu2/mem_stall_count[2][7]} {u_gpu2/mem_stall_count[2][8]} {u_gpu2/mem_stall_count[2][9]} {u_gpu2/mem_stall_count[2][10]} {u_gpu2/mem_stall_count[2][11]} {u_gpu2/mem_stall_count[2][12]} {u_gpu2/mem_stall_count[2][13]} {u_gpu2/mem_stall_count[2][14]} {u_gpu2/mem_stall_count[2][15]} {u_gpu2/mem_stall_count[2][16]} {u_gpu2/mem_stall_count[2][17]} {u_gpu2/mem_stall_count[2][18]} {u_gpu2/mem_stall_count[2][19]} {u_gpu2/mem_stall_count[2][20]} {u_gpu2/mem_stall_count[2][21]} {u_gpu2/mem_stall_count[2][22]} {u_gpu2/mem_stall_count[2][23]} {u_gpu2/mem_stall_count[2][24]} {u_gpu2/mem_stall_count[2][25]} {u_gpu2/mem_stall_count[2][26]} {u_gpu2/mem_stall_count[2][27]} {u_gpu2/mem_stall_count[2][28]} {u_gpu2/mem_stall_count[2][29]} {u_gpu2/mem_stall_count[2][30]} {u_gpu2/mem_stall_count[2][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
set_property port_width 32 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list {u_gpu2/free_run_count[1][0]} {u_gpu2/free_run_count[1][1]} {u_gpu2/free_run_count[1][2]} {u_gpu2/free_run_count[1][3]} {u_gpu2/free_run_count[1][4]} {u_gpu2/free_run_count[1][5]} {u_gpu2/free_run_count[1][6]} {u_gpu2/free_run_count[1][7]} {u_gpu2/free_run_count[1][8]} {u_gpu2/free_run_count[1][9]} {u_gpu2/free_run_count[1][10]} {u_gpu2/free_run_count[1][11]} {u_gpu2/free_run_count[1][12]} {u_gpu2/free_run_count[1][13]} {u_gpu2/free_run_count[1][14]} {u_gpu2/free_run_count[1][15]} {u_gpu2/free_run_count[1][16]} {u_gpu2/free_run_count[1][17]} {u_gpu2/free_run_count[1][18]} {u_gpu2/free_run_count[1][19]} {u_gpu2/free_run_count[1][20]} {u_gpu2/free_run_count[1][21]} {u_gpu2/free_run_count[1][22]} {u_gpu2/free_run_count[1][23]} {u_gpu2/free_run_count[1][24]} {u_gpu2/free_run_count[1][25]} {u_gpu2/free_run_count[1][26]} {u_gpu2/free_run_count[1][27]} {u_gpu2/free_run_count[1][28]} {u_gpu2/free_run_count[1][29]} {u_gpu2/free_run_count[1][30]} {u_gpu2/free_run_count[1][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
set_property port_width 32 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list {u_gpu2/mem_stall_count[1][0]} {u_gpu2/mem_stall_count[1][1]} {u_gpu2/mem_stall_count[1][2]} {u_gpu2/mem_stall_count[1][3]} {u_gpu2/mem_stall_count[1][4]} {u_gpu2/mem_stall_count[1][5]} {u_gpu2/mem_stall_count[1][6]} {u_gpu2/mem_stall_count[1][7]} {u_gpu2/mem_stall_count[1][8]} {u_gpu2/mem_stall_count[1][9]} {u_gpu2/mem_stall_count[1][10]} {u_gpu2/mem_stall_count[1][11]} {u_gpu2/mem_stall_count[1][12]} {u_gpu2/mem_stall_count[1][13]} {u_gpu2/mem_stall_count[1][14]} {u_gpu2/mem_stall_count[1][15]} {u_gpu2/mem_stall_count[1][16]} {u_gpu2/mem_stall_count[1][17]} {u_gpu2/mem_stall_count[1][18]} {u_gpu2/mem_stall_count[1][19]} {u_gpu2/mem_stall_count[1][20]} {u_gpu2/mem_stall_count[1][21]} {u_gpu2/mem_stall_count[1][22]} {u_gpu2/mem_stall_count[1][23]} {u_gpu2/mem_stall_count[1][24]} {u_gpu2/mem_stall_count[1][25]} {u_gpu2/mem_stall_count[1][26]} {u_gpu2/mem_stall_count[1][27]} {u_gpu2/mem_stall_count[1][28]} {u_gpu2/mem_stall_count[1][29]} {u_gpu2/mem_stall_count[1][30]} {u_gpu2/mem_stall_count[1][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
set_property port_width 32 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list {u_gpu2/free_run_count[2][0]} {u_gpu2/free_run_count[2][1]} {u_gpu2/free_run_count[2][2]} {u_gpu2/free_run_count[2][3]} {u_gpu2/free_run_count[2][4]} {u_gpu2/free_run_count[2][5]} {u_gpu2/free_run_count[2][6]} {u_gpu2/free_run_count[2][7]} {u_gpu2/free_run_count[2][8]} {u_gpu2/free_run_count[2][9]} {u_gpu2/free_run_count[2][10]} {u_gpu2/free_run_count[2][11]} {u_gpu2/free_run_count[2][12]} {u_gpu2/free_run_count[2][13]} {u_gpu2/free_run_count[2][14]} {u_gpu2/free_run_count[2][15]} {u_gpu2/free_run_count[2][16]} {u_gpu2/free_run_count[2][17]} {u_gpu2/free_run_count[2][18]} {u_gpu2/free_run_count[2][19]} {u_gpu2/free_run_count[2][20]} {u_gpu2/free_run_count[2][21]} {u_gpu2/free_run_count[2][22]} {u_gpu2/free_run_count[2][23]} {u_gpu2/free_run_count[2][24]} {u_gpu2/free_run_count[2][25]} {u_gpu2/free_run_count[2][26]} {u_gpu2/free_run_count[2][27]} {u_gpu2/free_run_count[2][28]} {u_gpu2/free_run_count[2][29]} {u_gpu2/free_run_count[2][30]} {u_gpu2/free_run_count[2][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
set_property port_width 32 [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list {u_gpu2/scoreboard_stall_count[0][0]} {u_gpu2/scoreboard_stall_count[0][1]} {u_gpu2/scoreboard_stall_count[0][2]} {u_gpu2/scoreboard_stall_count[0][3]} {u_gpu2/scoreboard_stall_count[0][4]} {u_gpu2/scoreboard_stall_count[0][5]} {u_gpu2/scoreboard_stall_count[0][6]} {u_gpu2/scoreboard_stall_count[0][7]} {u_gpu2/scoreboard_stall_count[0][8]} {u_gpu2/scoreboard_stall_count[0][9]} {u_gpu2/scoreboard_stall_count[0][10]} {u_gpu2/scoreboard_stall_count[0][11]} {u_gpu2/scoreboard_stall_count[0][12]} {u_gpu2/scoreboard_stall_count[0][13]} {u_gpu2/scoreboard_stall_count[0][14]} {u_gpu2/scoreboard_stall_count[0][15]} {u_gpu2/scoreboard_stall_count[0][16]} {u_gpu2/scoreboard_stall_count[0][17]} {u_gpu2/scoreboard_stall_count[0][18]} {u_gpu2/scoreboard_stall_count[0][19]} {u_gpu2/scoreboard_stall_count[0][20]} {u_gpu2/scoreboard_stall_count[0][21]} {u_gpu2/scoreboard_stall_count[0][22]} {u_gpu2/scoreboard_stall_count[0][23]} {u_gpu2/scoreboard_stall_count[0][24]} {u_gpu2/scoreboard_stall_count[0][25]} {u_gpu2/scoreboard_stall_count[0][26]} {u_gpu2/scoreboard_stall_count[0][27]} {u_gpu2/scoreboard_stall_count[0][28]} {u_gpu2/scoreboard_stall_count[0][29]} {u_gpu2/scoreboard_stall_count[0][30]} {u_gpu2/scoreboard_stall_count[0][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
set_property port_width 32 [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list {u_gpu2/scoreboard_stall_count[1][0]} {u_gpu2/scoreboard_stall_count[1][1]} {u_gpu2/scoreboard_stall_count[1][2]} {u_gpu2/scoreboard_stall_count[1][3]} {u_gpu2/scoreboard_stall_count[1][4]} {u_gpu2/scoreboard_stall_count[1][5]} {u_gpu2/scoreboard_stall_count[1][6]} {u_gpu2/scoreboard_stall_count[1][7]} {u_gpu2/scoreboard_stall_count[1][8]} {u_gpu2/scoreboard_stall_count[1][9]} {u_gpu2/scoreboard_stall_count[1][10]} {u_gpu2/scoreboard_stall_count[1][11]} {u_gpu2/scoreboard_stall_count[1][12]} {u_gpu2/scoreboard_stall_count[1][13]} {u_gpu2/scoreboard_stall_count[1][14]} {u_gpu2/scoreboard_stall_count[1][15]} {u_gpu2/scoreboard_stall_count[1][16]} {u_gpu2/scoreboard_stall_count[1][17]} {u_gpu2/scoreboard_stall_count[1][18]} {u_gpu2/scoreboard_stall_count[1][19]} {u_gpu2/scoreboard_stall_count[1][20]} {u_gpu2/scoreboard_stall_count[1][21]} {u_gpu2/scoreboard_stall_count[1][22]} {u_gpu2/scoreboard_stall_count[1][23]} {u_gpu2/scoreboard_stall_count[1][24]} {u_gpu2/scoreboard_stall_count[1][25]} {u_gpu2/scoreboard_stall_count[1][26]} {u_gpu2/scoreboard_stall_count[1][27]} {u_gpu2/scoreboard_stall_count[1][28]} {u_gpu2/scoreboard_stall_count[1][29]} {u_gpu2/scoreboard_stall_count[1][30]} {u_gpu2/scoreboard_stall_count[1][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
set_property port_width 11 [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list {u_gpu/warp_gen[1].warp_inst/pc[0]} {u_gpu/warp_gen[1].warp_inst/pc[1]} {u_gpu/warp_gen[1].warp_inst/pc[2]} {u_gpu/warp_gen[1].warp_inst/pc[3]} {u_gpu/warp_gen[1].warp_inst/pc[4]} {u_gpu/warp_gen[1].warp_inst/pc[5]} {u_gpu/warp_gen[1].warp_inst/pc[6]} {u_gpu/warp_gen[1].warp_inst/pc[7]} {u_gpu/warp_gen[1].warp_inst/pc[8]} {u_gpu/warp_gen[1].warp_inst/pc[9]} {u_gpu/warp_gen[1].warp_inst/pc[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe32]
set_property port_width 11 [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list {u_gpu/warp_gen[0].warp_inst/pc[0]} {u_gpu/warp_gen[0].warp_inst/pc[1]} {u_gpu/warp_gen[0].warp_inst/pc[2]} {u_gpu/warp_gen[0].warp_inst/pc[3]} {u_gpu/warp_gen[0].warp_inst/pc[4]} {u_gpu/warp_gen[0].warp_inst/pc[5]} {u_gpu/warp_gen[0].warp_inst/pc[6]} {u_gpu/warp_gen[0].warp_inst/pc[7]} {u_gpu/warp_gen[0].warp_inst/pc[8]} {u_gpu/warp_gen[0].warp_inst/pc[9]} {u_gpu/warp_gen[0].warp_inst/pc[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe33]
set_property port_width 32 [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list {u_gpu1/u_memory_controller/mem_controller_usage[0]} {u_gpu1/u_memory_controller/mem_controller_usage[1]} {u_gpu1/u_memory_controller/mem_controller_usage[2]} {u_gpu1/u_memory_controller/mem_controller_usage[3]} {u_gpu1/u_memory_controller/mem_controller_usage[4]} {u_gpu1/u_memory_controller/mem_controller_usage[5]} {u_gpu1/u_memory_controller/mem_controller_usage[6]} {u_gpu1/u_memory_controller/mem_controller_usage[7]} {u_gpu1/u_memory_controller/mem_controller_usage[8]} {u_gpu1/u_memory_controller/mem_controller_usage[9]} {u_gpu1/u_memory_controller/mem_controller_usage[10]} {u_gpu1/u_memory_controller/mem_controller_usage[11]} {u_gpu1/u_memory_controller/mem_controller_usage[12]} {u_gpu1/u_memory_controller/mem_controller_usage[13]} {u_gpu1/u_memory_controller/mem_controller_usage[14]} {u_gpu1/u_memory_controller/mem_controller_usage[15]} {u_gpu1/u_memory_controller/mem_controller_usage[16]} {u_gpu1/u_memory_controller/mem_controller_usage[17]} {u_gpu1/u_memory_controller/mem_controller_usage[18]} {u_gpu1/u_memory_controller/mem_controller_usage[19]} {u_gpu1/u_memory_controller/mem_controller_usage[20]} {u_gpu1/u_memory_controller/mem_controller_usage[21]} {u_gpu1/u_memory_controller/mem_controller_usage[22]} {u_gpu1/u_memory_controller/mem_controller_usage[23]} {u_gpu1/u_memory_controller/mem_controller_usage[24]} {u_gpu1/u_memory_controller/mem_controller_usage[25]} {u_gpu1/u_memory_controller/mem_controller_usage[26]} {u_gpu1/u_memory_controller/mem_controller_usage[27]} {u_gpu1/u_memory_controller/mem_controller_usage[28]} {u_gpu1/u_memory_controller/mem_controller_usage[29]} {u_gpu1/u_memory_controller/mem_controller_usage[30]} {u_gpu1/u_memory_controller/mem_controller_usage[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe34]
set_property port_width 3 [get_debug_ports u_ila_0/probe34]
connect_debug_port u_ila_0/probe34 [get_nets [list {u_gpu1/u_memory_controller/queue_count[0]} {u_gpu1/u_memory_controller/queue_count[1]} {u_gpu1/u_memory_controller/queue_count[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe35]
set_property port_width 11 [get_debug_ports u_ila_0/probe35]
connect_debug_port u_ila_0/probe35 [get_nets [list {u_gpu/warp_gen[2].warp_inst/pc[0]} {u_gpu/warp_gen[2].warp_inst/pc[1]} {u_gpu/warp_gen[2].warp_inst/pc[2]} {u_gpu/warp_gen[2].warp_inst/pc[3]} {u_gpu/warp_gen[2].warp_inst/pc[4]} {u_gpu/warp_gen[2].warp_inst/pc[5]} {u_gpu/warp_gen[2].warp_inst/pc[6]} {u_gpu/warp_gen[2].warp_inst/pc[7]} {u_gpu/warp_gen[2].warp_inst/pc[8]} {u_gpu/warp_gen[2].warp_inst/pc[9]} {u_gpu/warp_gen[2].warp_inst/pc[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe36]
set_property port_width 11 [get_debug_ports u_ila_0/probe36]
connect_debug_port u_ila_0/probe36 [get_nets [list {u_gpu/warp_gen[3].warp_inst/pc[0]} {u_gpu/warp_gen[3].warp_inst/pc[1]} {u_gpu/warp_gen[3].warp_inst/pc[2]} {u_gpu/warp_gen[3].warp_inst/pc[3]} {u_gpu/warp_gen[3].warp_inst/pc[4]} {u_gpu/warp_gen[3].warp_inst/pc[5]} {u_gpu/warp_gen[3].warp_inst/pc[6]} {u_gpu/warp_gen[3].warp_inst/pc[7]} {u_gpu/warp_gen[3].warp_inst/pc[8]} {u_gpu/warp_gen[3].warp_inst/pc[9]} {u_gpu/warp_gen[3].warp_inst/pc[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe37]
set_property port_width 4 [get_debug_ports u_ila_0/probe37]
connect_debug_port u_ila_0/probe37 [get_nets [list {u_gpu/alu_access[0]} {u_gpu/alu_access[1]} {u_gpu/alu_access[2]} {u_gpu/alu_access[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe38]
set_property port_width 32 [get_debug_ports u_ila_0/probe38]
connect_debug_port u_ila_0/probe38 [get_nets [list {u_gpu/alu_stall_count[1][0]} {u_gpu/alu_stall_count[1][1]} {u_gpu/alu_stall_count[1][2]} {u_gpu/alu_stall_count[1][3]} {u_gpu/alu_stall_count[1][4]} {u_gpu/alu_stall_count[1][5]} {u_gpu/alu_stall_count[1][6]} {u_gpu/alu_stall_count[1][7]} {u_gpu/alu_stall_count[1][8]} {u_gpu/alu_stall_count[1][9]} {u_gpu/alu_stall_count[1][10]} {u_gpu/alu_stall_count[1][11]} {u_gpu/alu_stall_count[1][12]} {u_gpu/alu_stall_count[1][13]} {u_gpu/alu_stall_count[1][14]} {u_gpu/alu_stall_count[1][15]} {u_gpu/alu_stall_count[1][16]} {u_gpu/alu_stall_count[1][17]} {u_gpu/alu_stall_count[1][18]} {u_gpu/alu_stall_count[1][19]} {u_gpu/alu_stall_count[1][20]} {u_gpu/alu_stall_count[1][21]} {u_gpu/alu_stall_count[1][22]} {u_gpu/alu_stall_count[1][23]} {u_gpu/alu_stall_count[1][24]} {u_gpu/alu_stall_count[1][25]} {u_gpu/alu_stall_count[1][26]} {u_gpu/alu_stall_count[1][27]} {u_gpu/alu_stall_count[1][28]} {u_gpu/alu_stall_count[1][29]} {u_gpu/alu_stall_count[1][30]} {u_gpu/alu_stall_count[1][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe39]
set_property port_width 32 [get_debug_ports u_ila_0/probe39]
connect_debug_port u_ila_0/probe39 [get_nets [list {u_gpu/free_run_count[0][0]} {u_gpu/free_run_count[0][1]} {u_gpu/free_run_count[0][2]} {u_gpu/free_run_count[0][3]} {u_gpu/free_run_count[0][4]} {u_gpu/free_run_count[0][5]} {u_gpu/free_run_count[0][6]} {u_gpu/free_run_count[0][7]} {u_gpu/free_run_count[0][8]} {u_gpu/free_run_count[0][9]} {u_gpu/free_run_count[0][10]} {u_gpu/free_run_count[0][11]} {u_gpu/free_run_count[0][12]} {u_gpu/free_run_count[0][13]} {u_gpu/free_run_count[0][14]} {u_gpu/free_run_count[0][15]} {u_gpu/free_run_count[0][16]} {u_gpu/free_run_count[0][17]} {u_gpu/free_run_count[0][18]} {u_gpu/free_run_count[0][19]} {u_gpu/free_run_count[0][20]} {u_gpu/free_run_count[0][21]} {u_gpu/free_run_count[0][22]} {u_gpu/free_run_count[0][23]} {u_gpu/free_run_count[0][24]} {u_gpu/free_run_count[0][25]} {u_gpu/free_run_count[0][26]} {u_gpu/free_run_count[0][27]} {u_gpu/free_run_count[0][28]} {u_gpu/free_run_count[0][29]} {u_gpu/free_run_count[0][30]} {u_gpu/free_run_count[0][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe40]
set_property port_width 32 [get_debug_ports u_ila_0/probe40]
connect_debug_port u_ila_0/probe40 [get_nets [list {u_gpu/free_run_count[1][0]} {u_gpu/free_run_count[1][1]} {u_gpu/free_run_count[1][2]} {u_gpu/free_run_count[1][3]} {u_gpu/free_run_count[1][4]} {u_gpu/free_run_count[1][5]} {u_gpu/free_run_count[1][6]} {u_gpu/free_run_count[1][7]} {u_gpu/free_run_count[1][8]} {u_gpu/free_run_count[1][9]} {u_gpu/free_run_count[1][10]} {u_gpu/free_run_count[1][11]} {u_gpu/free_run_count[1][12]} {u_gpu/free_run_count[1][13]} {u_gpu/free_run_count[1][14]} {u_gpu/free_run_count[1][15]} {u_gpu/free_run_count[1][16]} {u_gpu/free_run_count[1][17]} {u_gpu/free_run_count[1][18]} {u_gpu/free_run_count[1][19]} {u_gpu/free_run_count[1][20]} {u_gpu/free_run_count[1][21]} {u_gpu/free_run_count[1][22]} {u_gpu/free_run_count[1][23]} {u_gpu/free_run_count[1][24]} {u_gpu/free_run_count[1][25]} {u_gpu/free_run_count[1][26]} {u_gpu/free_run_count[1][27]} {u_gpu/free_run_count[1][28]} {u_gpu/free_run_count[1][29]} {u_gpu/free_run_count[1][30]} {u_gpu/free_run_count[1][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe41]
set_property port_width 32 [get_debug_ports u_ila_0/probe41]
connect_debug_port u_ila_0/probe41 [get_nets [list {u_gpu/free_run_count[2][0]} {u_gpu/free_run_count[2][1]} {u_gpu/free_run_count[2][2]} {u_gpu/free_run_count[2][3]} {u_gpu/free_run_count[2][4]} {u_gpu/free_run_count[2][5]} {u_gpu/free_run_count[2][6]} {u_gpu/free_run_count[2][7]} {u_gpu/free_run_count[2][8]} {u_gpu/free_run_count[2][9]} {u_gpu/free_run_count[2][10]} {u_gpu/free_run_count[2][11]} {u_gpu/free_run_count[2][12]} {u_gpu/free_run_count[2][13]} {u_gpu/free_run_count[2][14]} {u_gpu/free_run_count[2][15]} {u_gpu/free_run_count[2][16]} {u_gpu/free_run_count[2][17]} {u_gpu/free_run_count[2][18]} {u_gpu/free_run_count[2][19]} {u_gpu/free_run_count[2][20]} {u_gpu/free_run_count[2][21]} {u_gpu/free_run_count[2][22]} {u_gpu/free_run_count[2][23]} {u_gpu/free_run_count[2][24]} {u_gpu/free_run_count[2][25]} {u_gpu/free_run_count[2][26]} {u_gpu/free_run_count[2][27]} {u_gpu/free_run_count[2][28]} {u_gpu/free_run_count[2][29]} {u_gpu/free_run_count[2][30]} {u_gpu/free_run_count[2][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe42]
set_property port_width 4 [get_debug_ports u_ila_0/probe42]
connect_debug_port u_ila_0/probe42 [get_nets [list {u_gpu/alu_req[0]} {u_gpu/alu_req[1]} {u_gpu/alu_req[2]} {u_gpu/alu_req[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe43]
set_property port_width 32 [get_debug_ports u_ila_0/probe43]
connect_debug_port u_ila_0/probe43 [get_nets [list {u_gpu/alu_stall_count[3][0]} {u_gpu/alu_stall_count[3][1]} {u_gpu/alu_stall_count[3][2]} {u_gpu/alu_stall_count[3][3]} {u_gpu/alu_stall_count[3][4]} {u_gpu/alu_stall_count[3][5]} {u_gpu/alu_stall_count[3][6]} {u_gpu/alu_stall_count[3][7]} {u_gpu/alu_stall_count[3][8]} {u_gpu/alu_stall_count[3][9]} {u_gpu/alu_stall_count[3][10]} {u_gpu/alu_stall_count[3][11]} {u_gpu/alu_stall_count[3][12]} {u_gpu/alu_stall_count[3][13]} {u_gpu/alu_stall_count[3][14]} {u_gpu/alu_stall_count[3][15]} {u_gpu/alu_stall_count[3][16]} {u_gpu/alu_stall_count[3][17]} {u_gpu/alu_stall_count[3][18]} {u_gpu/alu_stall_count[3][19]} {u_gpu/alu_stall_count[3][20]} {u_gpu/alu_stall_count[3][21]} {u_gpu/alu_stall_count[3][22]} {u_gpu/alu_stall_count[3][23]} {u_gpu/alu_stall_count[3][24]} {u_gpu/alu_stall_count[3][25]} {u_gpu/alu_stall_count[3][26]} {u_gpu/alu_stall_count[3][27]} {u_gpu/alu_stall_count[3][28]} {u_gpu/alu_stall_count[3][29]} {u_gpu/alu_stall_count[3][30]} {u_gpu/alu_stall_count[3][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe44]
set_property port_width 32 [get_debug_ports u_ila_0/probe44]
connect_debug_port u_ila_0/probe44 [get_nets [list {u_gpu/alu_stall_count[0][0]} {u_gpu/alu_stall_count[0][1]} {u_gpu/alu_stall_count[0][2]} {u_gpu/alu_stall_count[0][3]} {u_gpu/alu_stall_count[0][4]} {u_gpu/alu_stall_count[0][5]} {u_gpu/alu_stall_count[0][6]} {u_gpu/alu_stall_count[0][7]} {u_gpu/alu_stall_count[0][8]} {u_gpu/alu_stall_count[0][9]} {u_gpu/alu_stall_count[0][10]} {u_gpu/alu_stall_count[0][11]} {u_gpu/alu_stall_count[0][12]} {u_gpu/alu_stall_count[0][13]} {u_gpu/alu_stall_count[0][14]} {u_gpu/alu_stall_count[0][15]} {u_gpu/alu_stall_count[0][16]} {u_gpu/alu_stall_count[0][17]} {u_gpu/alu_stall_count[0][18]} {u_gpu/alu_stall_count[0][19]} {u_gpu/alu_stall_count[0][20]} {u_gpu/alu_stall_count[0][21]} {u_gpu/alu_stall_count[0][22]} {u_gpu/alu_stall_count[0][23]} {u_gpu/alu_stall_count[0][24]} {u_gpu/alu_stall_count[0][25]} {u_gpu/alu_stall_count[0][26]} {u_gpu/alu_stall_count[0][27]} {u_gpu/alu_stall_count[0][28]} {u_gpu/alu_stall_count[0][29]} {u_gpu/alu_stall_count[0][30]} {u_gpu/alu_stall_count[0][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe45]
set_property port_width 32 [get_debug_ports u_ila_0/probe45]
connect_debug_port u_ila_0/probe45 [get_nets [list {u_gpu/free_run_count[3][0]} {u_gpu/free_run_count[3][1]} {u_gpu/free_run_count[3][2]} {u_gpu/free_run_count[3][3]} {u_gpu/free_run_count[3][4]} {u_gpu/free_run_count[3][5]} {u_gpu/free_run_count[3][6]} {u_gpu/free_run_count[3][7]} {u_gpu/free_run_count[3][8]} {u_gpu/free_run_count[3][9]} {u_gpu/free_run_count[3][10]} {u_gpu/free_run_count[3][11]} {u_gpu/free_run_count[3][12]} {u_gpu/free_run_count[3][13]} {u_gpu/free_run_count[3][14]} {u_gpu/free_run_count[3][15]} {u_gpu/free_run_count[3][16]} {u_gpu/free_run_count[3][17]} {u_gpu/free_run_count[3][18]} {u_gpu/free_run_count[3][19]} {u_gpu/free_run_count[3][20]} {u_gpu/free_run_count[3][21]} {u_gpu/free_run_count[3][22]} {u_gpu/free_run_count[3][23]} {u_gpu/free_run_count[3][24]} {u_gpu/free_run_count[3][25]} {u_gpu/free_run_count[3][26]} {u_gpu/free_run_count[3][27]} {u_gpu/free_run_count[3][28]} {u_gpu/free_run_count[3][29]} {u_gpu/free_run_count[3][30]} {u_gpu/free_run_count[3][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe46]
set_property port_width 32 [get_debug_ports u_ila_0/probe46]
connect_debug_port u_ila_0/probe46 [get_nets [list {u_gpu/alu_stall_count[2][0]} {u_gpu/alu_stall_count[2][1]} {u_gpu/alu_stall_count[2][2]} {u_gpu/alu_stall_count[2][3]} {u_gpu/alu_stall_count[2][4]} {u_gpu/alu_stall_count[2][5]} {u_gpu/alu_stall_count[2][6]} {u_gpu/alu_stall_count[2][7]} {u_gpu/alu_stall_count[2][8]} {u_gpu/alu_stall_count[2][9]} {u_gpu/alu_stall_count[2][10]} {u_gpu/alu_stall_count[2][11]} {u_gpu/alu_stall_count[2][12]} {u_gpu/alu_stall_count[2][13]} {u_gpu/alu_stall_count[2][14]} {u_gpu/alu_stall_count[2][15]} {u_gpu/alu_stall_count[2][16]} {u_gpu/alu_stall_count[2][17]} {u_gpu/alu_stall_count[2][18]} {u_gpu/alu_stall_count[2][19]} {u_gpu/alu_stall_count[2][20]} {u_gpu/alu_stall_count[2][21]} {u_gpu/alu_stall_count[2][22]} {u_gpu/alu_stall_count[2][23]} {u_gpu/alu_stall_count[2][24]} {u_gpu/alu_stall_count[2][25]} {u_gpu/alu_stall_count[2][26]} {u_gpu/alu_stall_count[2][27]} {u_gpu/alu_stall_count[2][28]} {u_gpu/alu_stall_count[2][29]} {u_gpu/alu_stall_count[2][30]} {u_gpu/alu_stall_count[2][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe47]
set_property port_width 32 [get_debug_ports u_ila_0/probe47]
connect_debug_port u_ila_0/probe47 [get_nets [list {u_gpu/alu_usage[0]} {u_gpu/alu_usage[1]} {u_gpu/alu_usage[2]} {u_gpu/alu_usage[3]} {u_gpu/alu_usage[4]} {u_gpu/alu_usage[5]} {u_gpu/alu_usage[6]} {u_gpu/alu_usage[7]} {u_gpu/alu_usage[8]} {u_gpu/alu_usage[9]} {u_gpu/alu_usage[10]} {u_gpu/alu_usage[11]} {u_gpu/alu_usage[12]} {u_gpu/alu_usage[13]} {u_gpu/alu_usage[14]} {u_gpu/alu_usage[15]} {u_gpu/alu_usage[16]} {u_gpu/alu_usage[17]} {u_gpu/alu_usage[18]} {u_gpu/alu_usage[19]} {u_gpu/alu_usage[20]} {u_gpu/alu_usage[21]} {u_gpu/alu_usage[22]} {u_gpu/alu_usage[23]} {u_gpu/alu_usage[24]} {u_gpu/alu_usage[25]} {u_gpu/alu_usage[26]} {u_gpu/alu_usage[27]} {u_gpu/alu_usage[28]} {u_gpu/alu_usage[29]} {u_gpu/alu_usage[30]} {u_gpu/alu_usage[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe48]
set_property port_width 32 [get_debug_ports u_ila_0/probe48]
connect_debug_port u_ila_0/probe48 [get_nets [list {u_gpu/scoreboard_stall_count[3][0]} {u_gpu/scoreboard_stall_count[3][1]} {u_gpu/scoreboard_stall_count[3][2]} {u_gpu/scoreboard_stall_count[3][3]} {u_gpu/scoreboard_stall_count[3][4]} {u_gpu/scoreboard_stall_count[3][5]} {u_gpu/scoreboard_stall_count[3][6]} {u_gpu/scoreboard_stall_count[3][7]} {u_gpu/scoreboard_stall_count[3][8]} {u_gpu/scoreboard_stall_count[3][9]} {u_gpu/scoreboard_stall_count[3][10]} {u_gpu/scoreboard_stall_count[3][11]} {u_gpu/scoreboard_stall_count[3][12]} {u_gpu/scoreboard_stall_count[3][13]} {u_gpu/scoreboard_stall_count[3][14]} {u_gpu/scoreboard_stall_count[3][15]} {u_gpu/scoreboard_stall_count[3][16]} {u_gpu/scoreboard_stall_count[3][17]} {u_gpu/scoreboard_stall_count[3][18]} {u_gpu/scoreboard_stall_count[3][19]} {u_gpu/scoreboard_stall_count[3][20]} {u_gpu/scoreboard_stall_count[3][21]} {u_gpu/scoreboard_stall_count[3][22]} {u_gpu/scoreboard_stall_count[3][23]} {u_gpu/scoreboard_stall_count[3][24]} {u_gpu/scoreboard_stall_count[3][25]} {u_gpu/scoreboard_stall_count[3][26]} {u_gpu/scoreboard_stall_count[3][27]} {u_gpu/scoreboard_stall_count[3][28]} {u_gpu/scoreboard_stall_count[3][29]} {u_gpu/scoreboard_stall_count[3][30]} {u_gpu/scoreboard_stall_count[3][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe49]
set_property port_width 32 [get_debug_ports u_ila_0/probe49]
connect_debug_port u_ila_0/probe49 [get_nets [list {u_gpu/mem_stall_count[2][0]} {u_gpu/mem_stall_count[2][1]} {u_gpu/mem_stall_count[2][2]} {u_gpu/mem_stall_count[2][3]} {u_gpu/mem_stall_count[2][4]} {u_gpu/mem_stall_count[2][5]} {u_gpu/mem_stall_count[2][6]} {u_gpu/mem_stall_count[2][7]} {u_gpu/mem_stall_count[2][8]} {u_gpu/mem_stall_count[2][9]} {u_gpu/mem_stall_count[2][10]} {u_gpu/mem_stall_count[2][11]} {u_gpu/mem_stall_count[2][12]} {u_gpu/mem_stall_count[2][13]} {u_gpu/mem_stall_count[2][14]} {u_gpu/mem_stall_count[2][15]} {u_gpu/mem_stall_count[2][16]} {u_gpu/mem_stall_count[2][17]} {u_gpu/mem_stall_count[2][18]} {u_gpu/mem_stall_count[2][19]} {u_gpu/mem_stall_count[2][20]} {u_gpu/mem_stall_count[2][21]} {u_gpu/mem_stall_count[2][22]} {u_gpu/mem_stall_count[2][23]} {u_gpu/mem_stall_count[2][24]} {u_gpu/mem_stall_count[2][25]} {u_gpu/mem_stall_count[2][26]} {u_gpu/mem_stall_count[2][27]} {u_gpu/mem_stall_count[2][28]} {u_gpu/mem_stall_count[2][29]} {u_gpu/mem_stall_count[2][30]} {u_gpu/mem_stall_count[2][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe50]
set_property port_width 32 [get_debug_ports u_ila_0/probe50]
connect_debug_port u_ila_0/probe50 [get_nets [list {u_gpu/mem_stall_count[0][0]} {u_gpu/mem_stall_count[0][1]} {u_gpu/mem_stall_count[0][2]} {u_gpu/mem_stall_count[0][3]} {u_gpu/mem_stall_count[0][4]} {u_gpu/mem_stall_count[0][5]} {u_gpu/mem_stall_count[0][6]} {u_gpu/mem_stall_count[0][7]} {u_gpu/mem_stall_count[0][8]} {u_gpu/mem_stall_count[0][9]} {u_gpu/mem_stall_count[0][10]} {u_gpu/mem_stall_count[0][11]} {u_gpu/mem_stall_count[0][12]} {u_gpu/mem_stall_count[0][13]} {u_gpu/mem_stall_count[0][14]} {u_gpu/mem_stall_count[0][15]} {u_gpu/mem_stall_count[0][16]} {u_gpu/mem_stall_count[0][17]} {u_gpu/mem_stall_count[0][18]} {u_gpu/mem_stall_count[0][19]} {u_gpu/mem_stall_count[0][20]} {u_gpu/mem_stall_count[0][21]} {u_gpu/mem_stall_count[0][22]} {u_gpu/mem_stall_count[0][23]} {u_gpu/mem_stall_count[0][24]} {u_gpu/mem_stall_count[0][25]} {u_gpu/mem_stall_count[0][26]} {u_gpu/mem_stall_count[0][27]} {u_gpu/mem_stall_count[0][28]} {u_gpu/mem_stall_count[0][29]} {u_gpu/mem_stall_count[0][30]} {u_gpu/mem_stall_count[0][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe51]
set_property port_width 32 [get_debug_ports u_ila_0/probe51]
connect_debug_port u_ila_0/probe51 [get_nets [list {u_gpu/mem_stall_count[3][0]} {u_gpu/mem_stall_count[3][1]} {u_gpu/mem_stall_count[3][2]} {u_gpu/mem_stall_count[3][3]} {u_gpu/mem_stall_count[3][4]} {u_gpu/mem_stall_count[3][5]} {u_gpu/mem_stall_count[3][6]} {u_gpu/mem_stall_count[3][7]} {u_gpu/mem_stall_count[3][8]} {u_gpu/mem_stall_count[3][9]} {u_gpu/mem_stall_count[3][10]} {u_gpu/mem_stall_count[3][11]} {u_gpu/mem_stall_count[3][12]} {u_gpu/mem_stall_count[3][13]} {u_gpu/mem_stall_count[3][14]} {u_gpu/mem_stall_count[3][15]} {u_gpu/mem_stall_count[3][16]} {u_gpu/mem_stall_count[3][17]} {u_gpu/mem_stall_count[3][18]} {u_gpu/mem_stall_count[3][19]} {u_gpu/mem_stall_count[3][20]} {u_gpu/mem_stall_count[3][21]} {u_gpu/mem_stall_count[3][22]} {u_gpu/mem_stall_count[3][23]} {u_gpu/mem_stall_count[3][24]} {u_gpu/mem_stall_count[3][25]} {u_gpu/mem_stall_count[3][26]} {u_gpu/mem_stall_count[3][27]} {u_gpu/mem_stall_count[3][28]} {u_gpu/mem_stall_count[3][29]} {u_gpu/mem_stall_count[3][30]} {u_gpu/mem_stall_count[3][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe52]
set_property port_width 32 [get_debug_ports u_ila_0/probe52]
connect_debug_port u_ila_0/probe52 [get_nets [list {u_gpu/scoreboard_stall_count[1][0]} {u_gpu/scoreboard_stall_count[1][1]} {u_gpu/scoreboard_stall_count[1][2]} {u_gpu/scoreboard_stall_count[1][3]} {u_gpu/scoreboard_stall_count[1][4]} {u_gpu/scoreboard_stall_count[1][5]} {u_gpu/scoreboard_stall_count[1][6]} {u_gpu/scoreboard_stall_count[1][7]} {u_gpu/scoreboard_stall_count[1][8]} {u_gpu/scoreboard_stall_count[1][9]} {u_gpu/scoreboard_stall_count[1][10]} {u_gpu/scoreboard_stall_count[1][11]} {u_gpu/scoreboard_stall_count[1][12]} {u_gpu/scoreboard_stall_count[1][13]} {u_gpu/scoreboard_stall_count[1][14]} {u_gpu/scoreboard_stall_count[1][15]} {u_gpu/scoreboard_stall_count[1][16]} {u_gpu/scoreboard_stall_count[1][17]} {u_gpu/scoreboard_stall_count[1][18]} {u_gpu/scoreboard_stall_count[1][19]} {u_gpu/scoreboard_stall_count[1][20]} {u_gpu/scoreboard_stall_count[1][21]} {u_gpu/scoreboard_stall_count[1][22]} {u_gpu/scoreboard_stall_count[1][23]} {u_gpu/scoreboard_stall_count[1][24]} {u_gpu/scoreboard_stall_count[1][25]} {u_gpu/scoreboard_stall_count[1][26]} {u_gpu/scoreboard_stall_count[1][27]} {u_gpu/scoreboard_stall_count[1][28]} {u_gpu/scoreboard_stall_count[1][29]} {u_gpu/scoreboard_stall_count[1][30]} {u_gpu/scoreboard_stall_count[1][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe53]
set_property port_width 32 [get_debug_ports u_ila_0/probe53]
connect_debug_port u_ila_0/probe53 [get_nets [list {u_gpu/program_duration_count[0]} {u_gpu/program_duration_count[1]} {u_gpu/program_duration_count[2]} {u_gpu/program_duration_count[3]} {u_gpu/program_duration_count[4]} {u_gpu/program_duration_count[5]} {u_gpu/program_duration_count[6]} {u_gpu/program_duration_count[7]} {u_gpu/program_duration_count[8]} {u_gpu/program_duration_count[9]} {u_gpu/program_duration_count[10]} {u_gpu/program_duration_count[11]} {u_gpu/program_duration_count[12]} {u_gpu/program_duration_count[13]} {u_gpu/program_duration_count[14]} {u_gpu/program_duration_count[15]} {u_gpu/program_duration_count[16]} {u_gpu/program_duration_count[17]} {u_gpu/program_duration_count[18]} {u_gpu/program_duration_count[19]} {u_gpu/program_duration_count[20]} {u_gpu/program_duration_count[21]} {u_gpu/program_duration_count[22]} {u_gpu/program_duration_count[23]} {u_gpu/program_duration_count[24]} {u_gpu/program_duration_count[25]} {u_gpu/program_duration_count[26]} {u_gpu/program_duration_count[27]} {u_gpu/program_duration_count[28]} {u_gpu/program_duration_count[29]} {u_gpu/program_duration_count[30]} {u_gpu/program_duration_count[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe54]
set_property port_width 32 [get_debug_ports u_ila_0/probe54]
connect_debug_port u_ila_0/probe54 [get_nets [list {u_gpu/scoreboard_stall_count[0][0]} {u_gpu/scoreboard_stall_count[0][1]} {u_gpu/scoreboard_stall_count[0][2]} {u_gpu/scoreboard_stall_count[0][3]} {u_gpu/scoreboard_stall_count[0][4]} {u_gpu/scoreboard_stall_count[0][5]} {u_gpu/scoreboard_stall_count[0][6]} {u_gpu/scoreboard_stall_count[0][7]} {u_gpu/scoreboard_stall_count[0][8]} {u_gpu/scoreboard_stall_count[0][9]} {u_gpu/scoreboard_stall_count[0][10]} {u_gpu/scoreboard_stall_count[0][11]} {u_gpu/scoreboard_stall_count[0][12]} {u_gpu/scoreboard_stall_count[0][13]} {u_gpu/scoreboard_stall_count[0][14]} {u_gpu/scoreboard_stall_count[0][15]} {u_gpu/scoreboard_stall_count[0][16]} {u_gpu/scoreboard_stall_count[0][17]} {u_gpu/scoreboard_stall_count[0][18]} {u_gpu/scoreboard_stall_count[0][19]} {u_gpu/scoreboard_stall_count[0][20]} {u_gpu/scoreboard_stall_count[0][21]} {u_gpu/scoreboard_stall_count[0][22]} {u_gpu/scoreboard_stall_count[0][23]} {u_gpu/scoreboard_stall_count[0][24]} {u_gpu/scoreboard_stall_count[0][25]} {u_gpu/scoreboard_stall_count[0][26]} {u_gpu/scoreboard_stall_count[0][27]} {u_gpu/scoreboard_stall_count[0][28]} {u_gpu/scoreboard_stall_count[0][29]} {u_gpu/scoreboard_stall_count[0][30]} {u_gpu/scoreboard_stall_count[0][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe55]
set_property port_width 4 [get_debug_ports u_ila_0/probe55]
connect_debug_port u_ila_0/probe55 [get_nets [list {u_gpu/mem_request_ack[0]} {u_gpu/mem_request_ack[1]} {u_gpu/mem_request_ack[2]} {u_gpu/mem_request_ack[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe56]
set_property port_width 32 [get_debug_ports u_ila_0/probe56]
connect_debug_port u_ila_0/probe56 [get_nets [list {u_gpu/scoreboard_stall_count[2][0]} {u_gpu/scoreboard_stall_count[2][1]} {u_gpu/scoreboard_stall_count[2][2]} {u_gpu/scoreboard_stall_count[2][3]} {u_gpu/scoreboard_stall_count[2][4]} {u_gpu/scoreboard_stall_count[2][5]} {u_gpu/scoreboard_stall_count[2][6]} {u_gpu/scoreboard_stall_count[2][7]} {u_gpu/scoreboard_stall_count[2][8]} {u_gpu/scoreboard_stall_count[2][9]} {u_gpu/scoreboard_stall_count[2][10]} {u_gpu/scoreboard_stall_count[2][11]} {u_gpu/scoreboard_stall_count[2][12]} {u_gpu/scoreboard_stall_count[2][13]} {u_gpu/scoreboard_stall_count[2][14]} {u_gpu/scoreboard_stall_count[2][15]} {u_gpu/scoreboard_stall_count[2][16]} {u_gpu/scoreboard_stall_count[2][17]} {u_gpu/scoreboard_stall_count[2][18]} {u_gpu/scoreboard_stall_count[2][19]} {u_gpu/scoreboard_stall_count[2][20]} {u_gpu/scoreboard_stall_count[2][21]} {u_gpu/scoreboard_stall_count[2][22]} {u_gpu/scoreboard_stall_count[2][23]} {u_gpu/scoreboard_stall_count[2][24]} {u_gpu/scoreboard_stall_count[2][25]} {u_gpu/scoreboard_stall_count[2][26]} {u_gpu/scoreboard_stall_count[2][27]} {u_gpu/scoreboard_stall_count[2][28]} {u_gpu/scoreboard_stall_count[2][29]} {u_gpu/scoreboard_stall_count[2][30]} {u_gpu/scoreboard_stall_count[2][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe57]
set_property port_width 4 [get_debug_ports u_ila_0/probe57]
connect_debug_port u_ila_0/probe57 [get_nets [list {u_gpu/mem_req_done[0]} {u_gpu/mem_req_done[1]} {u_gpu/mem_req_done[2]} {u_gpu/mem_req_done[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe58]
set_property port_width 32 [get_debug_ports u_ila_0/probe58]
connect_debug_port u_ila_0/probe58 [get_nets [list {u_gpu/mem_stall_count[1][0]} {u_gpu/mem_stall_count[1][1]} {u_gpu/mem_stall_count[1][2]} {u_gpu/mem_stall_count[1][3]} {u_gpu/mem_stall_count[1][4]} {u_gpu/mem_stall_count[1][5]} {u_gpu/mem_stall_count[1][6]} {u_gpu/mem_stall_count[1][7]} {u_gpu/mem_stall_count[1][8]} {u_gpu/mem_stall_count[1][9]} {u_gpu/mem_stall_count[1][10]} {u_gpu/mem_stall_count[1][11]} {u_gpu/mem_stall_count[1][12]} {u_gpu/mem_stall_count[1][13]} {u_gpu/mem_stall_count[1][14]} {u_gpu/mem_stall_count[1][15]} {u_gpu/mem_stall_count[1][16]} {u_gpu/mem_stall_count[1][17]} {u_gpu/mem_stall_count[1][18]} {u_gpu/mem_stall_count[1][19]} {u_gpu/mem_stall_count[1][20]} {u_gpu/mem_stall_count[1][21]} {u_gpu/mem_stall_count[1][22]} {u_gpu/mem_stall_count[1][23]} {u_gpu/mem_stall_count[1][24]} {u_gpu/mem_stall_count[1][25]} {u_gpu/mem_stall_count[1][26]} {u_gpu/mem_stall_count[1][27]} {u_gpu/mem_stall_count[1][28]} {u_gpu/mem_stall_count[1][29]} {u_gpu/mem_stall_count[1][30]} {u_gpu/mem_stall_count[1][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe59]
set_property port_width 11 [get_debug_ports u_ila_0/probe59]
connect_debug_port u_ila_0/probe59 [get_nets [list {u_gpu1/warp_gen[0].warp_inst/pc[0]} {u_gpu1/warp_gen[0].warp_inst/pc[1]} {u_gpu1/warp_gen[0].warp_inst/pc[2]} {u_gpu1/warp_gen[0].warp_inst/pc[3]} {u_gpu1/warp_gen[0].warp_inst/pc[4]} {u_gpu1/warp_gen[0].warp_inst/pc[5]} {u_gpu1/warp_gen[0].warp_inst/pc[6]} {u_gpu1/warp_gen[0].warp_inst/pc[7]} {u_gpu1/warp_gen[0].warp_inst/pc[8]} {u_gpu1/warp_gen[0].warp_inst/pc[9]} {u_gpu1/warp_gen[0].warp_inst/pc[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe60]
set_property port_width 11 [get_debug_ports u_ila_0/probe60]
connect_debug_port u_ila_0/probe60 [get_nets [list {u_gpu1/warp_gen[3].warp_inst/pc[0]} {u_gpu1/warp_gen[3].warp_inst/pc[1]} {u_gpu1/warp_gen[3].warp_inst/pc[2]} {u_gpu1/warp_gen[3].warp_inst/pc[3]} {u_gpu1/warp_gen[3].warp_inst/pc[4]} {u_gpu1/warp_gen[3].warp_inst/pc[5]} {u_gpu1/warp_gen[3].warp_inst/pc[6]} {u_gpu1/warp_gen[3].warp_inst/pc[7]} {u_gpu1/warp_gen[3].warp_inst/pc[8]} {u_gpu1/warp_gen[3].warp_inst/pc[9]} {u_gpu1/warp_gen[3].warp_inst/pc[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe61]
set_property port_width 32 [get_debug_ports u_ila_0/probe61]
connect_debug_port u_ila_0/probe61 [get_nets [list {u_gpu1/alu_stall_count[3][0]} {u_gpu1/alu_stall_count[3][1]} {u_gpu1/alu_stall_count[3][2]} {u_gpu1/alu_stall_count[3][3]} {u_gpu1/alu_stall_count[3][4]} {u_gpu1/alu_stall_count[3][5]} {u_gpu1/alu_stall_count[3][6]} {u_gpu1/alu_stall_count[3][7]} {u_gpu1/alu_stall_count[3][8]} {u_gpu1/alu_stall_count[3][9]} {u_gpu1/alu_stall_count[3][10]} {u_gpu1/alu_stall_count[3][11]} {u_gpu1/alu_stall_count[3][12]} {u_gpu1/alu_stall_count[3][13]} {u_gpu1/alu_stall_count[3][14]} {u_gpu1/alu_stall_count[3][15]} {u_gpu1/alu_stall_count[3][16]} {u_gpu1/alu_stall_count[3][17]} {u_gpu1/alu_stall_count[3][18]} {u_gpu1/alu_stall_count[3][19]} {u_gpu1/alu_stall_count[3][20]} {u_gpu1/alu_stall_count[3][21]} {u_gpu1/alu_stall_count[3][22]} {u_gpu1/alu_stall_count[3][23]} {u_gpu1/alu_stall_count[3][24]} {u_gpu1/alu_stall_count[3][25]} {u_gpu1/alu_stall_count[3][26]} {u_gpu1/alu_stall_count[3][27]} {u_gpu1/alu_stall_count[3][28]} {u_gpu1/alu_stall_count[3][29]} {u_gpu1/alu_stall_count[3][30]} {u_gpu1/alu_stall_count[3][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe62]
set_property port_width 4 [get_debug_ports u_ila_0/probe62]
connect_debug_port u_ila_0/probe62 [get_nets [list {u_gpu1/alu_access[0]} {u_gpu1/alu_access[1]} {u_gpu1/alu_access[2]} {u_gpu1/alu_access[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe63]
set_property port_width 4 [get_debug_ports u_ila_0/probe63]
connect_debug_port u_ila_0/probe63 [get_nets [list {u_gpu1/alu_req[0]} {u_gpu1/alu_req[1]} {u_gpu1/alu_req[2]} {u_gpu1/alu_req[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe64]
set_property port_width 32 [get_debug_ports u_ila_0/probe64]
connect_debug_port u_ila_0/probe64 [get_nets [list {u_gpu1/alu_stall_count[0][0]} {u_gpu1/alu_stall_count[0][1]} {u_gpu1/alu_stall_count[0][2]} {u_gpu1/alu_stall_count[0][3]} {u_gpu1/alu_stall_count[0][4]} {u_gpu1/alu_stall_count[0][5]} {u_gpu1/alu_stall_count[0][6]} {u_gpu1/alu_stall_count[0][7]} {u_gpu1/alu_stall_count[0][8]} {u_gpu1/alu_stall_count[0][9]} {u_gpu1/alu_stall_count[0][10]} {u_gpu1/alu_stall_count[0][11]} {u_gpu1/alu_stall_count[0][12]} {u_gpu1/alu_stall_count[0][13]} {u_gpu1/alu_stall_count[0][14]} {u_gpu1/alu_stall_count[0][15]} {u_gpu1/alu_stall_count[0][16]} {u_gpu1/alu_stall_count[0][17]} {u_gpu1/alu_stall_count[0][18]} {u_gpu1/alu_stall_count[0][19]} {u_gpu1/alu_stall_count[0][20]} {u_gpu1/alu_stall_count[0][21]} {u_gpu1/alu_stall_count[0][22]} {u_gpu1/alu_stall_count[0][23]} {u_gpu1/alu_stall_count[0][24]} {u_gpu1/alu_stall_count[0][25]} {u_gpu1/alu_stall_count[0][26]} {u_gpu1/alu_stall_count[0][27]} {u_gpu1/alu_stall_count[0][28]} {u_gpu1/alu_stall_count[0][29]} {u_gpu1/alu_stall_count[0][30]} {u_gpu1/alu_stall_count[0][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe65]
set_property port_width 4 [get_debug_ports u_ila_0/probe65]
connect_debug_port u_ila_0/probe65 [get_nets [list {u_gpu1/mem_req_done[0]} {u_gpu1/mem_req_done[1]} {u_gpu1/mem_req_done[2]} {u_gpu1/mem_req_done[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe66]
set_property port_width 32 [get_debug_ports u_ila_0/probe66]
connect_debug_port u_ila_0/probe66 [get_nets [list {u_gpu1/alu_stall_count[2][0]} {u_gpu1/alu_stall_count[2][1]} {u_gpu1/alu_stall_count[2][2]} {u_gpu1/alu_stall_count[2][3]} {u_gpu1/alu_stall_count[2][4]} {u_gpu1/alu_stall_count[2][5]} {u_gpu1/alu_stall_count[2][6]} {u_gpu1/alu_stall_count[2][7]} {u_gpu1/alu_stall_count[2][8]} {u_gpu1/alu_stall_count[2][9]} {u_gpu1/alu_stall_count[2][10]} {u_gpu1/alu_stall_count[2][11]} {u_gpu1/alu_stall_count[2][12]} {u_gpu1/alu_stall_count[2][13]} {u_gpu1/alu_stall_count[2][14]} {u_gpu1/alu_stall_count[2][15]} {u_gpu1/alu_stall_count[2][16]} {u_gpu1/alu_stall_count[2][17]} {u_gpu1/alu_stall_count[2][18]} {u_gpu1/alu_stall_count[2][19]} {u_gpu1/alu_stall_count[2][20]} {u_gpu1/alu_stall_count[2][21]} {u_gpu1/alu_stall_count[2][22]} {u_gpu1/alu_stall_count[2][23]} {u_gpu1/alu_stall_count[2][24]} {u_gpu1/alu_stall_count[2][25]} {u_gpu1/alu_stall_count[2][26]} {u_gpu1/alu_stall_count[2][27]} {u_gpu1/alu_stall_count[2][28]} {u_gpu1/alu_stall_count[2][29]} {u_gpu1/alu_stall_count[2][30]} {u_gpu1/alu_stall_count[2][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe67]
set_property port_width 32 [get_debug_ports u_ila_0/probe67]
connect_debug_port u_ila_0/probe67 [get_nets [list {u_gpu1/mem_stall_count[1][0]} {u_gpu1/mem_stall_count[1][1]} {u_gpu1/mem_stall_count[1][2]} {u_gpu1/mem_stall_count[1][3]} {u_gpu1/mem_stall_count[1][4]} {u_gpu1/mem_stall_count[1][5]} {u_gpu1/mem_stall_count[1][6]} {u_gpu1/mem_stall_count[1][7]} {u_gpu1/mem_stall_count[1][8]} {u_gpu1/mem_stall_count[1][9]} {u_gpu1/mem_stall_count[1][10]} {u_gpu1/mem_stall_count[1][11]} {u_gpu1/mem_stall_count[1][12]} {u_gpu1/mem_stall_count[1][13]} {u_gpu1/mem_stall_count[1][14]} {u_gpu1/mem_stall_count[1][15]} {u_gpu1/mem_stall_count[1][16]} {u_gpu1/mem_stall_count[1][17]} {u_gpu1/mem_stall_count[1][18]} {u_gpu1/mem_stall_count[1][19]} {u_gpu1/mem_stall_count[1][20]} {u_gpu1/mem_stall_count[1][21]} {u_gpu1/mem_stall_count[1][22]} {u_gpu1/mem_stall_count[1][23]} {u_gpu1/mem_stall_count[1][24]} {u_gpu1/mem_stall_count[1][25]} {u_gpu1/mem_stall_count[1][26]} {u_gpu1/mem_stall_count[1][27]} {u_gpu1/mem_stall_count[1][28]} {u_gpu1/mem_stall_count[1][29]} {u_gpu1/mem_stall_count[1][30]} {u_gpu1/mem_stall_count[1][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe68]
set_property port_width 32 [get_debug_ports u_ila_0/probe68]
connect_debug_port u_ila_0/probe68 [get_nets [list {u_gpu1/mem_stall_count[2][0]} {u_gpu1/mem_stall_count[2][1]} {u_gpu1/mem_stall_count[2][2]} {u_gpu1/mem_stall_count[2][3]} {u_gpu1/mem_stall_count[2][4]} {u_gpu1/mem_stall_count[2][5]} {u_gpu1/mem_stall_count[2][6]} {u_gpu1/mem_stall_count[2][7]} {u_gpu1/mem_stall_count[2][8]} {u_gpu1/mem_stall_count[2][9]} {u_gpu1/mem_stall_count[2][10]} {u_gpu1/mem_stall_count[2][11]} {u_gpu1/mem_stall_count[2][12]} {u_gpu1/mem_stall_count[2][13]} {u_gpu1/mem_stall_count[2][14]} {u_gpu1/mem_stall_count[2][15]} {u_gpu1/mem_stall_count[2][16]} {u_gpu1/mem_stall_count[2][17]} {u_gpu1/mem_stall_count[2][18]} {u_gpu1/mem_stall_count[2][19]} {u_gpu1/mem_stall_count[2][20]} {u_gpu1/mem_stall_count[2][21]} {u_gpu1/mem_stall_count[2][22]} {u_gpu1/mem_stall_count[2][23]} {u_gpu1/mem_stall_count[2][24]} {u_gpu1/mem_stall_count[2][25]} {u_gpu1/mem_stall_count[2][26]} {u_gpu1/mem_stall_count[2][27]} {u_gpu1/mem_stall_count[2][28]} {u_gpu1/mem_stall_count[2][29]} {u_gpu1/mem_stall_count[2][30]} {u_gpu1/mem_stall_count[2][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe69]
set_property port_width 32 [get_debug_ports u_ila_0/probe69]
connect_debug_port u_ila_0/probe69 [get_nets [list {u_gpu1/mem_stall_count[3][0]} {u_gpu1/mem_stall_count[3][1]} {u_gpu1/mem_stall_count[3][2]} {u_gpu1/mem_stall_count[3][3]} {u_gpu1/mem_stall_count[3][4]} {u_gpu1/mem_stall_count[3][5]} {u_gpu1/mem_stall_count[3][6]} {u_gpu1/mem_stall_count[3][7]} {u_gpu1/mem_stall_count[3][8]} {u_gpu1/mem_stall_count[3][9]} {u_gpu1/mem_stall_count[3][10]} {u_gpu1/mem_stall_count[3][11]} {u_gpu1/mem_stall_count[3][12]} {u_gpu1/mem_stall_count[3][13]} {u_gpu1/mem_stall_count[3][14]} {u_gpu1/mem_stall_count[3][15]} {u_gpu1/mem_stall_count[3][16]} {u_gpu1/mem_stall_count[3][17]} {u_gpu1/mem_stall_count[3][18]} {u_gpu1/mem_stall_count[3][19]} {u_gpu1/mem_stall_count[3][20]} {u_gpu1/mem_stall_count[3][21]} {u_gpu1/mem_stall_count[3][22]} {u_gpu1/mem_stall_count[3][23]} {u_gpu1/mem_stall_count[3][24]} {u_gpu1/mem_stall_count[3][25]} {u_gpu1/mem_stall_count[3][26]} {u_gpu1/mem_stall_count[3][27]} {u_gpu1/mem_stall_count[3][28]} {u_gpu1/mem_stall_count[3][29]} {u_gpu1/mem_stall_count[3][30]} {u_gpu1/mem_stall_count[3][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe70]
set_property port_width 32 [get_debug_ports u_ila_0/probe70]
connect_debug_port u_ila_0/probe70 [get_nets [list {u_gpu1/mem_stall_count[0][0]} {u_gpu1/mem_stall_count[0][1]} {u_gpu1/mem_stall_count[0][2]} {u_gpu1/mem_stall_count[0][3]} {u_gpu1/mem_stall_count[0][4]} {u_gpu1/mem_stall_count[0][5]} {u_gpu1/mem_stall_count[0][6]} {u_gpu1/mem_stall_count[0][7]} {u_gpu1/mem_stall_count[0][8]} {u_gpu1/mem_stall_count[0][9]} {u_gpu1/mem_stall_count[0][10]} {u_gpu1/mem_stall_count[0][11]} {u_gpu1/mem_stall_count[0][12]} {u_gpu1/mem_stall_count[0][13]} {u_gpu1/mem_stall_count[0][14]} {u_gpu1/mem_stall_count[0][15]} {u_gpu1/mem_stall_count[0][16]} {u_gpu1/mem_stall_count[0][17]} {u_gpu1/mem_stall_count[0][18]} {u_gpu1/mem_stall_count[0][19]} {u_gpu1/mem_stall_count[0][20]} {u_gpu1/mem_stall_count[0][21]} {u_gpu1/mem_stall_count[0][22]} {u_gpu1/mem_stall_count[0][23]} {u_gpu1/mem_stall_count[0][24]} {u_gpu1/mem_stall_count[0][25]} {u_gpu1/mem_stall_count[0][26]} {u_gpu1/mem_stall_count[0][27]} {u_gpu1/mem_stall_count[0][28]} {u_gpu1/mem_stall_count[0][29]} {u_gpu1/mem_stall_count[0][30]} {u_gpu1/mem_stall_count[0][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe71]
set_property port_width 32 [get_debug_ports u_ila_0/probe71]
connect_debug_port u_ila_0/probe71 [get_nets [list {u_gpu1/alu_usage[0]} {u_gpu1/alu_usage[1]} {u_gpu1/alu_usage[2]} {u_gpu1/alu_usage[3]} {u_gpu1/alu_usage[4]} {u_gpu1/alu_usage[5]} {u_gpu1/alu_usage[6]} {u_gpu1/alu_usage[7]} {u_gpu1/alu_usage[8]} {u_gpu1/alu_usage[9]} {u_gpu1/alu_usage[10]} {u_gpu1/alu_usage[11]} {u_gpu1/alu_usage[12]} {u_gpu1/alu_usage[13]} {u_gpu1/alu_usage[14]} {u_gpu1/alu_usage[15]} {u_gpu1/alu_usage[16]} {u_gpu1/alu_usage[17]} {u_gpu1/alu_usage[18]} {u_gpu1/alu_usage[19]} {u_gpu1/alu_usage[20]} {u_gpu1/alu_usage[21]} {u_gpu1/alu_usage[22]} {u_gpu1/alu_usage[23]} {u_gpu1/alu_usage[24]} {u_gpu1/alu_usage[25]} {u_gpu1/alu_usage[26]} {u_gpu1/alu_usage[27]} {u_gpu1/alu_usage[28]} {u_gpu1/alu_usage[29]} {u_gpu1/alu_usage[30]} {u_gpu1/alu_usage[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe72]
set_property port_width 32 [get_debug_ports u_ila_0/probe72]
connect_debug_port u_ila_0/probe72 [get_nets [list {u_gpu1/free_run_count[3][0]} {u_gpu1/free_run_count[3][1]} {u_gpu1/free_run_count[3][2]} {u_gpu1/free_run_count[3][3]} {u_gpu1/free_run_count[3][4]} {u_gpu1/free_run_count[3][5]} {u_gpu1/free_run_count[3][6]} {u_gpu1/free_run_count[3][7]} {u_gpu1/free_run_count[3][8]} {u_gpu1/free_run_count[3][9]} {u_gpu1/free_run_count[3][10]} {u_gpu1/free_run_count[3][11]} {u_gpu1/free_run_count[3][12]} {u_gpu1/free_run_count[3][13]} {u_gpu1/free_run_count[3][14]} {u_gpu1/free_run_count[3][15]} {u_gpu1/free_run_count[3][16]} {u_gpu1/free_run_count[3][17]} {u_gpu1/free_run_count[3][18]} {u_gpu1/free_run_count[3][19]} {u_gpu1/free_run_count[3][20]} {u_gpu1/free_run_count[3][21]} {u_gpu1/free_run_count[3][22]} {u_gpu1/free_run_count[3][23]} {u_gpu1/free_run_count[3][24]} {u_gpu1/free_run_count[3][25]} {u_gpu1/free_run_count[3][26]} {u_gpu1/free_run_count[3][27]} {u_gpu1/free_run_count[3][28]} {u_gpu1/free_run_count[3][29]} {u_gpu1/free_run_count[3][30]} {u_gpu1/free_run_count[3][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe73]
set_property port_width 4 [get_debug_ports u_ila_0/probe73]
connect_debug_port u_ila_0/probe73 [get_nets [list {u_gpu1/mem_request_ack[0]} {u_gpu1/mem_request_ack[1]} {u_gpu1/mem_request_ack[2]} {u_gpu1/mem_request_ack[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe74]
set_property port_width 32 [get_debug_ports u_ila_0/probe74]
connect_debug_port u_ila_0/probe74 [get_nets [list {u_gpu1/free_run_count[0][0]} {u_gpu1/free_run_count[0][1]} {u_gpu1/free_run_count[0][2]} {u_gpu1/free_run_count[0][3]} {u_gpu1/free_run_count[0][4]} {u_gpu1/free_run_count[0][5]} {u_gpu1/free_run_count[0][6]} {u_gpu1/free_run_count[0][7]} {u_gpu1/free_run_count[0][8]} {u_gpu1/free_run_count[0][9]} {u_gpu1/free_run_count[0][10]} {u_gpu1/free_run_count[0][11]} {u_gpu1/free_run_count[0][12]} {u_gpu1/free_run_count[0][13]} {u_gpu1/free_run_count[0][14]} {u_gpu1/free_run_count[0][15]} {u_gpu1/free_run_count[0][16]} {u_gpu1/free_run_count[0][17]} {u_gpu1/free_run_count[0][18]} {u_gpu1/free_run_count[0][19]} {u_gpu1/free_run_count[0][20]} {u_gpu1/free_run_count[0][21]} {u_gpu1/free_run_count[0][22]} {u_gpu1/free_run_count[0][23]} {u_gpu1/free_run_count[0][24]} {u_gpu1/free_run_count[0][25]} {u_gpu1/free_run_count[0][26]} {u_gpu1/free_run_count[0][27]} {u_gpu1/free_run_count[0][28]} {u_gpu1/free_run_count[0][29]} {u_gpu1/free_run_count[0][30]} {u_gpu1/free_run_count[0][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe75]
set_property port_width 32 [get_debug_ports u_ila_0/probe75]
connect_debug_port u_ila_0/probe75 [get_nets [list {u_gpu1/free_run_count[2][0]} {u_gpu1/free_run_count[2][1]} {u_gpu1/free_run_count[2][2]} {u_gpu1/free_run_count[2][3]} {u_gpu1/free_run_count[2][4]} {u_gpu1/free_run_count[2][5]} {u_gpu1/free_run_count[2][6]} {u_gpu1/free_run_count[2][7]} {u_gpu1/free_run_count[2][8]} {u_gpu1/free_run_count[2][9]} {u_gpu1/free_run_count[2][10]} {u_gpu1/free_run_count[2][11]} {u_gpu1/free_run_count[2][12]} {u_gpu1/free_run_count[2][13]} {u_gpu1/free_run_count[2][14]} {u_gpu1/free_run_count[2][15]} {u_gpu1/free_run_count[2][16]} {u_gpu1/free_run_count[2][17]} {u_gpu1/free_run_count[2][18]} {u_gpu1/free_run_count[2][19]} {u_gpu1/free_run_count[2][20]} {u_gpu1/free_run_count[2][21]} {u_gpu1/free_run_count[2][22]} {u_gpu1/free_run_count[2][23]} {u_gpu1/free_run_count[2][24]} {u_gpu1/free_run_count[2][25]} {u_gpu1/free_run_count[2][26]} {u_gpu1/free_run_count[2][27]} {u_gpu1/free_run_count[2][28]} {u_gpu1/free_run_count[2][29]} {u_gpu1/free_run_count[2][30]} {u_gpu1/free_run_count[2][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe76]
set_property port_width 32 [get_debug_ports u_ila_0/probe76]
connect_debug_port u_ila_0/probe76 [get_nets [list {u_gpu1/alu_stall_count[1][0]} {u_gpu1/alu_stall_count[1][1]} {u_gpu1/alu_stall_count[1][2]} {u_gpu1/alu_stall_count[1][3]} {u_gpu1/alu_stall_count[1][4]} {u_gpu1/alu_stall_count[1][5]} {u_gpu1/alu_stall_count[1][6]} {u_gpu1/alu_stall_count[1][7]} {u_gpu1/alu_stall_count[1][8]} {u_gpu1/alu_stall_count[1][9]} {u_gpu1/alu_stall_count[1][10]} {u_gpu1/alu_stall_count[1][11]} {u_gpu1/alu_stall_count[1][12]} {u_gpu1/alu_stall_count[1][13]} {u_gpu1/alu_stall_count[1][14]} {u_gpu1/alu_stall_count[1][15]} {u_gpu1/alu_stall_count[1][16]} {u_gpu1/alu_stall_count[1][17]} {u_gpu1/alu_stall_count[1][18]} {u_gpu1/alu_stall_count[1][19]} {u_gpu1/alu_stall_count[1][20]} {u_gpu1/alu_stall_count[1][21]} {u_gpu1/alu_stall_count[1][22]} {u_gpu1/alu_stall_count[1][23]} {u_gpu1/alu_stall_count[1][24]} {u_gpu1/alu_stall_count[1][25]} {u_gpu1/alu_stall_count[1][26]} {u_gpu1/alu_stall_count[1][27]} {u_gpu1/alu_stall_count[1][28]} {u_gpu1/alu_stall_count[1][29]} {u_gpu1/alu_stall_count[1][30]} {u_gpu1/alu_stall_count[1][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe77]
set_property port_width 32 [get_debug_ports u_ila_0/probe77]
connect_debug_port u_ila_0/probe77 [get_nets [list {u_gpu1/free_run_count[1][0]} {u_gpu1/free_run_count[1][1]} {u_gpu1/free_run_count[1][2]} {u_gpu1/free_run_count[1][3]} {u_gpu1/free_run_count[1][4]} {u_gpu1/free_run_count[1][5]} {u_gpu1/free_run_count[1][6]} {u_gpu1/free_run_count[1][7]} {u_gpu1/free_run_count[1][8]} {u_gpu1/free_run_count[1][9]} {u_gpu1/free_run_count[1][10]} {u_gpu1/free_run_count[1][11]} {u_gpu1/free_run_count[1][12]} {u_gpu1/free_run_count[1][13]} {u_gpu1/free_run_count[1][14]} {u_gpu1/free_run_count[1][15]} {u_gpu1/free_run_count[1][16]} {u_gpu1/free_run_count[1][17]} {u_gpu1/free_run_count[1][18]} {u_gpu1/free_run_count[1][19]} {u_gpu1/free_run_count[1][20]} {u_gpu1/free_run_count[1][21]} {u_gpu1/free_run_count[1][22]} {u_gpu1/free_run_count[1][23]} {u_gpu1/free_run_count[1][24]} {u_gpu1/free_run_count[1][25]} {u_gpu1/free_run_count[1][26]} {u_gpu1/free_run_count[1][27]} {u_gpu1/free_run_count[1][28]} {u_gpu1/free_run_count[1][29]} {u_gpu1/free_run_count[1][30]} {u_gpu1/free_run_count[1][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe78]
set_property port_width 32 [get_debug_ports u_ila_0/probe78]
connect_debug_port u_ila_0/probe78 [get_nets [list {u_gpu1/scoreboard_stall_count[1][0]} {u_gpu1/scoreboard_stall_count[1][1]} {u_gpu1/scoreboard_stall_count[1][2]} {u_gpu1/scoreboard_stall_count[1][3]} {u_gpu1/scoreboard_stall_count[1][4]} {u_gpu1/scoreboard_stall_count[1][5]} {u_gpu1/scoreboard_stall_count[1][6]} {u_gpu1/scoreboard_stall_count[1][7]} {u_gpu1/scoreboard_stall_count[1][8]} {u_gpu1/scoreboard_stall_count[1][9]} {u_gpu1/scoreboard_stall_count[1][10]} {u_gpu1/scoreboard_stall_count[1][11]} {u_gpu1/scoreboard_stall_count[1][12]} {u_gpu1/scoreboard_stall_count[1][13]} {u_gpu1/scoreboard_stall_count[1][14]} {u_gpu1/scoreboard_stall_count[1][15]} {u_gpu1/scoreboard_stall_count[1][16]} {u_gpu1/scoreboard_stall_count[1][17]} {u_gpu1/scoreboard_stall_count[1][18]} {u_gpu1/scoreboard_stall_count[1][19]} {u_gpu1/scoreboard_stall_count[1][20]} {u_gpu1/scoreboard_stall_count[1][21]} {u_gpu1/scoreboard_stall_count[1][22]} {u_gpu1/scoreboard_stall_count[1][23]} {u_gpu1/scoreboard_stall_count[1][24]} {u_gpu1/scoreboard_stall_count[1][25]} {u_gpu1/scoreboard_stall_count[1][26]} {u_gpu1/scoreboard_stall_count[1][27]} {u_gpu1/scoreboard_stall_count[1][28]} {u_gpu1/scoreboard_stall_count[1][29]} {u_gpu1/scoreboard_stall_count[1][30]} {u_gpu1/scoreboard_stall_count[1][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe79]
set_property port_width 32 [get_debug_ports u_ila_0/probe79]
connect_debug_port u_ila_0/probe79 [get_nets [list {u_gpu1/scoreboard_stall_count[0][0]} {u_gpu1/scoreboard_stall_count[0][1]} {u_gpu1/scoreboard_stall_count[0][2]} {u_gpu1/scoreboard_stall_count[0][3]} {u_gpu1/scoreboard_stall_count[0][4]} {u_gpu1/scoreboard_stall_count[0][5]} {u_gpu1/scoreboard_stall_count[0][6]} {u_gpu1/scoreboard_stall_count[0][7]} {u_gpu1/scoreboard_stall_count[0][8]} {u_gpu1/scoreboard_stall_count[0][9]} {u_gpu1/scoreboard_stall_count[0][10]} {u_gpu1/scoreboard_stall_count[0][11]} {u_gpu1/scoreboard_stall_count[0][12]} {u_gpu1/scoreboard_stall_count[0][13]} {u_gpu1/scoreboard_stall_count[0][14]} {u_gpu1/scoreboard_stall_count[0][15]} {u_gpu1/scoreboard_stall_count[0][16]} {u_gpu1/scoreboard_stall_count[0][17]} {u_gpu1/scoreboard_stall_count[0][18]} {u_gpu1/scoreboard_stall_count[0][19]} {u_gpu1/scoreboard_stall_count[0][20]} {u_gpu1/scoreboard_stall_count[0][21]} {u_gpu1/scoreboard_stall_count[0][22]} {u_gpu1/scoreboard_stall_count[0][23]} {u_gpu1/scoreboard_stall_count[0][24]} {u_gpu1/scoreboard_stall_count[0][25]} {u_gpu1/scoreboard_stall_count[0][26]} {u_gpu1/scoreboard_stall_count[0][27]} {u_gpu1/scoreboard_stall_count[0][28]} {u_gpu1/scoreboard_stall_count[0][29]} {u_gpu1/scoreboard_stall_count[0][30]} {u_gpu1/scoreboard_stall_count[0][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe80]
set_property port_width 32 [get_debug_ports u_ila_0/probe80]
connect_debug_port u_ila_0/probe80 [get_nets [list {u_gpu1/scoreboard_stall_count[2][0]} {u_gpu1/scoreboard_stall_count[2][1]} {u_gpu1/scoreboard_stall_count[2][2]} {u_gpu1/scoreboard_stall_count[2][3]} {u_gpu1/scoreboard_stall_count[2][4]} {u_gpu1/scoreboard_stall_count[2][5]} {u_gpu1/scoreboard_stall_count[2][6]} {u_gpu1/scoreboard_stall_count[2][7]} {u_gpu1/scoreboard_stall_count[2][8]} {u_gpu1/scoreboard_stall_count[2][9]} {u_gpu1/scoreboard_stall_count[2][10]} {u_gpu1/scoreboard_stall_count[2][11]} {u_gpu1/scoreboard_stall_count[2][12]} {u_gpu1/scoreboard_stall_count[2][13]} {u_gpu1/scoreboard_stall_count[2][14]} {u_gpu1/scoreboard_stall_count[2][15]} {u_gpu1/scoreboard_stall_count[2][16]} {u_gpu1/scoreboard_stall_count[2][17]} {u_gpu1/scoreboard_stall_count[2][18]} {u_gpu1/scoreboard_stall_count[2][19]} {u_gpu1/scoreboard_stall_count[2][20]} {u_gpu1/scoreboard_stall_count[2][21]} {u_gpu1/scoreboard_stall_count[2][22]} {u_gpu1/scoreboard_stall_count[2][23]} {u_gpu1/scoreboard_stall_count[2][24]} {u_gpu1/scoreboard_stall_count[2][25]} {u_gpu1/scoreboard_stall_count[2][26]} {u_gpu1/scoreboard_stall_count[2][27]} {u_gpu1/scoreboard_stall_count[2][28]} {u_gpu1/scoreboard_stall_count[2][29]} {u_gpu1/scoreboard_stall_count[2][30]} {u_gpu1/scoreboard_stall_count[2][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe81]
set_property port_width 32 [get_debug_ports u_ila_0/probe81]
connect_debug_port u_ila_0/probe81 [get_nets [list {u_gpu1/scoreboard_stall_count[3][0]} {u_gpu1/scoreboard_stall_count[3][1]} {u_gpu1/scoreboard_stall_count[3][2]} {u_gpu1/scoreboard_stall_count[3][3]} {u_gpu1/scoreboard_stall_count[3][4]} {u_gpu1/scoreboard_stall_count[3][5]} {u_gpu1/scoreboard_stall_count[3][6]} {u_gpu1/scoreboard_stall_count[3][7]} {u_gpu1/scoreboard_stall_count[3][8]} {u_gpu1/scoreboard_stall_count[3][9]} {u_gpu1/scoreboard_stall_count[3][10]} {u_gpu1/scoreboard_stall_count[3][11]} {u_gpu1/scoreboard_stall_count[3][12]} {u_gpu1/scoreboard_stall_count[3][13]} {u_gpu1/scoreboard_stall_count[3][14]} {u_gpu1/scoreboard_stall_count[3][15]} {u_gpu1/scoreboard_stall_count[3][16]} {u_gpu1/scoreboard_stall_count[3][17]} {u_gpu1/scoreboard_stall_count[3][18]} {u_gpu1/scoreboard_stall_count[3][19]} {u_gpu1/scoreboard_stall_count[3][20]} {u_gpu1/scoreboard_stall_count[3][21]} {u_gpu1/scoreboard_stall_count[3][22]} {u_gpu1/scoreboard_stall_count[3][23]} {u_gpu1/scoreboard_stall_count[3][24]} {u_gpu1/scoreboard_stall_count[3][25]} {u_gpu1/scoreboard_stall_count[3][26]} {u_gpu1/scoreboard_stall_count[3][27]} {u_gpu1/scoreboard_stall_count[3][28]} {u_gpu1/scoreboard_stall_count[3][29]} {u_gpu1/scoreboard_stall_count[3][30]} {u_gpu1/scoreboard_stall_count[3][31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe82]
set_property port_width 32 [get_debug_ports u_ila_0/probe82]
connect_debug_port u_ila_0/probe82 [get_nets [list {from_init_duration_count[0]} {from_init_duration_count[1]} {from_init_duration_count[2]} {from_init_duration_count[3]} {from_init_duration_count[4]} {from_init_duration_count[5]} {from_init_duration_count[6]} {from_init_duration_count[7]} {from_init_duration_count[8]} {from_init_duration_count[9]} {from_init_duration_count[10]} {from_init_duration_count[11]} {from_init_duration_count[12]} {from_init_duration_count[13]} {from_init_duration_count[14]} {from_init_duration_count[15]} {from_init_duration_count[16]} {from_init_duration_count[17]} {from_init_duration_count[18]} {from_init_duration_count[19]} {from_init_duration_count[20]} {from_init_duration_count[21]} {from_init_duration_count[22]} {from_init_duration_count[23]} {from_init_duration_count[24]} {from_init_duration_count[25]} {from_init_duration_count[26]} {from_init_duration_count[27]} {from_init_duration_count[28]} {from_init_duration_count[29]} {from_init_duration_count[30]} {from_init_duration_count[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe83]
set_property port_width 32 [get_debug_ports u_ila_0/probe83]
connect_debug_port u_ila_0/probe83 [get_nets [list {program_duration_count[0]} {program_duration_count[1]} {program_duration_count[2]} {program_duration_count[3]} {program_duration_count[4]} {program_duration_count[5]} {program_duration_count[6]} {program_duration_count[7]} {program_duration_count[8]} {program_duration_count[9]} {program_duration_count[10]} {program_duration_count[11]} {program_duration_count[12]} {program_duration_count[13]} {program_duration_count[14]} {program_duration_count[15]} {program_duration_count[16]} {program_duration_count[17]} {program_duration_count[18]} {program_duration_count[19]} {program_duration_count[20]} {program_duration_count[21]} {program_duration_count[22]} {program_duration_count[23]} {program_duration_count[24]} {program_duration_count[25]} {program_duration_count[26]} {program_duration_count[27]} {program_duration_count[28]} {program_duration_count[29]} {program_duration_count[30]} {program_duration_count[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe84]
set_property port_width 1 [get_debug_ports u_ila_0/probe84]
connect_debug_port u_ila_0/probe84 [get_nets [list clock_reset_from_mb]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe85]
set_property port_width 1 [get_debug_ports u_ila_0/probe85]
connect_debug_port u_ila_0/probe85 [get_nets [list dmem1_addr_space]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe86]
set_property port_width 1 [get_debug_ports u_ila_0/probe86]
connect_debug_port u_ila_0/probe86 [get_nets [list dmem2_addr_space]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe87]
set_property port_width 1 [get_debug_ports u_ila_0/probe87]
connect_debug_port u_ila_0/probe87 [get_nets [list dmem_addr_space]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe88]
set_property port_width 1 [get_debug_ports u_ila_0/probe88]
connect_debug_port u_ila_0/probe88 [get_nets [list gpu1_reset_from_mb]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe89]
set_property port_width 1 [get_debug_ports u_ila_0/probe89]
connect_debug_port u_ila_0/probe89 [get_nets [list gpu2_reset_from_mb]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe90]
set_property port_width 1 [get_debug_ports u_ila_0/probe90]
connect_debug_port u_ila_0/probe90 [get_nets [list u_gpu1/GPU_done]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe91]
set_property port_width 1 [get_debug_ports u_ila_0/probe91]
connect_debug_port u_ila_0/probe91 [get_nets [list gpu_done]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe92]
set_property port_width 1 [get_debug_ports u_ila_0/probe92]
connect_debug_port u_ila_0/probe92 [get_nets [list u_gpu2/GPU_done]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe93]
set_property port_width 1 [get_debug_ports u_ila_0/probe93]
connect_debug_port u_ila_0/probe93 [get_nets [list u_gpu/GPU_done]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe94]
set_property port_width 1 [get_debug_ports u_ila_0/probe94]
connect_debug_port u_ila_0/probe94 [get_nets [list gpu_reset_from_mb]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe95]
set_property port_width 1 [get_debug_ports u_ila_0/probe95]
connect_debug_port u_ila_0/probe95 [get_nets [list imem1_addr_space]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe96]
set_property port_width 1 [get_debug_ports u_ila_0/probe96]
connect_debug_port u_ila_0/probe96 [get_nets [list imem2_addr_space]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe97]
set_property port_width 1 [get_debug_ports u_ila_0/probe97]
connect_debug_port u_ila_0/probe97 [get_nets [list imem_addr_space]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe98]
set_property port_width 1 [get_debug_ports u_ila_0/probe98]
connect_debug_port u_ila_0/probe98 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[0]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe99]
set_property port_width 1 [get_debug_ports u_ila_0/probe99]
connect_debug_port u_ila_0/probe99 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[0]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe100]
set_property port_width 1 [get_debug_ports u_ila_0/probe100]
connect_debug_port u_ila_0/probe100 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe101]
set_property port_width 1 [get_debug_ports u_ila_0/probe101]
connect_debug_port u_ila_0/probe101 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe102]
set_property port_width 1 [get_debug_ports u_ila_0/probe102]
connect_debug_port u_ila_0/probe102 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe103]
set_property port_width 1 [get_debug_ports u_ila_0/probe103]
connect_debug_port u_ila_0/probe103 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe104]
set_property port_width 1 [get_debug_ports u_ila_0/probe104]
connect_debug_port u_ila_0/probe104 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe105]
set_property port_width 1 [get_debug_ports u_ila_0/probe105]
connect_debug_port u_ila_0/probe105 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe106]
set_property port_width 1 [get_debug_ports u_ila_0/probe106]
connect_debug_port u_ila_0/probe106 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe107]
set_property port_width 1 [get_debug_ports u_ila_0/probe107]
connect_debug_port u_ila_0/probe107 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe108]
set_property port_width 1 [get_debug_ports u_ila_0/probe108]
connect_debug_port u_ila_0/probe108 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe109]
set_property port_width 1 [get_debug_ports u_ila_0/probe109]
connect_debug_port u_ila_0/probe109 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe110]
set_property port_width 1 [get_debug_ports u_ila_0/probe110]
connect_debug_port u_ila_0/probe110 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[6]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe111]
set_property port_width 1 [get_debug_ports u_ila_0/probe111]
connect_debug_port u_ila_0/probe111 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[6]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe112]
set_property port_width 1 [get_debug_ports u_ila_0/probe112]
connect_debug_port u_ila_0/probe112 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe113]
set_property port_width 1 [get_debug_ports u_ila_0/probe113]
connect_debug_port u_ila_0/probe113 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe114]
set_property port_width 1 [get_debug_ports u_ila_0/probe114]
connect_debug_port u_ila_0/probe114 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[8]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe115]
set_property port_width 1 [get_debug_ports u_ila_0/probe115]
connect_debug_port u_ila_0/probe115 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[8]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe116]
set_property port_width 1 [get_debug_ports u_ila_0/probe116]
connect_debug_port u_ila_0/probe116 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe117]
set_property port_width 1 [get_debug_ports u_ila_0/probe117]
connect_debug_port u_ila_0/probe117 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe118]
set_property port_width 1 [get_debug_ports u_ila_0/probe118]
connect_debug_port u_ila_0/probe118 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe119]
set_property port_width 1 [get_debug_ports u_ila_0/probe119]
connect_debug_port u_ila_0/probe119 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe120]
set_property port_width 1 [get_debug_ports u_ila_0/probe120]
connect_debug_port u_ila_0/probe120 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe121]
set_property port_width 1 [get_debug_ports u_ila_0/probe121]
connect_debug_port u_ila_0/probe121 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe122]
set_property port_width 1 [get_debug_ports u_ila_0/probe122]
connect_debug_port u_ila_0/probe122 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[12]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe123]
set_property port_width 1 [get_debug_ports u_ila_0/probe123]
connect_debug_port u_ila_0/probe123 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[12]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe124]
set_property port_width 1 [get_debug_ports u_ila_0/probe124]
connect_debug_port u_ila_0/probe124 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[13]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe125]
set_property port_width 1 [get_debug_ports u_ila_0/probe125]
connect_debug_port u_ila_0/probe125 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[13]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe126]
set_property port_width 1 [get_debug_ports u_ila_0/probe126]
connect_debug_port u_ila_0/probe126 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe127]
set_property port_width 1 [get_debug_ports u_ila_0/probe127]
connect_debug_port u_ila_0/probe127 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[14]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe128]
set_property port_width 1 [get_debug_ports u_ila_0/probe128]
connect_debug_port u_ila_0/probe128 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe129]
set_property port_width 1 [get_debug_ports u_ila_0/probe129]
connect_debug_port u_ila_0/probe129 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe130]
set_property port_width 1 [get_debug_ports u_ila_0/probe130]
connect_debug_port u_ila_0/probe130 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[16]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe131]
set_property port_width 1 [get_debug_ports u_ila_0/probe131]
connect_debug_port u_ila_0/probe131 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[16]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe132]
set_property port_width 1 [get_debug_ports u_ila_0/probe132]
connect_debug_port u_ila_0/probe132 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[17]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe133]
set_property port_width 1 [get_debug_ports u_ila_0/probe133]
connect_debug_port u_ila_0/probe133 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[17]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe134]
set_property port_width 1 [get_debug_ports u_ila_0/probe134]
connect_debug_port u_ila_0/probe134 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[18]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe135]
set_property port_width 1 [get_debug_ports u_ila_0/probe135]
connect_debug_port u_ila_0/probe135 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[18]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe136]
set_property port_width 1 [get_debug_ports u_ila_0/probe136]
connect_debug_port u_ila_0/probe136 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe137]
set_property port_width 1 [get_debug_ports u_ila_0/probe137]
connect_debug_port u_ila_0/probe137 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe138]
set_property port_width 1 [get_debug_ports u_ila_0/probe138]
connect_debug_port u_ila_0/probe138 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[20]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe139]
set_property port_width 1 [get_debug_ports u_ila_0/probe139]
connect_debug_port u_ila_0/probe139 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[20]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe140]
set_property port_width 1 [get_debug_ports u_ila_0/probe140]
connect_debug_port u_ila_0/probe140 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[21]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe141]
set_property port_width 1 [get_debug_ports u_ila_0/probe141]
connect_debug_port u_ila_0/probe141 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[21]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe142]
set_property port_width 1 [get_debug_ports u_ila_0/probe142]
connect_debug_port u_ila_0/probe142 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[22]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe143]
set_property port_width 1 [get_debug_ports u_ila_0/probe143]
connect_debug_port u_ila_0/probe143 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[22]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe144]
set_property port_width 1 [get_debug_ports u_ila_0/probe144]
connect_debug_port u_ila_0/probe144 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe145]
set_property port_width 1 [get_debug_ports u_ila_0/probe145]
connect_debug_port u_ila_0/probe145 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe146]
set_property port_width 1 [get_debug_ports u_ila_0/probe146]
connect_debug_port u_ila_0/probe146 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[24]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe147]
set_property port_width 1 [get_debug_ports u_ila_0/probe147]
connect_debug_port u_ila_0/probe147 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[24]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe148]
set_property port_width 1 [get_debug_ports u_ila_0/probe148]
connect_debug_port u_ila_0/probe148 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[25]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe149]
set_property port_width 1 [get_debug_ports u_ila_0/probe149]
connect_debug_port u_ila_0/probe149 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[25]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe150]
set_property port_width 1 [get_debug_ports u_ila_0/probe150]
connect_debug_port u_ila_0/probe150 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[26]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe151]
set_property port_width 1 [get_debug_ports u_ila_0/probe151]
connect_debug_port u_ila_0/probe151 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[26]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe152]
set_property port_width 1 [get_debug_ports u_ila_0/probe152]
connect_debug_port u_ila_0/probe152 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[27]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe153]
set_property port_width 1 [get_debug_ports u_ila_0/probe153]
connect_debug_port u_ila_0/probe153 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[27]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe154]
set_property port_width 1 [get_debug_ports u_ila_0/probe154]
connect_debug_port u_ila_0/probe154 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[28]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe155]
set_property port_width 1 [get_debug_ports u_ila_0/probe155]
connect_debug_port u_ila_0/probe155 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[28]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe156]
set_property port_width 1 [get_debug_ports u_ila_0/probe156]
connect_debug_port u_ila_0/probe156 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[29]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe157]
set_property port_width 1 [get_debug_ports u_ila_0/probe157]
connect_debug_port u_ila_0/probe157 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[29]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe158]
set_property port_width 1 [get_debug_ports u_ila_0/probe158]
connect_debug_port u_ila_0/probe158 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[30]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe159]
set_property port_width 1 [get_debug_ports u_ila_0/probe159]
connect_debug_port u_ila_0/probe159 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[30]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe160]
set_property port_width 1 [get_debug_ports u_ila_0/probe160]
connect_debug_port u_ila_0/probe160 [get_nets [list {u_gpu1/program_duration_count_reg_n_0_[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe161]
set_property port_width 1 [get_debug_ports u_ila_0/probe161]
connect_debug_port u_ila_0/probe161 [get_nets [list {u_gpu2/program_duration_count_reg_n_0_[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe162]
set_property port_width 1 [get_debug_ports u_ila_0/probe162]
connect_debug_port u_ila_0/probe162 [get_nets [list u_gpu1/reset]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe163]
set_property port_width 1 [get_debug_ports u_ila_0/probe163]
connect_debug_port u_ila_0/probe163 [get_nets [list u_gpu/reset]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe164]
set_property port_width 1 [get_debug_ports u_ila_0/probe164]
connect_debug_port u_ila_0/probe164 [get_nets [list u_gpu2/reset]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe165]
set_property port_width 1 [get_debug_ports u_ila_0/probe165]
connect_debug_port u_ila_0/probe165 [get_nets [list reset_prev]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets sys_clk]
