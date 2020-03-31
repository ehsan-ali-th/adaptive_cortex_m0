// Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3 (lin64) Build 2405991 Thu Dec  6 23:36:41 MST 2018
// Date        : Sun Mar 22 17:45:12 2020
// Host        : esi-OMEN-by-HP-Laptop-15-dc0xxx running 64-bit Ubuntu 19.04
// Command     : write_verilog -force -mode synth_stub
//               /home/esi/workspace/Vivado_2018.3/zcu104/Cortex_M0/Cortex_M0.srcs/sources_1/bd/system/ip/system_clk_wiz_0_1/system_clk_wiz_0_1_stub.v
// Design      : system_clk_wiz_0_1
// Purpose     : Stub declaration of top-level module interface
// Device      : xczu7ev-ffvc1156-2-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module system_clk_wiz_0_1(CLK, reset, locked, clk_in1_p, clk_in1_n)
/* synthesis syn_black_box black_box_pad_pin="CLK,reset,locked,clk_in1_p,clk_in1_n" */;
  output CLK;
  input reset;
  output locked;
  input clk_in1_p;
  input clk_in1_n;
endmodule
