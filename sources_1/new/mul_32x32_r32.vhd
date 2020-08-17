----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/13/2020 03:18:52 AM
-- Design Name: 
-- Module Name: mul_32x32_r32 - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity mul_32x32_r32 is
    Port ( 
        operand_A : in std_logic_vector(31 downto 0);	
        operand_B : in std_logic_vector(31 downto 0);	
        result : out std_logic_vector(31 downto 0)
    );
end mul_32x32_r32;

architecture Behavioral of mul_32x32_r32 is
    signal mul_result : std_logic_vector(63 downto 0);
begin
    mul_result <= std_logic_vector (unsigned (operand_A) * unsigned (operand_B));
    result <= mul_result(31 downto 0);
end Behavioral;
