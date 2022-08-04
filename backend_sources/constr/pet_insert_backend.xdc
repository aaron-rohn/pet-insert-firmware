set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 3 [current_design]
set_property CONFIG_MODE SPIx1 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 1 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 2.5 [current_design]

create_clock -period 10 [get_ports clk_100_p]

create_clock -period 11.111 [get_ports sys_clk_p]
#create_clock -period 8.696 [get_ports sys_clk_p]
#create_clock -period 10 [get_ports sys_clk_p]

create_clock -period 11.111 [get_ports m_data_clk_p[0]]
create_clock -period 11.111 [get_ports m_data_clk_p[1]]
create_clock -period 11.111 [get_ports m_data_clk_p[2]]
create_clock -period 11.111 [get_ports m_data_clk_p[3]]

### System ports ###

set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN E12} [get_ports sys_clk_p]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN E13} [get_ports sys_clk_n]

set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN P15} [get_ports sys_rst_p]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN P16} [get_ports sys_rst_n]

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN B11} [get_ports status_fpga]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN C9}  [get_ports status_modules]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN B10} [get_ports status_network]

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN H16} [get_ports sda]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN G16} [get_ports scl]

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN L12} [get_ports config_spi_ncs]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN D4} [get_ports clk_100_p]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN C4} [get_ports clk_100_n]

### Module Ports ###

set_property -dict {IOSTANDARD LVCMOS25 DRIVE 16 PACKAGE_PIN J16} [get_ports m_en[0]]
set_property -dict {IOSTANDARD LVCMOS25 DRIVE 16 PACKAGE_PIN R11} [get_ports m_en[1]]
set_property -dict {IOSTANDARD LVCMOS25 DRIVE 16 PACKAGE_PIN B12} [get_ports m_en[2]]
set_property -dict {IOSTANDARD LVCMOS25 DRIVE 16 PACKAGE_PIN G15} [get_ports m_en[3]]

# clocks to frontend
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN K13} [get_ports m_clk_p[0]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN L13} [get_ports m_clk_n[0]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN R6}  [get_ports m_clk_p[1]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN R7}  [get_ports m_clk_n[1]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN A8}  [get_ports m_clk_p[2]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN A9}  [get_ports m_clk_n[2]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN C16} [get_ports m_clk_p[3]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN B16} [get_ports m_clk_n[3]]

# control to frontend
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN M16} [get_ports m_ctrl_p[0]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN N16} [get_ports m_ctrl_n[0]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN R5}  [get_ports m_ctrl_p[1]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN T5}  [get_ports m_ctrl_n[1]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN B9}  [get_ports m_ctrl_p[2]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN A10} [get_ports m_ctrl_n[2]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN E16} [get_ports m_ctrl_p[3]]
set_property -dict {IOSTANDARD LVDS_25 PACKAGE_PIN D16} [get_ports m_ctrl_n[3]]

# data clock from frontend
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN N14} [get_ports m_data_clk_p[0]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN P14} [get_ports m_data_clk_n[0]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN N11} [get_ports m_data_clk_p[1]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN N12} [get_ports m_data_clk_n[1]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN F5}  [get_ports m_data_clk_p[2]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN E5}  [get_ports m_data_clk_n[2]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN D13} [get_ports m_data_clk_p[3]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN C13} [get_ports m_data_clk_n[3]]

# Module 1 data ports
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN R15} [get_ports m_data_p[0]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN R16} [get_ports m_data_n[0]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN T14} [get_ports m_data_p[1]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN T15} [get_ports m_data_n[1]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN R13} [get_ports m_data_p[2]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN T13} [get_ports m_data_n[2]]

# Module 2 data ports
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN R12} [get_ports m_data_p[3]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN T12} [get_ports m_data_n[3]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN T9}  [get_ports m_data_p[4]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN T10} [get_ports m_data_n[4]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN T7}  [get_ports m_data_p[5]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN T8}  [get_ports m_data_n[5]]

# Module 3 data ports
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN D6}  [get_ports m_data_p[6]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN D5}  [get_ports m_data_n[6]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN C7}  [get_ports m_data_p[7]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN C6}  [get_ports m_data_n[7]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN A13} [get_ports m_data_p[8]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN A14} [get_ports m_data_n[8]]

# Module 4 data ports
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN B15} [get_ports m_data_p[9]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN A15} [get_ports m_data_n[9]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN C14} [get_ports m_data_p[10]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN B14} [get_ports m_data_n[10]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN D14} [get_ports m_data_p[11]]
set_property -dict {IOSTANDARD LVDS_25 DIFF_TERM TRUE PACKAGE_PIN D15} [get_ports m_data_n[11]]

### High speed GigEx interface ports ###

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R2} [get_ports user_hs_clk]

# Fifo RX ports

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN C1} [get_ports {Q[0]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN C2} [get_ports {Q[1]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN D3} [get_ports {Q[2]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN D1} [get_ports {Q[3]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN E1} [get_ports {Q[4]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN E3} [get_ports {Q[5]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN F3} [get_ports {Q[6]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN E2} [get_ports {Q[7]}]

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN K1} [get_ports nRx]

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN K3} [get_ports {RC[0]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN L3} [get_ports {RC[1]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN L2} [get_ports {RC[2]}]

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN T2} [get_ports {nRF[0]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R1} [get_ports {nRF[1]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN T4} [get_ports {nRF[2]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN N2} [get_ports {nRF[3]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN N4} [get_ports {nRF[4]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN N1} [get_ports {nRF[5]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN M2} [get_ports {nRF[6]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN N3} [get_ports {nRF[7]}]

# Fifo TX ports

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN F2} [get_ports {D[0]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN F4} [get_ports {D[1]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN G4} [get_ports {D[2]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN G1} [get_ports {D[3]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN G2} [get_ports {D[4]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN H4} [get_ports {D[5]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN H3} [get_ports {D[6]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN H1} [get_ports {D[7]}]

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN T3} [get_ports nTx]

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN P3} [get_ports {TC[0]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN P1} [get_ports {TC[1]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN P4} [get_ports {TC[2]}]

set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN H2} [get_ports {nTF[0]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN J3} [get_ports {nTF[1]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN J4} [get_ports {nTF[2]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN J1} [get_ports {nTF[3]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN K2} [get_ports {nTF[4]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN M1} [get_ports {nTF[5]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN M4} [get_ports {nTF[6]}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN R3} [get_ports {nTF[7]}]

# Master SPI GigEx interface ports
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN C3} [get_ports {gigex_spi_cs}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN B1} [get_ports {gigex_spi_sck}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN B2} [get_ports {gigex_spi_miso}]
set_property -dict {IOSTANDARD LVCMOS25 PACKAGE_PIN A2} [get_ports {gigex_spi_mosi}]
