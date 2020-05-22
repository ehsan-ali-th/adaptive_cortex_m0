----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/05/2020 05:03:27 PM
-- Design Name: 
-- Module Name: core_state - Behavioral
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

entity core_state is
    Port (
        clk : in std_logic;
        reset : in std_logic;
        instruction_size : in boolean;      -- false = 16-bit (2 bytes), true = 32-bit (4 bytes) 
        access_mem : in boolean;
        PC_updated : in boolean;
        imm8 : in std_logic_vector (7 downto 0);
        LM : in std_logic;
        number_of_ones_initial : in  STD_LOGIC_VECTOR (3 downto 0);
        execution_cmd : in executor_cmds_t;
        LDM_STM_access_mem : in boolean;
        new_PC : in std_logic_vector (31 downto 0);
        access_mem_mode : in access_mem_mode_t;
        SP_main_init : in std_logic_vector (31 downto 0);
        PC_init : in std_logic_vector (31 downto 0);
        PC : out std_logic_vector (31 downto 0);
        SP_main : out std_logic_vector (31 downto 0);
        PC_decode : out std_logic_vector (31 downto 0);
        PC_execute :  out std_logic_vector (31 downto 0);
        PC_after_execute :  out std_logic_vector (31 downto 0);
        LDM_STM_mem_address_index :  out unsigned (4 downto 0);             -- Because max no. of LDM registers is 7 so the range: 7 * 4 => 28 
        gp_data_in_ctrl : out gp_data_in_ctrl_t;
        hrdata_ctrl : out hrdata_ctrl_t;
        disable_fetch : out boolean;
        haddr_ctrl : out haddr_ctrl_t;                      -- true  = put data memory address on the bus, 
                                                            -- false = put program memory address on the bus
        disable_executor : out boolean;
        gp_addrA_executor_ctrl : out boolean;
        LDM_W_STM_R_reg : out std_logic_vector (3 downto 0);
        LDM_STM_capture_base : out boolean;
        HWRITE : out std_logic;
        VT_ctrl : out VT_ctrl_t
    );
end core_state;
    
architecture Behavioral of core_state is
    signal m0_core_state :  core_state_t;
    signal m0_core_next_state :  core_state_t;
    signal size_of_executed_instruction : unsigned (31 downto 0);
    signal PC_value :  unsigned(31 downto 0);
    signal SP_main_value :  std_logic_vector(31 downto 0);
	signal refetch_i : boolean;
    signal LDM_counter : unsigned (3 downto 0);          -- Starts with the total number of target registers 
--    signal STM_counter : unsigned (3 downto 0);          -- Starts with the total number of target registers 
    signal LDM_counter_value : unsigned (3 downto 0);      
    signal STM_counter_value : unsigned (3 downto 0);      
    signal LDM_read_counter : unsigned (4 downto 0);    -- Starts with 0 and counts uo to the max no. of target registers
    signal STM_write_counter : unsigned (4 downto 0);   
    signal STM_counter_diff : unsigned (4 downto 0);
    signal LDM_cur_target_reg : low_register_t;
    signal any_access_mem : boolean;
begin

    any_access_mem <= access_mem or LDM_STM_access_mem;


    LDM_STM_mem_address_index_p: process (LDM_read_counter, execution_cmd) begin
        if (execution_cmd = LDM) then
            LDM_STM_mem_address_index <=  shift_left (LDM_read_counter, 2);    --    LDM_read_counter * 4
        elsif (execution_cmd = STM) then       
            LDM_STM_mem_address_index <=  shift_left (STM_write_counter, 2);   --    STM_write_counter * 4
        else
            LDM_STM_mem_address_index <= B"00000";
        end if;                
    end process;
    
    -- STM_write_counter is an up counter starts from -1 , we use this signal to mark the two cycle before the end 
    --  of STM instruction so we can fetch and decode the next instruction in right time.
    STM_counter_diff <= unsigned('0' & number_of_ones_initial) - STM_write_counter;
    
    PC_p: process (clk, reset) begin
        if (reset = '1') then
            PC <= x"0000_0000";
            SP_main <= x"0000_0000";
            PC_decode <= x"0000_0000";
            PC_execute  <= x"0000_0000"; 
            PC_after_execute  <= x"0000_0000"; 
        else    
            if (rising_edge(clk)) then
                SP_main <= SP_main_value;
                if (refetch_i = false) then 
                    if (gp_addrA_executor_ctrl = false) then
                        PC <= std_logic_vector(PC_value);           -- normal
                    else
                        PC <= new_PC;
                    end if;    
                    PC_decode <= PC;
                    PC_execute <= PC_decode;
                    PC_after_execute <= PC_execute;
                end if;
            end if;    
        end if;
    end process;
    
    PC_value_p : process (size_of_executed_instruction, PC, m0_core_state, refetch_i, PC_init) begin
        if (m0_core_state = s_SET_PC) then
            PC_value <= unsigned (PC_init (31 downto 1) & '0');
        else  
             if (refetch_i = false) then 
                    PC_value <= size_of_executed_instruction + unsigned (PC);
            end if;      
            
        end if; 
    end process;
    
    SP_main_value_p : process (m0_core_state, SP_main_init) begin
        if (m0_core_state = s_RESET) then
            SP_main_value <= x"0000_0000";
        else  
             if (m0_core_state = s_SET_SP) then 
                    SP_main_value <= SP_main_init;
            end if;      
        end if; 
    end process;

    state_p: process (clk) begin
        if (reset = '1') then
             m0_core_state <= s_RESET;
             LDM_counter <= (others => '0');
--             STM_counter <= (others => '0');
        else
            if (rising_edge(clk)) then
                  m0_core_state <= m0_core_next_state;
                  LDM_counter <= LDM_counter_value;
--                 STM_counter <= STM_counter_value;
            end if;                       
        end if;
    end process;
    
    
    LDM_read_counter_p: process (clk) begin
         if (reset = '1') then
            LDM_read_counter <= (others => '0');
            STM_write_counter  <= (others => '0');
         else
            if (rising_edge(clk)) then             
                if (m0_core_next_state = s_RUN or m0_core_next_state = s_DATA_MEM_ACCESS_LDM) then
                    LDM_read_counter <= (others => '0');  
                elsif (any_access_mem = true) then
                    LDM_read_counter <= LDM_read_counter + 1;        
                end if;
            end if;    

            if (rising_edge(clk)) then             
                if (m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R0 or 
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R1 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R2 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R3 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R4 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R5 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R6 or 
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R7 or
                    m0_core_next_state = s_FINISH_STM) then
                    STM_write_counter <= STM_write_counter + 1;
                else
                    STM_write_counter <= B"11111";  
                end if;
            end if;    
            
            
         end if;      
    end process;
    
    size_of_executed_instruction_p: process (instruction_size) begin
        -- false = 16-bit (2 bytes), true = 32-bit (4 bytes) 
        if (instruction_size = true) then
            size_of_executed_instruction <= x"0000_0004";
        else
            size_of_executed_instruction <= x"0000_0002";
        end if;
    end process;
    
    LDM_counter_value_p: process (m0_core_state, number_of_ones_initial, LDM_counter) begin
        if (m0_core_state = s_RUN) then
            LDM_counter_value <= "0000";
        elsif (m0_core_state = s_DATA_MEM_ACCESS_LDM) then  
            LDM_counter_value <= unsigned(number_of_ones_initial);
        else    
            LDM_counter_value <=  unsigned(LDM_counter) - 1;  
        end if;    
    end process;
    
    STM_counter_value_p: process (m0_core_state, number_of_ones_initial, LDM_counter) begin
        if (m0_core_state = s_RUN) then
            stM_counter_value <= "0000";
        elsif (m0_core_state = s_DATA_MEM_ACCESS_LDM) then  
            LDM_counter_value <= unsigned(number_of_ones_initial);
        else    
            LDM_counter_value <=  unsigned(LDM_counter) - 1;  
        end if;    
    end process;
    
    LDM_W_STM_R_reg_p: process (LDM_cur_target_reg) begin
        case (LDM_cur_target_reg) is
            when REG_R0 => LDM_W_STM_R_reg <= "0000";
            when REG_R1 => LDM_W_STM_R_reg <= "0001";
            when REG_R2 => LDM_W_STM_R_reg <= "0010";
            when REG_R3 => LDM_W_STM_R_reg <= "0011";
            when REG_R4 => LDM_W_STM_R_reg <= "0100";
            when REG_R5 => LDM_W_STM_R_reg <= "0101";
            when REG_R6 => LDM_W_STM_R_reg <= "0110";
            when REG_R7 => LDM_W_STM_R_reg <= "0111";
            when others => LDM_W_STM_R_reg <= "0000";
        end case;   
    end process;
     
    next_state_p: process ( m0_core_state, reset, any_access_mem, PC_updated, execution_cmd, 
                            LDM_counter, access_mem_mode, imm8) begin
        if (reset = '1') then
             m0_core_next_state <= s_RESET;
        else     
            case (m0_core_state) is
                when s_RESET                => m0_core_next_state <= s_SET_SP;
                when s_SET_SP               => m0_core_next_state <= s_FETCH_PC;
                when s_FETCH_PC             => m0_core_next_state <= s_SET_PC;
                when s_SET_PC               => m0_core_next_state <= s_PRE1_RUN;
                when s_PRE1_RUN             => m0_core_next_state <= s_PRE2_RUN;
                when s_PRE2_RUN             => m0_core_next_state <= s_RUN;
                when s_RUN                  => m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                when s_DATA_MEM_ACCESS_R    => m0_core_next_state <= s_EXECUTE_DATA_MEM_R; 
                when s_EXECUTE_DATA_MEM_R   => m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                when s_DATA_MEM_ACCESS_W    => m0_core_next_state <= s_EXECUTE_DATA_MEM_W; 
                when s_EXECUTE_DATA_MEM_W   => m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                when s_PC_UPDATED           => m0_core_next_state <= s_PIPELINE_FLUSH1;
                when s_PIPELINE_FLUSH1      => m0_core_next_state <= s_PIPELINE_FLUSH2;
                when s_PIPELINE_FLUSH2      => m0_core_next_state <= s_PIPELINE_FLUSH3;
                when s_PIPELINE_FLUSH3      => m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                when s_DATA_MEM_ACCESS_LDM  =>
                    if    (imm8(0) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R0;
                    elsif (imm8(1) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R1;
                    elsif (imm8(2) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R2;
                    elsif (imm8(3) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R3;
                    elsif (imm8(4) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R4;
                    elsif (imm8(5) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R5;
                    elsif (imm8(6) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                    elsif (imm8(7) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                    else
                        m0_core_next_state <= s_RUN;  
                    end if;  
                when s_DATA_MEM_ACCESS_EXECUTE_LDM_R0 =>  
                    -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                    else
                        if (imm8(1) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R1;
                        elsif (imm8(2) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R2;
                        elsif (imm8(3) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R3;
                        elsif (imm8(4) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R4;
                        elsif (imm8(5) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R5;
                        elsif (imm8(6) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                        elsif (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                        end if;  
                    end if;                       
               when s_DATA_MEM_ACCESS_EXECUTE_LDM_R1 =>  
                    -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                    else
                        if (imm8(2) = '1') then   
                            m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R2;
                        elsif (imm8(3) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R3;
                        elsif (imm8(4) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R4;
                        elsif (imm8(5) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R5;
                        elsif (imm8(6) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                        elsif (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                        end if;  
                    end if;    
               when s_DATA_MEM_ACCESS_EXECUTE_LDM_R2 =>  
                    -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                    else
                        if (imm8(3) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R3;
                        elsif (imm8(4) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R4;
                        elsif (imm8(5) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R5;
                        elsif (imm8(6) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                        elsif (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);   
                        end if;  
                    end if;    
                when s_DATA_MEM_ACCESS_EXECUTE_LDM_R3 =>  
                    -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                    else
                        if (imm8(4) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R4;
                        elsif (imm8(5) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R5;
                        elsif (imm8(6) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                        elsif (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);    
                        end if;  
                    end if;   
                when s_DATA_MEM_ACCESS_EXECUTE_LDM_R4 =>  
                -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                    else
                        if (imm8(5) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R5;
                        elsif (imm8(6) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                        elsif (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM); 
                        end if;  
                    end if;
                when s_DATA_MEM_ACCESS_EXECUTE_LDM_R5 =>  
                    -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                    else
                        if (imm8(6) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                        elsif (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);   
                        end if;  
                    end if; 
                when s_DATA_MEM_ACCESS_EXECUTE_LDM_R6 =>  
                    -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                    else
                        if (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);       
                        end if;  
                    end if; 
                when s_DATA_MEM_ACCESS_EXECUTE_LDM_R7 =>  
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                when s_FINISH_STM =>
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                when s_DATA_REG_ACCESS_EXECUTE_STM_R0 =>  
                    if (imm8(1) = '1') then   
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R1;
                    elsif (imm8(2) = '1') then   
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R2;
                    elsif (imm8(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R3;
                    elsif (imm8(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R4;
                    elsif (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R1 =>  
                    if (imm8(2) = '1') then   
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R2;
                    elsif (imm8(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R3;
                    elsif (imm8(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R4;
                    elsif (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;
                    end if;  
           when s_DATA_REG_ACCESS_EXECUTE_STM_R2 =>  
                    if (imm8(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R3;
                    elsif (imm8(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R4;
                    elsif (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;    
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R3 =>  
                    if (imm8(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R4;
                    elsif (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R4 =>  
                    if (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;    
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R5 =>  
                    if (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;     
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R6 =>  
                    if (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R7 =>  
                m0_core_next_state <= s_FINISH_STM;
                when s_FINISH_PUSH =>
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd, PC_updated, imm8, LM);
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_R0 =>  
                    if (imm8(1) = '1') then   
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R1;
                    elsif (imm8(2) = '1') then   
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R2;
                    elsif (imm8(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R3;
                    elsif (imm8(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R4;
                    elsif (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R7;
                    elsif (LM = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_LM;     
                    else
                         m0_core_next_state <= s_FINISH_PUSH;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_R1 =>  
                    if (imm8(2) = '1') then   
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R2;
                    elsif (imm8(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R3;
                    elsif (imm8(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R4;
                    elsif (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R7;
                    elsif (LM = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_LM;     
                    else
                         m0_core_next_state <= s_FINISH_PUSH;
                    end if;  
           when s_DATA_REG_ACCESS_EXECUTE_PUSH_R2 =>  
                    if (imm8(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R3;
                    elsif (imm8(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R4;
                    elsif (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R7;
                    elsif (LM = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_LM;     
                    else
                         m0_core_next_state <= s_FINISH_PUSH;    
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_R3 =>  
                    if (imm8(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R4;
                    elsif (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R7;
                    elsif (LM = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_LM;     
                    else
                         m0_core_next_state <= s_FINISH_PUSH;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_R4 =>  
                    if (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R7;
                    elsif (LM = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_LM;     
                    else
                         m0_core_next_state <= s_FINISH_PUSH;    
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_R5 =>  
                    if (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R7;
                    elsif (LM = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_LM;     
                    else
                         m0_core_next_state <= s_FINISH_PUSH;     
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_R6 =>  
                    if (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R7;
                    elsif (LM = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_LM;
                    else    
                         m0_core_next_state <= s_FINISH_PUSH;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_R7 =>  
                     if (LM = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_LM;
                    else
                         m0_core_next_state <= s_FINISH_PUSH;
                    end if; 
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_LM =>    
                     m0_core_next_state <= s_FINISH_PUSH;

                                                                                                                                       
               when others => m0_core_next_state <= s_RESET;
            end case;
        end if;            
    end process;

    output_p: process ( m0_core_state, access_mem, PC(1), PC_execute(1), LDM_counter, LDM_counter_value, STM_counter_diff,
                        STM_write_counter, imm8, any_access_mem) begin
        case (m0_core_state) is
            when s_RESET => 
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_SP_main_init; 
                hrdata_ctrl <= sel_SP_main_init; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_SET_SP => 
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_SP_main_init; 
                hrdata_ctrl <= sel_SP_main_init; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_VECTOR_TABLE; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0';     
                VT_ctrl <= VT_SP_main;
            when s_FETCH_PC => 
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_VECTOR_TABLE; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0';     
                VT_ctrl <= VT_RESET;
            when s_SET_PC => 
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_PC_init; 
                hrdata_ctrl <=  sel_PC_init; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_VECTOR_TABLE; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0';     
                VT_ctrl <= VT_RESET;
            when s_PRE1_RUN =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                LDM_cur_target_reg <= REG_NONE;
                disable_fetch <= false;
                gp_addrA_executor_ctrl <= false; 
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_PRE2_RUN =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                LDM_cur_target_reg <= REG_NONE;   
                disable_fetch <= false;
                gp_addrA_executor_ctrl <= false; 
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_RUN =>  
                refetch_i <= any_access_mem; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_executor <= false; 
                haddr_ctrl <= sel_PC;
                disable_fetch <= any_access_mem;
                LDM_cur_target_reg <= REG_NONE;
                gp_addrA_executor_ctrl <= false; 
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
             when s_DATA_MEM_ACCESS_R =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                if (PC_execute(1) = '1') then
                    hrdata_ctrl <= sel_NC;          -- Do not update hrdata_program_value
                else
                    hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value
                end if;
                disable_executor <= true; 
                if (PC(1) = '1') then
                    disable_fetch <= false;
                else
                    disable_fetch <= any_access_mem;
                end if;
                haddr_ctrl <= sel_DATA;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_EXECUTE_DATA_MEM_R =>  
                refetch_i <= any_access_mem; 
                gp_data_in_ctrl <= sel_HRDATA_VALUE_SIZED; 
                hrdata_ctrl <= sel_HRDATA_VALUE_SIZED; 
                disable_executor <= false; 
                haddr_ctrl <= sel_PC;
                disable_fetch <= any_access_mem;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
             when s_DATA_MEM_ACCESS_W =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_executor <= true; 
                haddr_ctrl <= sel_WDATA;
                if (PC(1) = '1') then
                    disable_fetch <= false;
                else
                    disable_fetch <= any_access_mem;
                end if;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_EXECUTE_DATA_MEM_W =>  
                refetch_i <= any_access_mem; 
                gp_data_in_ctrl <= sel_HRDATA_VALUE_SIZED; 
                hrdata_ctrl <=  sel_HRDATA_VALUE_SIZED; 
                disable_executor <= false; 
                haddr_ctrl <= sel_PC;
                disable_fetch <= any_access_mem;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_PC_UPDATED =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_fetch <= false;
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= true; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_PIPELINE_FLUSH1 =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_fetch <= false; 
                disable_executor <= true;
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= false;
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_PIPELINE_FLUSH2 =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_PIPELINE_FLUSH3 =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_MEM_ACCESS_LDM =>
                LDM_STM_capture_base <= true; 
                if (LDM_counter_value = 1) then
                    -- it means the STM instruction has only 1 register in its register_list
                    -- therefor we have to finish the STM in next cycle.
                    refetch_i <= false;
                    disable_fetch <= any_access_mem; 
                else
                    refetch_i <= true;
                    disable_fetch <= true;
                end if;
                if (PC(1) = '1') then
                        hrdata_ctrl <= sel_NC;          -- Do not update hrdata_program_value
                else
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value
                end if;
                gp_data_in_ctrl <= sel_LDM_Rn; 
                haddr_ctrl <= sel_LDM;
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R0 =>  
                LDM_cur_target_reg <= REG_R0;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_PC;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R1 =>  
                LDM_cur_target_reg <= REG_R1;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_PC;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R2 =>  
                LDM_cur_target_reg <= REG_R2;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_PC;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <=  sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R3 =>            
                LDM_cur_target_reg <= REG_R3;  
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_PC;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R4 =>  
                LDM_cur_target_reg <= REG_R4;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_PC;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R5 =>  
                LDM_cur_target_reg <= REG_R5;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_PC;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R6 =>  
                LDM_cur_target_reg <= REG_R6;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_LDM;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R7 =>  
                LDM_cur_target_reg <= REG_R7;  
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_LDM;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_FINISH_STM =>
                -- In this state we need to write the total number of bytes written into memory to register bank
                LDM_STM_capture_base <= false; 
                --  we have to finish the STM in next cycle.
                refetch_i <= any_access_mem; 
                disable_fetch <= any_access_mem;
                if (PC(1) = '1') then
                    hrdata_ctrl <= sel_NC; 
                   else
                    hrdata_ctrl <= sel_LDM_Rn;
                end if;
                gp_data_in_ctrl <= sel_STM_total_bytes_wrote; 
                haddr_ctrl <= sel_PC;                           -- Not used
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_STM_R0 =>  
               LDM_cur_target_reg <= REG_R0;
               LDM_STM_capture_base <= true;
               if (STM_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
               else
                    refetch_i <= true; 
                    disable_fetch <= true; 
               end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_STM_R1 =>  
                LDM_cur_target_reg <= REG_R1;
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_STM_R2 =>  
                LDM_cur_target_reg <= REG_R2;
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_STM_R3 =>            
                LDM_cur_target_reg <= REG_R3;
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_STM_R4 =>  
                LDM_cur_target_reg <= REG_R4;
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_STM_R5 =>  
                LDM_cur_target_reg <= REG_R5;
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_STM_R6 =>  
                LDM_cur_target_reg <= REG_R6;
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_STM_R7 =>  
                LDM_cur_target_reg <= REG_R7;
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_FINISH_PUSH =>
                -- In this state we need to write the total number of bytes written into memory to register bank
                LDM_STM_capture_base <= false; 
                --  we have to finish the STM in next cycle.
                refetch_i <= any_access_mem; 
                disable_fetch <= any_access_mem;
                if (PC(1) = '1') then
                    hrdata_ctrl <= sel_NC; 
                   else
                    hrdata_ctrl <= sel_LDM_Rn;
                end if;
                gp_data_in_ctrl <= sel_STM_total_bytes_wrote; 
                haddr_ctrl <= sel_PC;                           -- Not used
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R0 =>  
               LDM_cur_target_reg <= REG_R0;   
               LDM_STM_capture_base <= true;
               if (STM_counter_diff = 1) then         -- two states before the end of PUSH
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
               else
                    refetch_i <= true; 
                    disable_fetch <= true; 
               end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R1 =>  
                LDM_cur_target_reg <= REG_R1;   
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of PUSH 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R2 =>  
                LDM_cur_target_reg <= REG_R2;   
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of PUSH 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R3 =>            
                LDM_cur_target_reg <= REG_R3;  
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of PUSH
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R4 =>  
                LDM_cur_target_reg <= REG_R4;   
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R5 =>  
                LDM_cur_target_reg <= REG_R5;   
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of PUSH
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R6 =>  
                LDM_cur_target_reg <= REG_R6;   
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of PUSH
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R7 =>  
                LDM_cur_target_reg <= REG_R7;  
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of PUSH
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_LM =>  
                LDM_cur_target_reg <= REG_LM;  
                LDM_STM_capture_base <= true; 
                if (STM_counter_diff = 1) then         -- two states before the end of PUSH
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter = 0 and PC_execute(1) = '0') then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_Rn;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;


            when others => 
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                hrdata_ctrl <= sel_NC; 
                disable_fetch <= false; 
                disable_executor <= false; 
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= false;
                LDM_STM_capture_base <= false; 
                LDM_cur_target_reg <= REG_NONE;
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
        end case;
    end process;       
 end Behavioral;
