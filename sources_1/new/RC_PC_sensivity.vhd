library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity RC_PC_sensivity is
Port (
    HADDR : in std_logic_vector(31 downto 0);
    invoke_accelerator : out std_logic
 );
end RC_PC_sensivity;

architecture Behavioral of RC_PC_sensivity is

begin
invoke_accelerator_p: process(HADDR) begin
    case HADDR is
      when 
           x"00000088" |  
           x"00000092" |
           x"000000a4" |
           x"000000cc" |
           x"000000da" |
           x"000000fc" |
           x"00000110" |
           x"0000011c" |
           x"0000013a" |
           x"00000152" |
           x"00000178" |
           x"00000182" 
                            =>  invoke_accelerator <= '1';
        when others         =>  invoke_accelerator <= '0';
    end case;
end process;
end Behavioral;