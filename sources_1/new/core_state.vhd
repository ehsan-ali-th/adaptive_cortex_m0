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
        HADDR : out std_logic_vector(31 downto 0);
        PC : out std_logic_vector(31 downto 0);
        execute_mem_rw : out boolean;
        disable_fetch : out boolean;
        haddr_ctrl : out boolean;            -- true  = put data memory address on the bus, 
                                            -- false = put program memory address on the bus
        disable_executor : out boolean                                   

        --PC_upda ted : in std_logic;
        --access_mem : in boolean;
        --PC_2bit_LSB : in std_logic_vector(1 downto 0);
       -- use_PC_value: in boolean;
        --instr_ptr: out std_logic;
        --state : out core_state_t;
        --next_state : out core_state_t;
        --m0_previous_state : out core_state_t
    );
end core_state;

architecture Behavioral of core_state is

--    component pipeline_stall_gen is
--        Port (
--            clk : in std_logic;
--            reset : in std_logic;
--            trigger : in boolean;
--            pulse : out boolean
--         );
--    end component;

    signal m0_core_state :  core_state_t;
    signal m0_core_next_state :  core_state_t;
    signal size_of_executed_instruction : unsigned (31 downto 0);
    signal PC_value :  unsigned(31 downto 0);
    signal HADDR_enable : boolean;
	signal refetch : boolean;
	
            
begin

--    m0_pipeline_stall_gen: pipeline_stall_gen port map (
--        clk => clk,
--        reset => reset,
--        trigger => access_mem,
--        pulse => refetch
--    );

    --HADDR <= std_logic_vector(HADDR_value);
   -- access_data_section <= invalidate_pipeline;
  
    
    PC_p: process (clk, reset, m0_core_state, refetch) begin
        if (reset = '1') then
            PC <= x"0000_0000";
            --HADDR <= x"0000_0000";
        else    
            if (rising_edge(clk)) then
                if (refetch = false) then 
                    PC <= std_logic_vector(PC_value);
                end if;
            end if;    
        end if;
    end process;
    
    PC_value_p : process (size_of_executed_instruction, PC, m0_core_state, refetch) begin
        if (m0_core_state = s_RESET) then
            PC_value <= x"0000_0000";
        else  
             if (refetch = false) then 
                    PC_value <= size_of_executed_instruction + unsigned(PC);
            end if;      
            
        end if; 
    end process;

    HRDATA_valuep : process (PC_value, m0_core_state, HADDR_enable) begin
        if (m0_core_state = s_RESET) then
            HADDR <= x"0000_0000";
        else 
            HADDR <= std_logic_vector((unsigned (PC_value ) + 2) and x"FFFF_FFFC");
        end if;
    end process;
    
    state_p: process (clk) begin
        if (reset = '1') then
             m0_core_state <= s_RESET;
        else
            if (rising_edge(clk)) then
                  m0_core_state <= m0_core_next_state;
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
     
--     HADDR_enable <= true;
     
      -- and (m0_core_state = s_RUN or m0_core_state = s_EXECUTE_DATA_MEM_RW)) s_DATA_MEM_ACCESS
--     HADDR_enable_p: process (PC(1), m0_core_state) begin
--        if (m0_core_state = s_RUN or m0_core_state = s_DATA_MEM_ACCESS)  then
--            HADDR_enable <= true;
--        else
--            HADDR_enable <= false;
--        end if;
--     end process;

    next_state_p: process (m0_core_state, reset, access_mem) begin
        if (reset = '1') then
             m0_core_next_state <= s_RESET;
        else     
            case (m0_core_state) is
                when s_RESET => m0_core_next_state <=s_RUN;  
                --when s_START_DELAY_CYCLE => m0_core_next_state <= s_RUN;  
                when s_RUN =>  
                    if (access_mem = true) then 
                        m0_core_next_state <= s_DATA_MEM_ACCESS;
                    else    
                        m0_core_next_state <= s_RUN;     
                    end if;    
                when s_DATA_MEM_ACCESS => m0_core_next_state <= s_EXECUTE_DATA_MEM_RW; 
                when s_EXECUTE_DATA_MEM_RW =>
                if (access_mem = true) then 
                        m0_core_next_state <= s_DATA_MEM_ACCESS;
                    else    
                        m0_core_next_state <= s_RUN;     
                    end if;  
--                when s_EXEC_INSTA_START =>  
--                     if (PC_updated = '0') then
--                         if (use_PC_value = true) then  
--                            m0_core_next_state <= s_INSTB_MEM_ACCESS;
--                         else
--                             core_inst_ptr <= core_inst_ptr + 1;
--                            m0_core_next_state <= s_EXEC_INSTB;
--                         end if;  
--                            if (mem_access = true) then 
--                            m0_core_state_after_mem_access <= s_EXEC_INSTB; 
--                            m0_core_next_state <= s_MEM_ACCESS; 
--                        else
--                            m0_core_next_state <= s_EXEC_INSTB;
--                        end if;
--                    else 
--                        m0_core_next_state <= s_PC_UPDATED_INVALID;
--    end if;   
--                when s_EXEC_INSTA => 
--                    if (PC_updated = '0') then
--                        if (access_mem = true) then  
--                            m0_core_next_state <= s_REFETCH_INSTA; -- refetch INSTA 
--                        else
--                            m0_core_next_state <= s_EXEC_INSTB;
--                        end if; 
--                    else 
--                        m0_core_next_state <= s_PC_UPDATED_INVALID;
--                    end if;    
--                when s_EXEC_INSTB => 
--                    if (PC_updated = '0') then
--                        if (access_mem = true) then  
--                            m0_core_next_state <= s_REFETCH_INSTB; -- refetch INSTB 
--                        else
--                            m0_core_next_state <= s_EXEC_INSTA;
--                        end if; 
--                    else 
--                        m0_core_next_state <= s_PC_UPDATED_INVALID;
--                    end if;  
--                when s_PC_UPDATED_INVALID => m0_core_next_state <= s_EXEC_INSTB_INVALID;
--                when s_EXEC_INSTA_INVALID => 
--                     PC can only be unaligned if the user loads a value into the PC.
--                     The following instructions update the PC:
                     
--                     MOV PC, Rm
--                     ADD PC,<Rm>
                    
--                     In those case the pipeline gets invalidated and then it jumps to new PC to fetch data.
--                     Always the last invalid state is s_EXEC_INSTA_INVALID. So if the PC is unaligned we 
--                     just need to extend the pipeline invalid state one more cycle.
--                    if (PC_2bit_LSB = B"00") then
--                        m0_core_next_state <= s_EXEC_INSTB;
--                    else
--                        m0_core_next_state <= s_PC_UNALIGNED;
--                    end if;
--                when s_EXEC_INSTB_INVALID => m0_core_next_state <= s_EXEC_INSTA_INVALID;
--                when s_PC_UNALIGNED => m0_core_next_state <= s_EXEC_INSTA;
--                when s_REFETCH_INSTB => m0_core_next_state <= s_EXEC_INSTA;
--                when s_REFETCH_INSTA => m0_core_next_state <= s_EXEC_INSTB;
--                when s_INSTA_MEM_ACCESS => m0_core_next_state <= s_INSTB_AFTER_MEM_ACCESS;
--                when s_INSTB_MEM_ACCESS => m0_core_next_state <= s_INSTA_AFTER_MEM_ACCESS;
--                when s_INSTA_AFTER_MEM_ACCESS => 
--                     if (PC_updated = '0') then
--                        core_inst_ptr <= core_inst_ptr + 1;
--                        if (use_PC_value = true) then  
--                             m0_core_next_state <= s_INSTA_MEM_ACCESS;
--                        else
--                             m0_core_next_state <= s_EXEC_INSTB;
--                        end if;          
--                    else 
--                        m0_core_next_state <= s_PC_UPDATED_INVALID;
--                    end if;    
--                when s_INSTB_AFTER_MEM_ACCESS =>
                
--                    if (PC_updated = '0') then
--                        if (use_PC_value = true) then  
--                            m0_core_next_state <= s_INSTB_MEM_ACCESS;
--                        else
--                            core_inst_ptr <= core_inst_ptr + 1;
--                            m0_core_next_state <= s_EXEC_INSTA;
--                        end if; 
--                    else 
--                        m0_core_next_state <= s_PC_UPDATED_INVALID;
--                    end if;  
                
--                     if (PC_updated = '0') then
--                        core_inst_ptr <= core_inst_ptr + 1;                    
--                        if (use_PC_value = true) then  
--                             m0_core_next_state <= s_INSTB_MEM_ACCESS;
--                        else
--                             m0_core_next_state <= s_EXEC_INSTA;
--                        end if; 
--                    else 
--                        m0_core_next_state <= s_PC_UPDATED_INVALID;
--                    end if;
--                when s_MEM_ACCESS => m0_core_next_state <= m0_core_state_after_mem_access;
                when others => m0_core_next_state <= s_RESET;
            end case;
        end if;            
    end process;

      output_p: process (m0_core_state, access_mem, PC(1)) begin
        case (m0_core_state) is
            when s_RESET => refetch <= false; execute_mem_rw <= false; disable_fetch <= false; disable_executor <= false; haddr_ctrl <= false;
           -- when s_START_DELAY_CYCLE => enable_decode <= '0'; enable_execute <= '0';
            when s_RUN =>  refetch <= access_mem; execute_mem_rw <= false; disable_fetch <= access_mem; disable_executor <= false; haddr_ctrl <= false;
            when s_DATA_MEM_ACCESS =>  refetch <= false; execute_mem_rw <= false;  disable_executor <= false; haddr_ctrl <= true;
                if (PC(1) = '0') then
                    disable_fetch <= true;
                else
                    disable_fetch <= false;
                end if;    
            when s_EXECUTE_DATA_MEM_RW =>  refetch <= access_mem; execute_mem_rw <= true; disable_executor <= false; haddr_ctrl <= false;
                if (access_mem = true) then
                    disable_fetch <= true;
                else
                    disable_fetch <= false;
                end if;    
                
--            when s_EXEC_INSTA_START =>  
--            when s_EXEC_INSTA => 
--            when s_EXEC_INSTB => 
--            when s_PC_UPDATED_INVALID => 
--            when s_EXEC_INSTA_INVALID => 
--            when s_EXEC_INSTB_INVALID =>
--            when s_PC_UNALIGNED =>
--            when s_REFETCH_INSTB =>
--            when s_REFETCH_INSTA => 
            when others =>  refetch <= false; execute_mem_rw <= false; disable_fetch <= false; disable_executor <= false; haddr_ctrl <= false;
        end case;
    end process;       
    
  

--    state <= m0_core_state;
--    next_state <= m0_core_next_state;

end Behavioral;
