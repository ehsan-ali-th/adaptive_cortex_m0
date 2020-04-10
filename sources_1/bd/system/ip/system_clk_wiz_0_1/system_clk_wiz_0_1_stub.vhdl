-- Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
-- Date        : Thu Apr  9 20:19:20 2020
-- Host        : DESKTOP-GB8O8RC running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               D:/workspace/Vivado_2019.2/Cortex_M0/Cortex_M0.srcs/sources_1/bd/system/ip/system_clk_wiz_0_1/system_clk_wiz_0_1_stub.vhdl
-- Design      : system_clk_wiz_0_1
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xczu7ev-ffvc1156-2-e
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity system_clk_wiz_0_1 is
  Port ( 
    CLK : out STD_LOGIC;
    reset : in STD_LOGIC;
    locked : out STD_LOGIC;
    clk_in1_p : in STD_LOGIC;
    clk_in1_n : in STD_LOGIC
  );

end system_clk_wiz_0_1;

architecture stub of system_clk_wiz_0_1 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "CLK,reset,locked,clk_in1_p,clk_in1_n";
begin
end;
