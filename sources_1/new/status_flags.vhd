----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/24/2020 04:40:02 PM
-- Design Name: 
-- Module Name: status_flags - Behavioral
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

library xil_defaultlib;
use xil_defaultlib.helper_funcs.all;

entity status_flags is
    Port (
        clk : in std_logic;
        reset : in std_logic;
        result : in std_logic_vector(31 downto 0);
        alu_temp_32 : in std_logic;
        overflow_status : in std_logic_vector(2 downto 0);      -- Concatenation of 3 bits: operand_A(31) & imm8_z_ext(31) & alu_result(31);
        cmd : in executor_cmds_t;
        set_flags : in boolean; 
        flags_o : out flag_t
    );
end status_flags;

architecture Behavioral of status_flags is
    signal status_flags : bit_vector(31 downto 0) := (others=>'0');
        
    alias N : bit is status_flags(31);
    alias Z : bit is status_flags(30);
    alias C : bit is status_flags(29);
    alias V : bit is status_flags(28);
    alias EN : bit_vector is status_flags(5 downto 0);
    alias T : bit is status_flags(24);

begin

    cmd_p: process(reset, cmd, result, set_flags, overflow_status, alu_temp_32) begin
        if reset = '0' then 
            if set_flags then
                -- how to calculate overflow:
                -- There are two cases where the overflow flag would be turned on during a binary arithmetic operation:
                -- 1) The inputs both have sign bits that are off, while the result has a sign bit that is on.
                -- 2) The inputs both have sign bits that are on, while the result has a sign bit that is off.
                -- concat the three relevant sign-bits to one vector

                case (cmd) is
                    ------------------------------------------------------------ -- MOVS Rd, #(imm8)
                    when MOVS_imm8 =>                                       
                        -- APSR.N = result<31>;
                        -- APSR.Z = IsZeroBit(result);
                        -- APSR.C = carry;
                        -- // APSR.V unchanged
                        N <= to_bit (result(31));    
                        if (to_integer(unsigned(result)) = 0) then Z <= '1'; else Z <= '0'; end if;
                        C <= '0';
                    ------------------------------------------------------------ -- MOVS <Rd>,<Rm>    
                    ------------------------------------------------------------ -- MOV <Rd>,<Rm> | MOV PC, Rm       
                    when MOVS | MOV =>
                        -- APSR.N = result<31>;
                        -- APSR.Z = IsZeroBit(result);
                        -- // APSR.C unchanged
                        -- // APSR.V unchanged
                        N <= to_bit (result(31));  
                        if (to_integer(unsigned(result)) = 0) then Z <= '1'; else Z <= '0'; end if;
                    ------------------------------------------------------------ -- ADDS <Rd>,<Rn>,#<imm3>      
                    ------------------------------------------------------------ -- ADDS <Rd>,<Rn>,<Rm>       
                    ------------------------------------------------------------ -- ADDS <Rdn>,#<imm8>   
                    ------------------------------------------------------------ -- ADCS <Rdn>,<Rm>  
                    ------------------------------------------------------------ -- SUBS <Rd>,<Rn>,<Rm>
                    ------------------------------------------------------------ -- SUBS <Rd>,<Rn>,#<imm3>  
                    ------------------------------------------------------------ -- SBCS <Rdn>,<Rm>   
                    ------------------------------------------------------------ -- RSBS <Rd>,<Rn>,#0
                    ------------------------------------------------------------ -- CMP <Rn>,<Rm>
                    ------------------------------------------------------------ -- CMN <Rn>,<Rm>     
                    when ADDS_imm3 | ADDS | ADDS_imm8 | ADCS | 
                          SUBS | SUBS_imm8 | SBCS | RSBS |
                          CMP | CMN =>    
                        -- APSR.N = result<31>;
                        -- APSR.Z = IsZeroBit(result);
                        -- APSR.C = carry;
                        -- APSR.V = overflow;
                        N <= to_bit (result(31)); 
                        if (to_integer(unsigned(result)) = 0) then Z <= '1'; else Z <= '0'; end if;
                        C <= to_bit(alu_temp_32);
                        if ((overflow_status = B"001") or (overflow_status = B"110")) then V <= '1'; else V <= '0'; end if;
                    ------------------------------------------------------------ -- MULS <Rdm>,<Rn>,<Rdm>     
                    when MULS =>
                        -- APSR.N = result<31>;
                        -- APSR.Z = IsZeroBit(result<31:0>);
                        -- // APSR.C unchanged
                        -- // APSR.V unchanged
                        N <= to_bit (result(31)); 
                        if (to_integer(unsigned(result)) = 0) then Z <= '1'; else Z <= '0'; end if;
                    when others =>  
                        null;
                 end case;
              end if; -- set_flags
         else
            status_flags <= (others => '0');
         end if;      
        
    end process cmd_p;

    flags_o.N <= N;
    flags_o.Z <= Z;
    flags_o.C <= C;
    flags_o.V <= V;
    flags_o.EN <= EN;
    flags_o.T <= T;

end Behavioral;
