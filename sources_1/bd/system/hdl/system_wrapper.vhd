--Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
--Date        : Tue Apr 21 09:36:43 2020
--Host        : DESKTOP-GB8O8RC running 64-bit major release  (build 9200)
--Command     : generate_target system_wrapper.bd
--Design      : system_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity system_wrapper is
  port (
    LED0 : out STD_LOGIC;
    LED1 : out STD_LOGIC;
    clk_300mhz_clk_n : in STD_LOGIC;
    clk_300mhz_clk_p : in STD_LOGIC;
    reset : in STD_LOGIC
  );
end system_wrapper;

architecture STRUCTURE of system_wrapper is
  component system is
  port (
    reset : in STD_LOGIC;
    LED0 : out STD_LOGIC;
    LED1 : out STD_LOGIC;
    clk_300mhz_clk_n : in STD_LOGIC;
    clk_300mhz_clk_p : in STD_LOGIC
  );
  end component system;
begin
system_i: component system
     port map (
      LED0 => LED0,
      LED1 => LED1,
      clk_300mhz_clk_n => clk_300mhz_clk_n,
      clk_300mhz_clk_p => clk_300mhz_clk_p,
      reset => reset
    );
end STRUCTURE;
