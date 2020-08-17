----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/17/2020 04:48:17 PM
-- Design Name: 
-- Module Name: m0_RC_PC_sensivity - Behavioral
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

entity m0_RC_PC_sensivity is
    Port ( 
        HADDR : in std_logic_vector(31 downto 0);
        invoke_accelerator : out std_logic
    );
end m0_RC_PC_sensivity;

architecture Behavioral of m0_RC_PC_sensivity is

begin
  
    invoke_accelerator_p: process(HADDR) begin
        case HADDR is
            when x"0002_0308" | 
                 x"0002_0312" |
                 x"0002_0324" |
                 x"0002_034c" |
                 x"0002_035a" |
                 x"0002_037c" |
                 x"0002_0390" |
                 x"0002_0390" |
                 x"0002_03ba" |
                 x"0002_03d2" |
                 x"0002_03f8" |
                 x"0002_0402"   
                                =>  invoke_accelerator <= '1';
            when others         =>  invoke_accelerator <= '0';
        end case;
    end process;

end Behavioral;
