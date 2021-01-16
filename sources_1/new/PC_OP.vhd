library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity m0_PC_OP is
Port (
    PC     : in  std_logic_vector(31 downto 0);
    operand : out std_logic_vector(10 downto 0)
 );
end m0_PC_OP;

architecture Behavioral of m0_PC_OP is

begin
PC_to_OP_p: process(PC) begin
  case PC is
      when x"00000088" => operand <= "000" & x"2a";
      when x"00000092" => operand <= "000" & x"2a";
      when x"000000a4" => operand <= "000" & x"08";
      when x"000000cc" => operand <= "000" & x"0e";
      when x"000000da" => operand <= "000" & x"31";
      when x"000000fc" => operand <= "000" & x"21";
      when x"00000110" => operand <= "000" & x"21";
      when x"0000011c" => operand <= "000" & x"21";
      when x"0000013a" => operand <= "000" & x"20";
      when x"00000152" => operand <= "000" & x"21";
      when x"00000178" => operand <= "000" & x"22";
      when x"00000182" => operand <= "000" & x"22";
    when others =>  operand <= (others => '0');
  end case;
end process;
end Behavioral;