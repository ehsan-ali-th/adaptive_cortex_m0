----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/25/2020 07:50:00 PM
-- Design Name: 
-- Module Name: my_functions - Behavioral
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

package helper_funcs is
    function conv_to_string ( a: std_logic_vector) return string;
    function hexcharacter (nibble: std_logic_vector(3 downto 0)) return character;
    function to_std_logic (in_bit: bit) return std_logic;
    function to_std_logic (in_bit: boolean) return std_logic;


    type core_state_t is (
        s_RESET, 
       -- s_START_DELAY_CYCLE,
        s_RUN,
        s_DATA_MEM_ACCESS,
        s_EXECUTE_DATA_MEM_RW,
        s_FETCH_32_ALIGNED,
        --s_EXEC_INSTA_START, 
        s_EXEC_INSTA, 
        s_EXEC_INSTB, 
        s_PC_UPDATED_INVALID,
        s_EXEC_INSTA_INVALID,
        s_EXEC_INSTB_INVALID,
        s_PC_UNALIGNED,
        s_REFETCH_INSTA,
        s_REFETCH_INSTB
--        s_INSTA_MEM_ACCESS,
--        s_INSTB_MEM_ACCESS,
--        s_INSTA_AFTER_MEM_ACCESS,
--        s_INSTB_AFTER_MEM_ACCESS,
--        s_MEM_ACCESS   
        );

    type executor_cmds_t is (                               -- Executor commands
        MOVS_imm8, MOVS, MOV, 
        ADDS_imm3, ADDS, ADD, ADD_PC,  ADDS_imm8, ADCS,
        SUBS_imm3, SUBS, SUBS_imm8, SBCS,
        RSBS,
        MULS,
        CMP, CMN, CMP_imm8,
        ANDS, EORS, ORRS, BICS, MVNS, TST,
        RORS,
        LDR_imm5,LDR_imm8,
        NOP,
        NOT_DEF
        );  
        
    type flag_t is record 
        N  : bit;                              -- Negative    
        Z  : bit;                              -- Zero 
        C  : bit;                              -- Carry
        V  : bit;                              -- Overflow
        EN : bit_vector (5 downto 0);          -- Exception Number.
        T  : bit;                              -- Thumb code is executed.
    end record;        

end  helper_funcs;

package body helper_funcs is

    function conv_to_string ( a: std_logic_vector) return string is
        variable b : string (1 to a'length) := (others => NUL);
        variable stri : integer := 1; 
        begin
            for i in a'range loop
                b(stri) := std_logic'image(a((i)))(2);
                stri := stri+1;
            end loop;
        return b;
    end function;
    
    --
  -- Function to convert 4-bit binary nibble to hexadecimal character
  --
  -----------------------------------------------------------------------------------------
  --
  function hexcharacter (nibble: std_logic_vector(3 downto 0))  return character is
    variable hex: character;
  begin
    case nibble is
      when "0000" => hex := '0';
      when "0001" => hex := '1';
      when "0010" => hex := '2';
      when "0011" => hex := '3';
      when "0100" => hex := '4';
      when "0101" => hex := '5';
      when "0110" => hex := '6';
      when "0111" => hex := '7';
      when "1000" => hex := '8';
      when "1001" => hex := '9';
      when "1010" => hex := 'A';
      when "1011" => hex := 'B';
      when "1100" => hex := 'C';
      when "1101" => hex := 'D';
      when "1110" => hex := 'E';
      when "1111" => hex := 'F';
      when others => hex := 'x';
    end case;
    return hex;
  end function;

  function to_std_logic (in_bit: bit) return std_logic is
    variable  ret : std_logic;
  begin
    if (in_bit = '0') then
        ret := '0';
    else
        ret := '1';
    end if;   
     return ret; 
  end function;
  
    function to_std_logic (in_bit: boolean) return std_logic is
    variable  ret : std_logic;
  begin
    if (in_bit = false) then
        ret := '0';
    else
        ret := '1';
    end if;   
     return ret; 
  end function;


end  helper_funcs;
