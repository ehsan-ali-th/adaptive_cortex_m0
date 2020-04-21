----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/20/2020 07:45:23 PM
-- Design Name: 
-- Module Name: pipeline_invalidator_test - Behavioral
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

entity pipeline_invalidator_test is
--  Port ( );
end pipeline_invalidator_test;

architecture Behavioral of pipeline_invalidator_test is

component pipeline_invalidator is
    Port (
        clk : in std_logic;
        reset : in std_logic;
        trigger : in boolean;
        invalidate_pipeline : out boolean
     );
end component;

    -- inputs
    signal clk: std_logic := '0';
    signal reset: std_logic := '1';
    signal trigger: boolean := false;

    -- outputs
    signal invalidate_pipeline: boolean := false;

     constant half_clk : time  := 5 ns; 

begin

   clk <= not clk after half_clk;

    tb: process begin
        wait for 100ns; 
        reset <= '1';
        wait for 10ns;
        reset <= '0';
        wait for 25ns;
        trigger <= true;
        wait for 40ns;
        trigger <= false;
        wait; -- wait forever
    end process;

    -- Instantiate UUT
    uut: pipeline_invalidator port map (
        clk => clk,
        reset => reset,
        trigger => trigger,
        invalidate_pipeline => invalidate_pipeline
    );
    
    process begin
        wait for 1000 ns;
        report "Simulation finished"  severity note;
        std.env.finish;
    end process;
end Behavioral;
