----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/28/2020 03:06:58 PM
-- Design Name: 
-- Module Name: executor - Behavioral
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

entity executor is
    Port (
         clk : in std_logic;
         reset : in std_logic;
         run : in std_logic;
         operand_A : in std_logic_vector(31 downto 0);	
         operand_B : in std_logic_vector(31 downto 0);	
         command: in executor_cmds_t;	
         imm8_z_ext : in  std_logic_vector(31 downto 0);
         destination_is_PC : in std_logic;
         state: in core_state_t;
         PC_updated: out std_logic;
         result : out std_logic_vector(31 downto 0);
         WE: out std_logic
     );
end executor;

architecture Behavioral of executor is

  component status_flags is
        Port (
            clk : in std_logic;
            reset : in std_logic;
            WE : in std_logic;                          -- Write Enable
            N  : in std_logic;                          -- Negative    
            Z  : in std_logic;                          -- Zero 
            C  : in std_logic;                          -- Carry
            V  : in std_logic;                          -- Overflow
            EN : in std_logic_vector (5 downto 0);      -- Exception Number.
            T  : in std_logic;                           -- Thumb code is executed.
            RN  : out std_logic;                          -- Read Negative    
            RZ  : out std_logic;                          -- Read Zero 
            RC  : out std_logic;                          -- Read Carry
            RV  : out std_logic;                          -- Read Overflow
            REN : out std_logic_vector (5 downto 0);      -- Read Exception Number.
            RT  : out std_logic                           -- Read Thumb code is executed.
        );
    end component;
    
      -- status flags signals
	signal  flag_reg_WE :  std_logic;	
	signal  set_N       :  std_logic;	
    signal  set_Z       :  std_logic;
    signal  set_C       :  std_logic;
    signal  set_V       :  std_logic;
    signal  set_EN      :  std_logic_vector (5 downto 0);
    signal  set_T       :  std_logic;
    signal  N_flag      :  std_logic;
    signal  Z_flag      :  std_logic;
    signal  C_flag      :  std_logic;
    signal  V_flag      :  std_logic;
    signal  EN_flag     :  std_logic_vector (5 downto 0);
    signal  T_flag      :  std_logic;
    
    
    -- signals 
    signal mux_ctrl     :  std_logic_vector (1 downto 0);
    signal alu_result :  std_logic_vector (31 downto 0);
    signal alu_temp : unsigned (32 downto 0) := (others => '0');
    signal temp_overflow : std_logic_vector (2 downto 0);
    signal result_final :  std_logic_vector (31 downto 0);
    signal WE_val : std_logic;
    signal pipeline_is_invalid : std_logic;
    signal update_PC : std_logic;
    signal current_instruction_mem_location :  std_logic_vector (31 downto 0);
    

begin

    c0_flags: status_flags port map (
            clk => clk,
            reset => reset,
            WE => flag_reg_WE,
            N  => set_N, 
            Z  => set_Z,
            C  => set_C,
            V  => set_V,
            EN => set_EN,
            T  => set_T,
            RN  => N_flag,  
            RZ  => Z_flag,
            RC  => C_flag,
            RV  => V_flag,
            REN => EN_flag,
            RT  => T_flag
        );
        
    PC_updated <= destination_is_PC;
        
    gp_data_in_p: process  (run, imm8_z_ext, mux_ctrl, operand_A, operand_B, alu_result) begin
        if (run = '1') then 
            case mux_ctrl is
                when B"00" =>   result_final <= imm8_z_ext;
                when B"10" =>   result_final <= operand_A;
                when B"01" =>   result_final <= operand_B;
                when B"11" =>   result_final <= alu_result;
                when others =>  result_final <= (others => '0');
            end case;
        else 
            result_final <= (others => '0');
        end if;    
    end process;
    
--     WE_p: process  (WE_val, pipeline_is_invalid) begin
--        if (pipeline_is_invalid = '1') then
--            WE <= '0';
--        else
--            WE <= WE_val;
--        end if;    
--    end process;

    WE_p: process  (WE_val, state) begin
        if (state = s_PC_UPDATED_INVALID or 
            state = s_EXEC_INSTA_INVALID or 
            state = s_EXEC_INSTB_INVALID or 
            state = s_PC_UNALIGNED) then
            WE <= '0';
        else
            WE <= WE_val;
        end if;    
    end process;
 
    execution_p: process  (command, result_final, alu_result, operand_A, operand_B, imm8_z_ext) begin
        case (command) is
            when MOVS_imm8 =>       -- MOVS Rd, #(imm8)                         
                WE_val <= '1'; 
                mux_ctrl <= B"00";    -- immediate value  
                set_N <= result_final(31);                          -- APSR.N = result<31>;
                if (to_integer(unsigned(result_final)) = 0) then    -- APSR.Z = IsZeroBit(result);
                    set_Z <= '1';
                else
                    set_Z <= '0';
                end if;    
                set_C <= '0';
                flag_reg_WE <= '1';
                update_PC <= '0';
            when MOVS =>            -- MOVS <Rd>,<Rm> 
                WE_val <= '1'; 
                mux_ctrl <= B"10";          -- A bus of register bank
                set_N <= result_final(31);                          -- APSR.N = result<31>;
                 if (to_integer(unsigned(result_final)) = 0) then    -- APSR.Z = IsZeroBit(result);
                    set_Z <= '1';
                else
                    set_Z <= '0';
                end if;  
                flag_reg_WE <= '1';
                update_PC <= '0';
            when MOV =>             -- MOV <Rd>,<Rm> , MOV PC, Rm
                WE_val <= '1'; 
                mux_ctrl <= B"10";          -- A bus of register bank
                if (destination_is_PC = '0') then        -- if destination_is_PC = 1 it means d == 15 (destination is PC) then setflags is always FALSE  
                    set_N <= result_final(31);                          -- APSR.N = result<31>;
                    if (to_integer(unsigned(result_final)) = 0) then    -- APSR.Z = IsZeroBit(result);
                        set_Z <= '1';
                    else
                        set_Z <= '0';
                    end if;    
                    flag_reg_WE <= '1';
                    update_PC <= '0';
                else
                    flag_reg_WE <= '0';
                    update_PC <= '1';
            end if;   
             when ADDS_imm3 =>     -- ADDS <Rd>,<Rn>,#<imm3>
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_N <= result_final(31);                          -- APSR.N = result<31>;
                if (to_integer(unsigned(result_final)) = 0) then    -- APSR.Z = IsZeroBit(result);
                    set_Z <= '1';
                else
                    set_Z <= '0';
                end if;    
                set_C <= std_logic(alu_temp(32));
                -- how to calculate overflow:
                -- There are two cases where the overflow flag would be turned on during a binary arithmetic operation:
                -- 1) The inputs both have sign bits that are off, while the result has a sign bit that is on.
                -- 2) The inputs both have sign bits that are on, while the result has a sign bit that is off.
                -- concat the three relevant sign-bits to one vector
                temp_overflow <= operand_A(31) & imm8_z_ext(31) & alu_result(31);
                if ((temp_overflow = B"001") or (temp_overflow = B"110")) then
                    set_V <= '1';
                else
                    set_V <= '0';
                end if;    
                flag_reg_WE <= '1';
                 update_PC <= '0';
            when ADDS =>     -- ADDS <Rd>,<Rn>,<Rm>
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_N <= result_final(31);                          -- APSR.N = result<31>;
                if (to_integer(unsigned(result_final)) = 0) then    -- APSR.Z = IsZeroBit(result);
                    set_Z <= '1';
                else
                    set_Z <= '0';
                end if;    
                set_C <= std_logic(alu_temp(32));
                -- how to calculate overflow:
                -- There are two cases where the overflow flag would be turned on during a binary arithmetic operation:
                -- 1) The inputs both have sign bits that are off, while the result has a sign bit that is on.
                -- 2) The inputs both have sign bits that are on, while the result has a sign bit that is off.
                -- concat the three relevant sign-bits to one vector
                temp_overflow <= operand_A(31) & operand_B(31) & alu_result(31);
                if ((temp_overflow = B"001") or (temp_overflow = B"110")) then
                    set_V <= '1';
                else
                    set_V <= '0';
                end if;    
                flag_reg_WE <= '1';                
                update_PC <= '0';
            when ADD =>     -- ADD <Rdn>,<Rm> - ADD PC,<Rm>
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                -- When command = ADD we know that destination_is_PC is 0.  
                set_N <= result_final(31);                          -- APSR.N = result<31>;
                if (to_integer(unsigned(result_final)) = 0) then    -- APSR.Z = IsZeroBit(result);
                    set_Z <= '1';
                else
                    set_Z <= '0';
                end if;    
                set_C <= std_logic(alu_temp(32));
                temp_overflow <= operand_A(31) & operand_B(31) & alu_result(31);
                if ((temp_overflow = B"001") or (temp_overflow = B"110")) then
                    set_V <= '1';
                else
                    set_V <= '0';
                end if;    
                -- it means d == 15 (destination is PC) then setflags is always FALSE  
                flag_reg_WE <= '1';
                update_PC <= '0';
            when ADD_PC =>    
                WE_val <= '0'; 
                mux_ctrl <= B"11";          -- alu_result
                flag_reg_WE <= '0';
                update_PC <= '1';
            when ADDS_imm8 =>     -- ADDS <Rdn>,#<imm8> 
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_N <= result_final(31);                          -- APSR.N = result<31>;
                if (to_integer(unsigned(result_final)) = 0) then    -- APSR.Z = IsZeroBit(result);
                    set_Z <= '1';
                else
                    set_Z <= '0';
                end if;    
                set_C <= std_logic(alu_temp(32));
                temp_overflow <= operand_A(31) & imm8_z_ext(31) & alu_result(31);
                if ((temp_overflow = B"001") or (temp_overflow = B"110")) then
                    set_V <= '1';
                else
                    set_V <= '0';
                end if;    
                flag_reg_WE <= '1';                
                 update_PC <= '0';
            when ADCS =>                                           -- ADCS <Rdn>,<Rm>
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_N <= result_final(31);                          -- APSR.N = result<31>;
                if (to_integer(unsigned(result_final)) = 0) then    -- APSR.Z = IsZeroBit(result);
                    set_Z <= '1';
                else
                    set_Z <= '0';
                end if;    
                set_C <= std_logic(alu_temp(32));
                temp_overflow <= operand_A(31) & operand_B(31) & alu_result(31);
                if ((temp_overflow = B"001") or (temp_overflow = B"110")) then
                    set_V <= '1';
                else
                    set_V <= '0';
                end if;    
                flag_reg_WE <= '1';                
                 update_PC <= '0';
          
                
                
             when NOT_DEF =>
                WE_val <= '0'; 
                mux_ctrl <= B"00";
                flag_reg_WE <= '0';
                set_N       <= '0';
                set_Z       <= '0';
                set_C       <= '0';
                set_V       <= '0';
                set_EN      <= (others => '0');
                set_T       <= '0';
                temp_overflow <= (others => '0');
                update_PC <= '0';
           when others  => 
                WE_val <= '0'; 
                mux_ctrl <= B"00";
                flag_reg_WE <= '0';
                set_N       <= '0';
                set_Z       <= '0';
                set_C       <= '0';
                set_V       <= '0';
                set_EN      <= (others => '0');
                set_T       <= '0';       
                temp_overflow <= (others => '0');        
                update_PC <= '0';
       end case;  
     end process;
     
    alu_p: process  (command, state, operand_A, operand_B, current_instruction_mem_location, imm8_z_ext, C_flag) begin
        case (command) is
            when ADDS_imm3 =>       -- ADDS <Rd>,<Rn>,#<imm3>
                alu_temp <= unsigned ('0' & operand_A) + unsigned('0' & imm8_z_ext);    -- AddWithCarry(R[n], imm32, '0');
            when ADDS =>            -- ADDS <Rd>,<Rn>,<Rm>
                alu_temp <= unsigned ('0' & operand_A) + unsigned('0' & operand_B);     -- AddWithCarry(R[n], shifted, '0');
            when ADD =>             -- ADD <Rdn>,<Rm>
                alu_temp <= unsigned ('0' & operand_A) + unsigned('0' & operand_B);     -- AAddWithCarry(R[n], shifted, '0');
            when ADD_PC =>             -- ADD PC, <Rm>
                alu_temp <= (unsigned ('0' & current_instruction_mem_location) + unsigned('0' & operand_B) + 2)
                    and B"1_1111_1111_1111_1111_1111_1111_1111_1110";     -- AAddWithCarry(R[n], shifted, '0');
            when ADDS_imm8 =>       -- ADDS <Rdn>,#<imm8>
                alu_temp <= unsigned ('0' & operand_A) + unsigned('0' & imm8_z_ext);    -- AddWithCarry(R[n], imm32, '0');                
            when ADCS =>            -- ADCS <Rdn>,<Rm>
                alu_temp <= ((unsigned ('0' & operand_A) + unsigned('0' & operand_B)) + C_flag) ;     --AddWithCarry(R[n], shifted, APSR.C);                
            when others  =>
                alu_temp <= (others => '0');
        end case;       
     end process;

     alu_result <= std_logic_vector(alu_temp(31 downto 0));
     result <= result_final;
     
    -- If core is at state s_EXEC_INSTA then the current memory address of the currect instruction is PC.
    --  but if the core is at state s_EXEC_INSTB then current memory address of the currect instruction is PC - 2
    -- The to PC instrution adds to current memory location which must be calculates based on the observations stated above.
    current_instruction_mem_location_p: process (state, operand_A) begin
        if (state = s_EXEC_INSTA) then
            current_instruction_mem_location <= operand_A;    -- OperanA will carry the PC if update_PC signal is activated
        else
            current_instruction_mem_location <= STD_LOGIC_VECTOR (unsigned (operand_A) + 2);
        end if;
    end process;
    
    
 


end Behavioral;
