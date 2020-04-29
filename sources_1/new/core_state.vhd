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
        new_PC : in std_logic_vector (31 downto 0);
        PC : out std_logic_vector (31 downto 0);
        PC_decode : out std_logic_vector (31 downto 0);
        PC_execute :  out std_logic_vector (31 downto 0);
        PC_after_execute :  out std_logic_vector (31 downto 0);
        execute_mem_rw : out boolean;
        disable_fetch : out boolean;
        haddr_ctrl : out boolean;               -- true  = put data memory address on the bus, 
                                                -- false = put program memory address on the bus
        disable_executor : out boolean;
        gp_addrA_executor_ctrl : out boolean
          
    );
end core_state;

architecture Behavioral of core_state is

    signal m0_core_state :  core_state_t;
    signal m0_core_next_state :  core_state_t;
    signal size_of_executed_instruction : unsigned (31 downto 0);
    signal PC_value :  unsigned(31 downto 0);
	signal refetch_i : boolean;
            
begin

    PC_p: process (clk, reset) begin
        if (reset = '1') then
            PC <= x"0000_0000";
            PC_decode <= x"0000_0000";
            PC_execute  <= x"0000_0000"; 
            PC_after_execute  <= x"0000_0000"; 
        else    
            if (rising_edge(clk)) then
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
    
    PC_value_p : process (size_of_executed_instruction, PC, m0_core_state, refetch_i) begin
        if (m0_core_state = s_RESET) then
            PC_value <= x"0000_0002";
        else  
             if (refetch_i = false) then 
                    PC_value <= size_of_executed_instruction + unsigned(PC);
            end if;      
            
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
     
    next_state_p: process (m0_core_state, reset, access_mem, PC_updated) begin
        if (reset = '1') then
             m0_core_next_state <= s_RESET;
        else     
            case (m0_core_state) is
                when s_RESET => m0_core_next_state <= s_RESET1;  
                when s_RESET1 => m0_core_next_state <= s_RESET2;  
                when s_RESET2 => m0_core_next_state <= s_RUN;  
                when s_RUN =>  
                    -- CHECK if instruction needs memory access
                    if (access_mem = true) then 
                        m0_core_next_state <= s_DATA_MEM_ACCESS;
                    -- CHECK if instruction updates PC
                    elsif (PC_updated = true) then
                       m0_core_next_state <= s_PC_UPDATED;
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
               when s_PC_UPDATED =>   
                    m0_core_next_state <= s_PIPELINE_FLUSH1;
               when s_PIPELINE_FLUSH1 =>   
                    m0_core_next_state <= s_PIPELINE_FLUSH2;
               when s_PIPELINE_FLUSH2 =>   
                    m0_core_next_state <= s_PIPELINE_FLUSH3;
               when s_PIPELINE_FLUSH3 =>   
                    m0_core_next_state <= s_RUN;
               when others => m0_core_next_state <= s_RESET;
            end case;
        end if;            
    end process;

    output_p: process (m0_core_state, access_mem, PC(1)) begin
        case (m0_core_state) is
            when s_RESET => refetch_i <= false; execute_mem_rw <= false; disable_fetch <= false; disable_executor <= true; haddr_ctrl <= false;
                gp_addrA_executor_ctrl <= false; 
            when s_RESET1 => refetch_i <= false; execute_mem_rw <= false; disable_fetch <= false; disable_executor <= true; haddr_ctrl <= false; 
                gp_addrA_executor_ctrl <= false;
            when s_RESET2 => refetch_i <= false; execute_mem_rw <= false; disable_fetch <= false; disable_executor <= true; haddr_ctrl <= false; 
                gp_addrA_executor_ctrl <= false;
 
           -- when s_START_DELAY_CYCLE => enable_decode <= '0'; enable_execute <= '0';
            when s_RUN =>  refetch_i <= access_mem; execute_mem_rw <= false;  disable_executor <= false; haddr_ctrl <= false;
                disable_fetch <= access_mem;
                gp_addrA_executor_ctrl <= false;
 
            when s_DATA_MEM_ACCESS =>  refetch_i <= false; execute_mem_rw <= false;  disable_executor <= true; haddr_ctrl <= true;
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= access_mem;
                    end if;
                    gp_addrA_executor_ctrl <= false;
            when s_EXECUTE_DATA_MEM_RW =>  refetch_i <= access_mem; execute_mem_rw <= true; disable_executor <= false; haddr_ctrl <= false;
                   disable_fetch <= access_mem;
                   gp_addrA_executor_ctrl <= false;
                   
            when s_PC_UPDATED =>  refetch_i <= false; execute_mem_rw <= false; disable_fetch <= false; disable_executor <= true; haddr_ctrl <= false;
                gp_addrA_executor_ctrl <= true; 
            when s_PIPELINE_FLUSH1 =>  refetch_i <= false; execute_mem_rw <= false; disable_fetch <= false; disable_executor <= true; haddr_ctrl <= false;
                gp_addrA_executor_ctrl <= false; 
            when s_PIPELINE_FLUSH2 =>  refetch_i <= false; execute_mem_rw <= false; disable_fetch <= false; disable_executor <= true; haddr_ctrl <= false;
                gp_addrA_executor_ctrl <= false; 
            when s_PIPELINE_FLUSH3 =>  refetch_i <= false; execute_mem_rw <= false; disable_fetch <= false; disable_executor <= true; haddr_ctrl <= false;
                gp_addrA_executor_ctrl <= false; 
             

            when others =>  refetch_i <= false; execute_mem_rw <= false; disable_fetch <= false; disable_executor <= false; haddr_ctrl <= false;
                gp_addrA_executor_ctrl <= false;

        end case;
    end process;       
    
  

--    state <= m0_core_state;
--    next_state <= m0_core_next_state;

end Behavioral;
