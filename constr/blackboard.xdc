# Pin and timing constraints for the Real Digital Blackboard (Zynq-7000,
# XC7Z007S-1CLG400C).
#

## Clock
set_property PACKAGE_PIN H16 [get_ports clk_in]
set_property IOSTANDARD LVCMOS33 [get_ports clk_in]
create_clock -period 10.000 -name clk_in -waveform {0.000 5.000} [get_ports clk_in]

## Buttons
set_property PACKAGE_PIN R18 [get_ports {btn[0]}]
set_property PACKAGE_PIN R17 [get_ports {btn[1]}]
set_property PACKAGE_PIN W19 [get_ports {btn[2]}]
set_property PACKAGE_PIN T17 [get_ports {btn[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[*]}]

## Switches, sw[0] to sw[7] only (see note above about sw[8:11])
set_property PACKAGE_PIN G15 [get_ports {sw[0]}]
set_property PACKAGE_PIN P15 [get_ports {sw[1]}]
set_property PACKAGE_PIN W13 [get_ports {sw[2]}]
set_property PACKAGE_PIN T16 [get_ports {sw[3]}]
set_property PACKAGE_PIN U19 [get_ports {sw[4]}]
set_property PACKAGE_PIN U9  [get_ports {sw[5]}]
set_property PACKAGE_PIN U10 [get_ports {sw[6]}]
set_property PACKAGE_PIN U8  [get_ports {sw[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[*]}]

## LEDs
set_property PACKAGE_PIN M14 [get_ports {led[0]}]
set_property PACKAGE_PIN M15 [get_ports {led[1]}]
set_property PACKAGE_PIN G14 [get_ports {led[2]}]
set_property PACKAGE_PIN D18 [get_ports {led[3]}]
set_property PACKAGE_PIN N16 [get_ports {led[4]}]
set_property PACKAGE_PIN N14 [get_ports {led[5]}]
set_property PACKAGE_PIN L14 [get_ports {led[6]}]
set_property PACKAGE_PIN L13 [get_ports {led[7]}]
set_property PACKAGE_PIN M2  [get_ports {led[8]}]
set_property PACKAGE_PIN M3  [get_ports {led[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]


# with a shared ground, and set the adapter to 115200 8N1.
set_property PACKAGE_PIN V15 [get_ports uart_tx_pin]
set_property PACKAGE_PIN W15 [get_ports uart_rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]


set_property PACKAGE_PIN Y17 [get_ports vga_hsync]
set_property PACKAGE_PIN Y18 [get_ports vga_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vsync]

set_property PACKAGE_PIN W20 [get_ports {vga_red[0]}]
set_property PACKAGE_PIN Y21 [get_ports {vga_red[1]}]
set_property PACKAGE_PIN Y22 [get_ports {vga_red[2]}]
set_property PACKAGE_PIN AA22 [get_ports {vga_red[3]}]

set_property PACKAGE_PIN Y19 [get_ports {vga_green[0]}]
set_property PACKAGE_PIN Y20 [get_ports {vga_green[1]}]
set_property PACKAGE_PIN AB22 [get_ports {vga_green[2]}]
set_property PACKAGE_PIN AA21 [get_ports {vga_green[3]}]

set_property PACKAGE_PIN AB21 [get_ports {vga_blue[0]}]
set_property PACKAGE_PIN AB20 [get_ports {vga_blue[1]}]
set_property PACKAGE_PIN AB19 [get_ports {vga_blue[2]}]
set_property PACKAGE_PIN AA19 [get_ports {vga_blue[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {vga_red[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_green[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_blue[*]}]

## Config options, standard for this part
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
