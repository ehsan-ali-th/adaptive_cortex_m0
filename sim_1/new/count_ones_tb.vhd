----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/01/2020 04:00:11 PM
-- Design Name: 
-- Module Name: count_ones_tb - Behavioral
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

entity count_ones_tb is
--  Port ( );
end count_ones_tb;

architecture Behavioral of count_ones_tb is

    component count_ones is
        Port ( byte_in : in STD_LOGIC_VECTOR (7 downto 0);
               ones : out STD_LOGIC_VECTOR (3 downto 0));
    end component;

    signal byte_in :  STD_LOGIC_VECTOR (7 downto 0);
    signal ones :  STD_LOGIC_VECTOR (3 downto 0);

begin


    uut: count_ones port map ( 
        byte_in => byte_in,
        ones => ones);
        
    process begin
        wait for 100 ns;
        byte_in <= B"0000_0000";
        wait for 100 ns;
        byte_in <= B"0000_0001";
        wait for 100 ns;
        byte_in <= B"0001_0001";
        wait for 100 ns;
        byte_in <= B"1111_0000";
        wait for 100 ns;
        byte_in <= B"1111_1111";
        wait for 100 ns;
        byte_in <= B"0000_1111";
        wait for 100 ns;
        byte_in <= B"1010_1010";
        wait for 100 ns;
        byte_in <= B"0101_0101";
        wait for 100 ns;
        byte_in <= B"1111_1100";
        wait for 100 ns;
        byte_in <= B"0011_1111";
        wait for 100 ns;
        byte_in <= B"1100_0011";
                
        wait for 100 ns;
        report "Simulation finished"  severity note;
        std.env.finish;
    end process;    


end Behavioral;
