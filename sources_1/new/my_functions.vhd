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
    function to_std_logic_vector (in_bit_vector: bit_vector) return std_logic_vector;
    
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
        s_DATA_REG_ACCESS_EXECUTE_PUSH_LR,
        s_DATA_MEM_ACCESS_POP,
        s_DATA_MEM_ACCESS_EXECUTE_POP_R0,
        s_DATA_MEM_ACCESS_EXECUTE_POP_R1,
        s_DATA_MEM_ACCESS_EXECUTE_POP_R2,
        s_DATA_MEM_ACCESS_EXECUTE_POP_R3,
        s_DATA_MEM_ACCESS_EXECUTE_POP_R4,
        s_DATA_MEM_ACCESS_EXECUTE_POP_R5,
        s_DATA_MEM_ACCESS_EXECUTE_POP_R6,
        s_DATA_MEM_ACCESS_EXECUTE_POP_R7,
        s_DATA_MEM_ACCESS_EXECUTE_POP_PC,
        s_BRANCH_PC_UPDATED,
        s_BRANCH_Phase1,
        s_BRANCH_Phase2,
        s_BRANCH_UNCOND_PC_UPDATED,
        s_BRANCH_BL_UNCOND_PC_UPDATED,
        s_BX_PC_UPDATED,
        s_BLX_PC_UPDATED,
        s_BLX_Phase1,
        s_BLX_Phase2,
        s_SVC_PUSH_R0,
        s_SVC_PUSH_R1,
        s_SVC_PUSH_R2,
        s_SVC_PUSH_R3,
        s_SVC_PUSH_R12,
        s_SVC_PUSH_R14,
        s_SVC_PUSH_RETURN_ADDR,
        s_SVC_PUSH_xPSR,
        s_SVC_FETCH_NEW_PC,
        s_SVC_PC_UPDATED,
        s_INST32_DETECTED,
        s_MRS,
        s_MSR,
        s_ISB,
        s_DMB,
        s_DSB

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
        LDRSB, LDR_label, LDM,
        STR_imm5, STRH_imm5, STRB_imm5, STR, STRH,        STRB, 
               STR_SP_imm8, STM,
        PUSH, POP,
        BRANCH, BRANCH_imm11, BL2, BX, BLX,
        SXTH, SXTB, UXTH, UXTB,
        REV,  REV16, REVSH,
        SVC,
        BL, MSR, MRS, DSB, DMB, ISB,            -- 32-bit instructions  
        EVAL_32_INSTR,
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
        sel_SP_main_addr,
        sel_SP_main_addr_plus_4,
        sel_PC_plus_4,
        sel_BRANCH,
        sel_BRANCH_BL,
        sel_hardd_NC,
        sel_BX_Rm,
        sel_BLX_Rm,
        sel_SP_main_addr_SVC,
        sel_SVC_mem_content
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
        sel_gp_data_in_NC,
        sel_LR_DATA_BL,
        sel_LR_DATA_BLX,
        sel_special_reg,
        sel_Rn
    );
    
    type hrdata_ctrl_t is (
        sel_ALU_RESULT,
        sel_HRDATA_VALUE_SIZED,
        sel_LDM_DATA,
        sel_STM_total_bytes_wrote,
        sel_LDM_Rn,
        sel_SP_main_init,
        sel_PC_init,
        sel_SVC,
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
        REG_LR,
        REG_PC,
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
   
   type SDC_push_read_address_t is (
        SDC_read_R0,
        SDC_read_R1,
        SDC_read_R2,
        SDC_read_R3,
        SDC_read_R12,
        SDC_read_R14,
        SDC_read_retuen_addr,
        SDC_read_xPSR
   ); 
 
    type flag_t is record 
        N  : bit;                              -- Negative    
        Z  : bit;                              -- Zero 
        C  : bit;                              -- Carry
        V  : bit;                              -- Overflow
        EN : bit_vector (5 downto 0);          -- Exception Number.
        T  : bit;                              -- Thumb code is executed.
    end record;       
    
    subtype cond_t is std_logic_vector (3 downto 0);
    constant EQ : cond_t := B"0000"; 
    constant NE : cond_t := B"0001"; 
    constant CS : cond_t := B"0010"; 
    constant CC : cond_t := B"0011"; 
    constant MI : cond_t := B"0100"; 
    constant PL : cond_t := B"0101"; 
    constant VS : cond_t := B"0110"; 
    constant VC : cond_t := B"0111"; 
    constant HI : cond_t := B"1000"; 
    constant LS : cond_t := B"1001"; 
    constant GE : cond_t := B"1010"; 
    constant LT : cond_t := B"1011"; 
    constant GT : cond_t := B"1100"; 
    constant LE : cond_t := B"1101"; 
    constant AL : cond_t := B"1110"; 
    
    subtype mode_t is std_logic;
    constant mode_privileged    : mode_t := '0'; 
    constant mode_unprivileged  : mode_t := '1'; 
    
    subtype SP_mode_t is std_logic;
    constant SP_mode_main     : mode_t := '0'; 
    constant SP_mode_process  : mode_t := '1'; 
    
   subtype special_reg_t is std_logic_vector (7 downto 0);
   constant sp_reg_APSR    : special_reg_t := B"0000_0000";                       -- The flags from previous instructions.
   constant sp_reg_IAPSR   : special_reg_t := B"0000_0001";                       -- A composite of IPSR and APSR.
   constant sp_reg_EAPSR   : special_reg_t := B"0000_0010";                       -- A composite of EPSR and APSR.
   constant sp_reg_XPSR    : special_reg_t := B"0000_0011";                       -- A composite of all three PSR registers.
   constant sp_reg_IPSR    : special_reg_t := B"0000_0101";                       -- The Interrupt status register.
   constant sp_reg_EPSR    : special_reg_t := B"0000_0110";                       -- The execution status register.
   constant sp_reg_IEPSR   : special_reg_t := B"0000_0111";                       -- A composite of IPSR and EPSR.
   constant sp_reg_MSP     : special_reg_t := B"0000_1000";                       -- The Main Stack pointer.
   constant sp_reg_PSP     : special_reg_t := B"0000_1001";                       -- The Process Stack pointer.
   constant sp_reg_PRIMASK : special_reg_t := B"0001_0000";                       -- Register to mask out configurable exceptions.
   constant sp_reg_CONTROL : special_reg_t := B"0001_0100";                       -- The CONTROL register.

    
    -- Cortex-M0 functions
    function IsAligned (
        address : in std_logic_vector (31 downto 0);
        size : in integer) return boolean;
 
    function run_next_state_calc (
        any_access_mem  : boolean; 
        access_mem_mode : access_mem_mode_t;
        execution_cmd   : executor_cmds_t;
        PC_updated      : boolean; 
        imm8_value      : std_logic_vector (7 downto 0);
        LR_PC           : std_logic;
        cond_satisfied  : boolean
        ) return  core_state_t; 
        
        function inst32_next_state_calc (
        execution_cmd   : executor_cmds_t
        ) return  core_state_t; 
  
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
  
  
   function to_std_logic_vector (in_bit_vector: bit_vector) return std_logic_vector is 
    variable ret : std_logic_vector (in_bit_vector'RANGE);
        begin
            for i in in_bit_vector'RANGE loop
                ret(i) := to_std_logic(in_bit_vector(i));
            end loop;
            return ret;
        end;
   
   
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
        any_access_mem  : boolean; 
        access_mem_mode : access_mem_mode_t;
        execution_cmd   : executor_cmds_t;
        PC_updated      : boolean;
        imm8_value      : std_logic_vector (7 downto 0);
        LR_PC           : std_logic;
        cond_satisfied  : boolean
        ) return core_state_t is
        variable next_state : core_state_t;
      begin
            -- CHECK if instruction needs memory access
            if (any_access_mem = true) then 
                if (access_mem_mode = MEM_ACCESS_READ) then 
                    if (execution_cmd = LDM) then
                        next_state := s_DATA_MEM_ACCESS_LDM;
                    elsif (execution_cmd = POP) then
                         next_state := s_DATA_MEM_ACCESS_POP;
                    else
                        next_state := s_DATA_MEM_ACCESS_R;
                    end if;  
                elsif (access_mem_mode = MEM_ACCESS_WRITE) then
                    if (execution_cmd = STM) then
                        if (imm8_value(0) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R0;
                        elsif (imm8_value(1) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R1;
                        elsif (imm8_value(2) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R2;
                        elsif (imm8_value(3) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R3;
                        elsif (imm8_value(4) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R4;
                        elsif (imm8_value(5) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R5;                 
                        elsif (imm8_value(6) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                        elsif (imm8_value(7) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                        else
                            next_state := s_FINISH_STM;
                        end if;
                    elsif (execution_cmd = PUSH) then
                        if (LR_PC = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_LR; 
                        elsif (imm8_value(7) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R7;
                        elsif (imm8_value(6) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R6;
                        elsif (imm8_value(5) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R5;
                        elsif (imm8_value(4) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R4;
                        elsif (imm8_value(3) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R3;
                        elsif (imm8_value(2) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R2;
                        elsif (imm8_value(1) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R1;                     
                        elsif (imm8_value(0) = '1') then   
                            next_state := s_DATA_REG_ACCESS_EXECUTE_PUSH_R0;
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
                 --report "PC_updated = true, cond_satisfied= " &  boolean'image(cond_satisfied) & 
                   -- "execution_cmd= " & executor_cmds_t'image(execution_cmd) severity note;  
                if (execution_cmd = BRANCH) then    
                    if (cond_satisfied = true) then
                         next_state := s_BRANCH_PC_UPDATED;
                    else
                         next_state := s_RUN;
                    end if;
                elsif (execution_cmd = BRANCH_imm11) then  
                    next_state := s_BRANCH_UNCOND_PC_UPDATED;    
                elsif (execution_cmd = BX) then  
                    next_state := s_BX_PC_UPDATED;                
                elsif (execution_cmd = BLX) then  
                    next_state := s_BLX_PC_UPDATED;    
                elsif (execution_cmd = SVC) then  
                    next_state := s_SVC_PUSH_R0;                 
                else
                    next_state := s_PC_UPDATED;
                end if;  
            elsif (execution_cmd = EVAL_32_INSTR) then
                next_state := s_INST32_DETECTED;
            else    
                next_state := s_RUN;     
            end if;
        return  next_state; 
     end function;


     function inst32_next_state_calc (
        execution_cmd   : executor_cmds_t
        )  return core_state_t is
     variable next_state : core_state_t;
     begin
        if (execution_cmd = BL) then  
            next_state := s_BRANCH_BL_UNCOND_PC_UPDATED;
        elsif  (execution_cmd = MRS) then
            next_state := s_MRS; 
        elsif  (execution_cmd = MSR) then
            next_state := s_MSR; 
        elsif  (execution_cmd = ISB) then
            next_state := s_ISB;   
        elsif  (execution_cmd = DMB) then
            next_state := s_DMB;  
        elsif  (execution_cmd = DSB) then
            next_state := s_DSB;                         
        else    
            next_state := s_RUN;     
        end if;
        return  next_state; 
    end function;


end  helper_funcs;
