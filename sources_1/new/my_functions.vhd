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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

package helper_funcs is
    -- general
    function conv_to_string ( a: std_logic_vector) return string;
    function hexcharacter (nibble: std_logic_vector(3 downto 0)) return character;
    function to_std_logic (in_bit: bit) return std_logic;
    function to_std_logic (in_bit: boolean) return std_logic;
    

 

    type core_state_t is (
        s_RESET, 
        s_RESET1, 
        s_RESET2, 
        s_RUN,
        s_DATA_MEM_ACCESS,
        s_EXECUTE_DATA_MEM_RW,
        s_PC_UPDATED,
        s_PIPELINE_FLUSH1,
        s_PIPELINE_FLUSH2,
        s_PIPELINE_FLUSH3,
        s_DATA_MEM_ACCESS_LDM,
        s_DATA_MEM_ACCESS_EXECUTE_LDM_R0,
        s_DATA_MEM_ACCESS_EXECUTE_LDM_R1,
        s_DATA_MEM_ACCESS_EXECUTE_LDM_R2,
        s_DATA_MEM_ACCESS_EXECUTE_LDM_R3,
        s_DATA_MEM_ACCESS_EXECUTE_LDM_R4,
        s_DATA_MEM_ACCESS_EXECUTE_LDM_R5,
        s_DATA_MEM_ACCESS_EXECUTE_LDM_R6,
        s_DATA_MEM_ACCESS_EXECUTE_LDM_R7
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
        LSLS_imm5, LSLS, LSRS_imm5, LSRS, ASRS_imm5, ASRS,
        LDR_imm5, LDRH_imm5, LDRB_imm5, LDRH, LDRSH, LDRB, 
        LDRSB, LDR_label, LDM,
        NOP,
        NOT_DEF
        );  
        
   type mem_op_size_t is (
        WORD,               -- 4
        HALF_WORD,          -- 2
        BYTE,               -- 1
        NOT_DEF
   );   
   
    type haddr_ctrl_t is (
        sel_PC,                 -- Put PC on the HADDR bus
        sel_DATA,               -- Put data_memory_addr on the HADDR bus
        sel_LDM                 -- Put data_memory_addr_i (base_reg_content) on the HADDR bus
        
   );   
   
   type gp_data_in_ctrl_t is (
        ALU_RESULT,
        HRDATA_VALUE_SIZED,
        LDM_DATA,
        LDM_Rn
   );  
   
  type low_register_t is (
        R0, 
        R1, 
        R2, 
        R3, 
        R4, 
        R5, 
        R6, 
        R7,
        NONE 
   );   
   
   
  
  
        
    type flag_t is record 
        N  : bit;                              -- Negative    
        Z  : bit;                              -- Zero 
        C  : bit;                              -- Carry
        V  : bit;                              -- Overflow
        EN : bit_vector (5 downto 0);          -- Exception Number.
        T  : bit;                              -- Thumb code is executed.
    end record;        
    
    -- Cortex-M0 functions
    function IsAligned (
        address : in std_logic_vector (31 downto 0);
        size : in integer) return boolean;
    function set_LDM_target_reg (imm8 : in std_logic_vector (7 downto 0)) return low_register_t;    

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
  
    function IsAligned ( address : in std_logic_vector (31 downto 0);
                         size : in integer) return boolean is
        variable ret : boolean;
        begin
        
        assert (size = 1 or size = 2 or size = 4) report "Memory address size is wrong." severity failure;
       
       case (size) is
        when 1 => ret := true;
        when 2 => 
            if (address (0) = '0') then
                ret := true;
            else
                ret := false;
            end if;
       when 4 =>  
            if (address (1 downto 0) = B"00") then
                ret := true;
            else
                ret := false;
            end if;   
        when others => ret := false;
       end case;
       
       return ret; 
    end function;
    
    function set_LDM_target_reg (imm8 : in std_logic_vector (7 downto 0)) return low_register_t is
        variable target_reg : low_register_t;
    begin
        if    (imm8(0) = '1') then
            target_reg := R0;
        elsif (imm8(1) = '1') then   
            target_reg := R1;
        elsif (imm8(2) = '1') then   
            target_reg := R2;
        elsif (imm8(3) = '1') then   
            target_reg := R3;
        elsif (imm8(4) = '1') then   
            target_reg := R4;
        elsif (imm8(5) = '1') then   
            target_reg := R5;
        elsif (imm8(6) = '1') then   
            target_reg := R6;
        elsif (imm8(7) = '1') then   
            target_reg := R7;
        else
            target_reg := NONE;    
        end if;  
        return target_reg;    
    end function;

end  helper_funcs;
