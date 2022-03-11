set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 12 [current_design]
set_property CONFIG_MODE SPIx1 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 2.5 [current_design]

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN L12} [get_ports config_spi_ncs]

create_clock -period 10 [get_ports sys_clk_p]

# Differential signals

set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN F5} [get_ports sys_clk_p]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN E5} [get_ports sys_clk_n]

set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN B2} [get_ports sys_ctrl_p]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN A2} [get_ports sys_ctrl_n]

set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN D4} [get_ports data_clk_p]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN C4} [get_ports data_clk_n]

set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN A5} [get_ports {data_p[0]}]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN A4} [get_ports {data_n[0]}]

set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN B6} [get_ports {data_p[1]}]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN B5} [get_ports {data_n[1]}]

set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN B7} [get_ports {data_p[2]}]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN A7} [get_ports {data_n[2]}]

# Misc signals

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN A12} [get_ports {SDA}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN B12} [get_ports {SCL}]

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN G1}  [get_ports {module_id[0]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN E1}  [get_ports {module_id[1]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN D1}  [get_ports {module_id[2]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN C1}  [get_ports {module_id[3]}]


# Block 1 timing front, rear
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN T3}  [get_ports {block1[0]}] # TIMING1_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN T13} [get_ports {block1[1]}] # TIMING1_REAR
# Block 1 Front
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R2}  [get_ports {block1[2]}] # B1_FRONT -> A1_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN T2}  [get_ports {block1[3]}] # C1_FRONT -> B1_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R3}  [get_ports {block1[4]}] # D1_FRONT -> C1_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R1}  [get_ports {block1[5]}] # A1_FRONT -> D1_FRONT
# Block 1 Rear
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN T14} [get_ports {block1[6]}] # B1_REAR -> A1_REAR
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R16} [get_ports {block1[7]}] # C1_REAR -> B1_REAR
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R15} [get_ports {block1[8]}] # D1_REAR -> C1_REAR
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN T15} [get_ports {block1[9]}] # A1_REAR -> D1_REAR


# Block 2 timing front, rear
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R6}  [get_ports {block2[0]}] # TIMING2_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN T10} [get_ports {block2[1]}] # TIMING2_REAR
# Block 2 Front
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN T4}  [get_ports {block2[2]}] # B2_FRONT -> A2_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R5}  [get_ports {block2[3]}] # C2_FRONT -> B2_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN T5}  [get_ports {block2[4]}] # D2_FRONT -> C2_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN P4}  [get_ports {block2[5]}] # A2_FRONT -> D2_FRONT
# Block 2 Rear
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R12} [get_ports {block2[6]}] # B2_REAR -> A2_REAR
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN T12} [get_ports {block2[7]}] # C2_REAR -> B2_REAR
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R13} [get_ports {block2[8]}] # D2_REAR -> C2_REAR
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R11} [get_ports {block2[9]}] # A2_REAR -> D2_REAR


# Block 3 timing front, rear
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN M16} [get_ports {block3[0]}] # TIMING3_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN M2}  [get_ports {block3[1]}] # TIMING3_REAR
# Block 3 Front
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN M14} [get_ports {block3[2]}] # A3_FRONT -> A3_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN P15} [get_ports {block3[3]}] # D3_FRONT -> B3_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN P16} [get_ports {block3[4]}] # C3_FRONT -> C3_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN N16} [get_ports {block3[5]}] # B3_FRONT -> D3_FRONT
# Block 3 Rear
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN N2}  [get_ports {block3[6]}] # B3_REAR -> A3_REAR
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN M1}  [get_ports {block3[7]}] # C3_REAR -> B3_REAR
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN N1}  [get_ports {block3[8]}] # D3_REAR -> C3_REAR
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN P1}  [get_ports {block3[9]}] # A3_REAR -> D3_REAR


# Block 4 timing front, rear
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN H16} [get_ports {block4[0]}] # TIMING4_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN K1}  [get_ports {block4[1]}] # TIMING4_REAR
# Block 4 Front
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN G16} [get_ports {block4[2]}] # A4_FRONT -> A4_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN J16} [get_ports {block4[3]}] # D4_FRONT -> B4_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN G15} [get_ports {block4[4]}] # C4_FRONT -> C4_FRONT
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN J15} [get_ports {block4[5]}] # B4_FRONT -> D4_FRONT
# Block 4 Rear
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN J1}  [get_ports {block4[6]}] # B4_REAR -> A4_REAR
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN L3}  [get_ports {block4[7]}] # C4_REAR -> B4_REAR
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN K2}  [get_ports {block4[8]}] # D4_REAR -> C4_REAR
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN L2}  [get_ports {block4[9]}] # A4_REAR -> D4_REAR
