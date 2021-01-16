----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/30/2020 03:51:00 PM
-- Design Name: 
-- Module Name: global_sig - Behavioral
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

package GlobalSignalsPkg is
  -- synthesis translate_off 
  signal cortex_m0_clk : std_logic ; 
  signal cortex_m0_current_instruction : std_logic_vector (15 downto 0) ; 
  -- synthesis translate_on 
end package GlobalSignalsPkg ; 


 
---- Package Body Section
--package body GlobalSignalsPkg is

--end package body GlobalSignalsPkg;

