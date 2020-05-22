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
   
    
    -- Vector Table
--    constant VT_RESET       : integer := 1;
--    constant VT_NMI         : integer := 2;
--    constant VT_HardFault   : integer := 3;
--    constant VT_SVCall      : integer := 11;
--    constant VT_PendSV      : integer := 14;
--    constant VT_SysTick     : integer := 15;
    
    -- type M0_vector_table is array (0 to 15) of std_logic_vector (31 downto 0);

 

    type core_state_t is (
        s_RESET, 
        s_SET_SP,
        s_FETCH_PC,
        s_SET_PC,
        s_PRE1_RUN,
        s_PRE2_RUN,
        s_RUN,
        s_DATA_MEM_ACCESS_R,
        s_DATA_MEM_ACCESS_W,
        s_EXECUTE_DATA_MEM_R,
        s_EXECUTE_DATA_MEM_W,
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
        s_DATA_MEM_ACCESS_EXECUTE_LDM_R7,
        s_FINISH_STM,
        s_DATA_REG_ACCESS_EXECUTE_STM_R0,
        s_DATA_REG_ACCESS_EXECUTE_STM_R1,
        s_DATA_REG_ACCESS_EXECUTE_STM_R2,
        s_DATA_REG_ACCESS_EXECUTE_STM_R3,
        s_DATA_REG_ACCESS_EXECUTE_STM_R4,
        s_DATA_REG_ACCESS_EXECUTE_STM_R5,
        s_DATA_REG_ACCESS_EXECUTE_STM_R6,
        s_DATA_REG_ACCESS_EXECUTE_STM_R7,
        s_FINISH_PUSH,
        s_DATA_REG_ACCESS_EXECUTE_PUSH_R0,
        s_DATA_REG_ACCESS_EXECUTE_PUSH_R1,
        s_DATA_REG_ACCESS_EXECUTE_PUSH_R2,
        s_DATA_REG_ACCESS_EXECUTE_PUSH_R3,
        s_DATA_REG_ACCESS_EXECUTE_PUSH_R4,
        s_DATA_REG_ACCESS_EXECUTE_PUSH_R5,
        s_DATA_REG_ACCESS_EXECUTE_PUSH_R6,
        s_DATA_REG_ACCESS_EXECUTE_PUSH_R7,
        s_DATA_REG_ACCESS_EXECUTE_PUSH_LM
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
        LDR_imm5, LDRH_imm5, LDRB_imm5, LDR, LDRH, LDRSH, LDRB, 
        LDRSB, LDR_label,   LDM,
        STR_imm5, STRH_imm5, STRB_imm5, STR, STRH,        STRB, 
               STR_SP_imm8, STM,
        PUSH,       
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
        sel_LDM,                -- Put LDM_STM_mem_addr on the HADDR bus
        sel_STM,                -- Put LDM_STM_mem_addr on the HADDR bus
        sel_WDATA,              -- Put data on the HADDR to be written into memory
        sel_VECTOR_TABLE,
        sel_SP_main_addr
    );   
   
    type gp_data_in_ctrl_t is (
        sel_ALU_RESULT,
        sel_HRDATA_VALUE_SIZED,
        sel_LDM_DATA,
        sel_STM_total_bytes_wrote,
        sel_LDM_Rn,
        sel_SP_main_init,
        sel_SP_set,
        sel_PC_init,
        sel_gp_data_in_NC
    );
    
    type hrdata_ctrl_t is (
        sel_ALU_RESULT,
        sel_HRDATA_VALUE_SIZED,
        sel_LDM_DATA,
        sel_STM_total_bytes_wrote,
        sel_LDM_Rn,
        sel_SP_main_init,
        sel_PC_init,
        sel_gp_data_in_NC,
        sel_NC
    );    

    type low_register_t is (
        REG_R0, 
        REG_R1, 
        REG_R2, 
        REG_R3, 
        REG_R4, 
        REG_R5, 
        REG_R6, 
        REG_R7,
        REG_LM,
        REG_NONE 
   );   
   
   type access_mem_mode_t is (
        MEM_ACCESS_READ, 
        MEM_ACCESS_WRITE, 
        MEM_ACCESS_NONE
   );  
   
   type VT_ctrl_t is (
        VT_SP_main,
        VT_RESET,
        VT_NMI,
        VT_HardFault,
        VT_SVCall,
        VT_PendSV,
        VT_SysTick,
        VT_NONE 
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
 
    function run_next_state_calc (
        access_mem      : boolean; 
        access_mem_mode : access_mem_mode_t;
        execution_cmd   : executor_cmds_t;
        PC_updated      : boolean; 
        imm8            : std_logic_vector (7 downto 0);
        LM              : std_logic) return  core_state_t; 
  
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
    
   
    
     function run_next_state_calc (
        access_mem      : boolean; 
        access_mem_mode : access_mem_mode_t;
        execution_cmd   : executor_cmds_t;
        PC_updated      : boolean;
        imm8            : std_logic_vector (7 downto 0);
        LM              : std_logic) return core_state_t is
        variable next_state : core_state_t;
      begin
            -- If you modify something here then remember to copy it to s_FINISH_STM
            -- CHECK if instruction needs memory access
            if (access_mem = true) then 
                if (access_mem_mode = MEM_ACCESS_READ) then 
                    if (execution_cmd = LDM) then
                        next_state := s_DATA_MEM_ACCESS_LDM;
                    else
                        next_state := s_DATA_MEM_ACCESS_R;
                    end if;  
                elsif (access_mem_mode = MEM_ACCESS_WRITE) then
                    if (execution_cmd = STM) then
                        if (imm8(0) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R0;
                        elsif (imm8(1) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R1;
                        elsif (imm8(2) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R2;
                        elsif (imm8(3) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R3;
                        elsif (imm8(4) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R4;
                        elsif (imm8(5) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R5;
                        elsif (imm8(6) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                        elsif (imm8(7) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                        else
                            next_state := s_FINISH_STM;
                        end if;
                    elsif (execution_cmd = PUSH) then
                        if (imm8(0) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R0;
                        elsif (imm8(1) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R1;
                        elsif (imm8(2) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R2;
                        elsif (imm8(3) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R3;
                        elsif (imm8(4) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R4;
                        elsif (imm8(5) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R5;
                        elsif (imm8(6) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R6;
                        elsif (imm8(7) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R7;
                        elsif (LM = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_LM;     
                        else
                            next_state := s_FINISH_STM;
                        end if;    
                    else
                        next_state := s_DATA_MEM_ACCESS_W;
                    end if; 
                else 
                    -- access_mem_mode = MEM_ACCESS_NONE
                
                end if;      
                -- CHECK if instruction updates PC
            elsif (PC_updated = true) then
                next_state := s_PC_UPDATED;
            else    
                next_state := s_RUN;     
            end if;  
        
        return  next_state; 
  end function;

end  helper_funcs;
