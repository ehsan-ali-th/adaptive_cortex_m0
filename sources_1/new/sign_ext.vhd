----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/04/2020 02:28:18 PM
-- Design Name: 
-- Module Name: sign_ext - Behavioral
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

entity sign_ext is
    generic(
        in_byte_width : integer := 8
    );
    Port (
        in_byte:    in  std_logic_vector(in_byte_width - 1 downto 0);
        ret:        out std_logic_vector(31 downto 0)
    );
end sign_ext;

architecture Behavioral of sign_ext is

begin
    ret_p: process (in_byte) begin
        if (in_byte(in_byte_width - 1) = '1') then
            ret (31 downto in_byte_width) <= (others => '1');  
        else
            ret (31 downto in_byte_width) <= (others => '0');  
        end if;
    end process;

    ret (in_byte_width - 1 downto 0) <= in_byte;
end Behavioral;
