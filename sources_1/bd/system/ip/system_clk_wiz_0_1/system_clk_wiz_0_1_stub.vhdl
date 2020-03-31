-- Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2018.3 (lin64) Build 2405991 Thu Dec  6 23:36:41 MST 2018
-- Date        : Sun Mar 22 17:45:12 2020
-- Host        : esi-OMEN-by-HP-Laptop-15-dc0xxx running 64-bit Ubuntu 19.04
-- Command     : write_vhdl -force -mode synth_stub
--               /home/esi/workspace/Vivado_2018.3/zcu104/Cortex_M0/Cortex_M0.srcs/sources_1/bd/system/ip/system_clk_wiz_0_1/system_clk_wiz_0_1_stub.vhdl
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
