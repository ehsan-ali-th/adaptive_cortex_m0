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
        enable_decode : out std_logic;
        enable_execute: out std_logic;
        HADDR : out std_logic_vector(31 downto 0);
        PC : out std_logic_vector(31 downto 0)

        --PC_updated : in std_logic;
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
    signal m0_core_state :  core_state_t;
    signal m0_core_next_state :  core_state_t;
--    signal m0_core_state_after_mem_access :  core_state_t;
    signal size_of_executed_instruction : unsigned (31 downto 0);
    signal PC_value :  unsigned(31 downto 0);
    signal HADDR_value :  unsigned(31 downto 0);
    
                    
            
begin

    HADDR <= std_logic_vector(HADDR_value);

    
    PC_p: process (clk, reset, m0_core_state) begin
        if (reset = '1') then
            PC <= x"0000_0000";
            --HADDR <= x"0000_0000";
        else    
            if (rising_edge(clk)) then
                if (m0_core_state = s_RUN) then
                    PC <= std_logic_vector(PC_value);
                   --HADDR <= std_logic_vector(HADDR_value);
                end if;
            end if;    
        end if;
    end process;
    
    PC_value_p : process (size_of_executed_instruction, PC, m0_core_state) begin
        if (m0_core_state = s_RESET) then
            PC_value <= x"0000_0000";
        else        
            PC_value <= size_of_executed_instruction + unsigned(PC);
        end if; 
    end process;

    HRDATA_valuep : process (PC_value, m0_core_state) begin
        if (m0_core_state = s_RESET) then
            HADDR_value <= x"0000_0000";
        else    
            HADDR_value <= (PC_value and x"FFFF_FFFC");
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

    next_state_p: process (m0_core_state, reset) begin
        if (reset = '1') then
             m0_core_next_state <= s_RESET;
        else     
            case (m0_core_state) is
                when s_RESET => m0_core_next_state <=s_RUN;  
                --when s_START_DELAY_CYCLE => m0_core_next_state <= s_RUN;  
                when s_RUN =>  m0_core_next_state <= s_RUN;     
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

      output_p: process (m0_core_state) begin
        case (m0_core_state) is
            when s_RESET => enable_decode <= '0'; enable_execute <= '0';
           -- when s_START_DELAY_CYCLE => enable_decode <= '0'; enable_execute <= '0';
            when s_RUN => enable_decode <= '1'; enable_execute <= '1';
                
--            when s_EXEC_INSTA_START =>  
--            when s_EXEC_INSTA => 
--            when s_EXEC_INSTB => 
--            when s_PC_UPDATED_INVALID => 
--            when s_EXEC_INSTA_INVALID => 
--            when s_EXEC_INSTB_INVALID =>
--            when s_PC_UNALIGNED =>
--            when s_REFETCH_INSTB =>
--            when s_REFETCH_INSTA => 
            when others => enable_decode <= '0'; enable_execute <= '0';
        end case;
    end process;          

--    state <= m0_core_state;
--    next_state <= m0_core_next_state;

end Behavioral;
