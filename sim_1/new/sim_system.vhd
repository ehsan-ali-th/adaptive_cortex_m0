----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/22/2020 05:44:50 PM
-- Design Name: 
-- Module Name: sim_system - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sim_system is
--  Port ( );
end sim_system;

architecture Behavioral of sim_system is

    component system is
      port (
        LED0 : out STD_LOGIC;
        LED1 : out STD_LOGIC;
        clk_300mhz_clk_n : in STD_LOGIC;
        clk_300mhz_clk_p : in STD_LOGIC;
        reset : in STD_LOGIC
      );
    end component;

  -- inputs
    signal clk300Mhz_n: std_logic := '0';
    signal clk300Mhz_p: std_logic := '1';
    signal reset: std_logic := '0';

    -- outputs
    signal led0: std_logic := '0';
    signal led1: std_logic := '0';

    constant half_period300 : time := 3.3333 ns; -- produce 300Mhz clock  
begin

    clk300Mhz_n <= not clk300Mhz_n after half_period300;
    clk300Mhz_p <= not clk300Mhz_p after half_period300;
    
    tb: process begin
        wait for 100ns;
        reset <= '0';
        wait for 200ns;
        reset <= '1';
        wait for 500ns;
        reset <= '0';
        wait; -- wait forever
    end process;

    -- Instantiate UUT
    uut: system port map (
        clk_300mhz_clk_n => clk300Mhz_n,
        clk_300mhz_clk_p => clk300Mhz_p,
        reset => reset,
        LED0 => led0,
        LED1 => led1
    );
    
    process begin
        wait for 3000 ns;
        report "Simulation finished"  severity note;
        std.env.finish;
    end process;


end Behavioral;
