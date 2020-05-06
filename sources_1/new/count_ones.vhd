----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/01/2020 03:55:00 PM
-- Design Name: 
-- Module Name: count_ones - Behavioral
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

entity count_ones is
    Port ( byte_in : in STD_LOGIC_VECTOR (7 downto 0);
           ones : out STD_LOGIC_VECTOR (3 downto 0));
end count_ones;

architecture Behavioral of count_ones is

begin

    process (byte_in)
        variable count : unsigned(3 downto 0) := "0000";
    begin
        count := "0000";                               --initialize count variable.
        for i in 0 to 7 loop                            --for all the bits.
            count := count + ("000" & byte_in(i));     --Add the bit to the count.
        end loop;
        ones <= std_logic_vector(count);    --assign the count to output.
    end process;


end Behavioral;
