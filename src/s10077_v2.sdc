//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.10.03 Education 
//Created Time: 2025-09-24 17:32:31
create_clock -name FPGA_CLK -period 37.037 -waveform {0 18.518} [get_ports {FPGA_CLK}]
create_generated_clock -name SENSOR_CLK -source [get_ports {FPGA_CLK}] -divide_by 16 [get_ports {SENSOR_CLK}]
//create_clock -name tck_pad_i -period 200 -waveform {0 100} [get_ports {tck_pad_i}]
//set_clock_groups -asynchronous -group [get_clocks {SENSOR_CLK}] -group [get_clocks {tck_pad_i}]