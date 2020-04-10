// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
// Date        : Thu Apr  9 20:19:20 2020
// Host        : DESKTOP-GB8O8RC running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               D:/workspace/Vivado_2019.2/Cortex_M0/Cortex_M0.srcs/sources_1/bd/system/ip/system_clk_wiz_0_1/system_clk_wiz_0_1_stub.v
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
