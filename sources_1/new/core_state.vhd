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
        run : in std_logic;
        PC_updated : in std_logic;
        access_mem : in boolean;
        PC_2bit_LSB : in std_logic_vector(1 downto 0);
       -- use_PC_value: in boolean;
        instr_ptr: out std_logic;
        state : out core_state_t;
        next_state : out core_state_t;
        m0_previous_state : out core_state_t
    );
end core_state;

architecture Behavioral of core_state is
    signal m0_core_state :  core_state_t;
    signal m0_core_next_state :  core_state_t;
    signal m0_core_state_after_mem_access :  core_state_t;
begin

    state_p: process (clk) begin
        if (rising_edge(clk)) then
            if (reset = '0') then
--                if (access_mem = true and m0_core_next_state = s_EXEC_INSTB) then 
--                        m0_core_state <= s_REFETCH_INSTB;
--                elsif (access_mem = true and m0_core_next_state = s_EXEC_INSTA) then 
--                        m0_core_state <= s_REFETCH_INSTA;
--                else
--                    m0_core_state <= m0_core_next_state;
--                end if;
                m0_core_state <= m0_core_next_state;
                m0_previous_state <= m0_core_state; 
            else
                m0_core_state <= s_RESET;
                m0_previous_state <= s_RESET;
            end if;    
        end if;
    end process;

    next_state_p: process (m0_core_state, PC_updated, run, access_mem) begin
        if (reset = '1') then
             m0_core_next_state <= s_RESET;
        else     
            case (m0_core_state) is
                when s_RESET => 
                        if (run = '1') then 
                            m0_core_next_state <=  s_RUN;
                        else
                            m0_core_next_state <= s_RESET;     
                        end if;    
               when s_RUN =>  m0_core_next_state <= s_EXEC_INSTA;     
               -- when s_EXEC_INSTA_START =>  
                   --  if (PC_updated = '0') then
    --                     if (use_PC_value = true) then  
    --                        m0_core_next_state <= s_INSTB_MEM_ACCESS;
    --                     else
    --                         core_inst_ptr <= core_inst_ptr + 1;
                         --   m0_core_next_state <= s_EXEC_INSTB;
    --                     end if;  
        --                    if (mem_access = true) then 
    --                        m0_core_state_after_mem_access <= s_EXEC_INSTB; 
    --                        m0_core_next_state <= s_MEM_ACCESS; 
    --                    else
    --                        m0_core_next_state <= s_EXEC_INSTB;
    --                    end if;
                  --  else 
                   --     m0_core_next_state <= s_PC_UPDATED_INVALID;
    --end if;   
                when s_EXEC_INSTA => 
                    if (PC_updated = '0') then
                        if (access_mem = true) then  
                            m0_core_next_state <= s_REFETCH_INSTA; -- refetch INSTA 
                        else
                            m0_core_next_state <= s_EXEC_INSTB;
                        end if; 
                    else 
                        m0_core_next_state <= s_PC_UPDATED_INVALID;
                    end if;    
                when s_EXEC_INSTB => 
                    if (PC_updated = '0') then
                        if (access_mem = true) then  
                            m0_core_next_state <= s_REFETCH_INSTB; -- refetch INSTB 
                        else
                            m0_core_next_state <= s_EXEC_INSTA;
                        end if; 
                    else 
                        m0_core_next_state <= s_PC_UPDATED_INVALID;
                    end if;  
                when s_PC_UPDATED_INVALID => m0_core_next_state <= s_EXEC_INSTB_INVALID;
                when s_EXEC_INSTA_INVALID => 
                    -- PC can only be unaligned if the user loads a value into the PC.
                    -- The following instructions update the PC:
                    -- 
                    -- MOV PC, Rm
                    -- ADD PC,<Rm>
                    --
                    -- In those case the pipeline gets invalidated and then it jumps to new PC to fetch data.
                    -- Always the last invalid state is s_EXEC_INSTA_INVALID. So if the PC is unaligned we 
                    -- just need to extend the pipeline invalid state one more cycle.
                    if (PC_2bit_LSB = B"00") then
                        m0_core_next_state <= s_EXEC_INSTB;
                    else
                        m0_core_next_state <= s_PC_UNALIGNED;
                    end if;
                when s_EXEC_INSTB_INVALID => m0_core_next_state <= s_EXEC_INSTA_INVALID;
                when s_PC_UNALIGNED => m0_core_next_state <= s_EXEC_INSTA;
                when s_REFETCH_INSTB => m0_core_next_state <= s_EXEC_INSTA;
                when s_REFETCH_INSTA => m0_core_next_state <= s_EXEC_INSTB;
    --            when s_INSTA_MEM_ACCESS => m0_core_next_state <= s_INSTB_AFTER_MEM_ACCESS;
    --            when s_INSTB_MEM_ACCESS => m0_core_next_state <= s_INSTA_AFTER_MEM_ACCESS;
    --            when s_INSTA_AFTER_MEM_ACCESS => 
    --                 if (PC_updated = '0') then
    --                    core_inst_ptr <= core_inst_ptr + 1;
    --                    if (use_PC_value = true) then  
    --                         m0_core_next_state <= s_INSTA_MEM_ACCESS;
    --                    else
    --                         m0_core_next_state <= s_EXEC_INSTB;
    --                    end if;          
    --                else 
    --                    m0_core_next_state <= s_PC_UPDATED_INVALID;
    --                end if;    
    --            when s_INSTB_AFTER_MEM_ACCESS =>
                
    --                if (PC_updated = '0') then
    --                    if (use_PC_value = true) then  
    --                        m0_core_next_state <= s_INSTB_MEM_ACCESS;
    --                    else
    --                        core_inst_ptr <= core_inst_ptr + 1;
    --                        m0_core_next_state <= s_EXEC_INSTA;
    --                    end if; 
    --                else 
    --                    m0_core_next_state <= s_PC_UPDATED_INVALID;
    --                end if;  
                
    --                 if (PC_updated = '0') then
    --                    core_inst_ptr <= core_inst_ptr + 1;                    
    --                    if (use_PC_value = true) then  
    --                         m0_core_next_state <= s_INSTB_MEM_ACCESS;
    --                    else
    --                         m0_core_next_state <= s_EXEC_INSTA;
    --                    end if; 
    --                else 
    --                    m0_core_next_state <= s_PC_UPDATED_INVALID;
    --                end if;
    --            when s_MEM_ACCESS => m0_core_next_state <= m0_core_state_after_mem_access;
                when others => m0_core_next_state <= s_RESET;
            end case;
        end if;            
    end process;

--      output_p: process (m0_core_state, PC_updated, run, access_mem) begin
--        case (m0_core_state) is
--            when s_RESET => 
--            when s_EXEC_INSTA_START =>  
--            when s_EXEC_INSTA => 
--            when s_EXEC_INSTB => 
--            when s_PC_UPDATED_INVALID => 
--            when s_EXEC_INSTA_INVALID => 
--            when s_EXEC_INSTB_INVALID =>
--            when s_PC_UNALIGNED =>
--            when s_REFETCH_INSTB =>
--            when s_REFETCH_INSTA => 
--            when others =>
--        end case;
--    end process;          

    state <= m0_core_state;
    next_state <= m0_core_next_state;

end Behavioral;
