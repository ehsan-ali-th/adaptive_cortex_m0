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
--use IEEE.NUMERIC_STD.ALL;

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
        PC_2bit_LSB :  std_logic_vector(1 downto 0);
        state : out core_state_t
        
    );
end core_state;

architecture Behavioral of core_state is
    signal m0_core_state :  core_state_t;
    signal m0_core_next_state :  core_state_t;
begin

    state_p: process (clk) begin
        if (rising_edge(clk)) then
            if (reset = '0') then
                m0_core_state <= m0_core_next_state;
            else
                m0_core_state <= s_RESET;
            end if;    
        end if;
    end process;

    next_state_p: process (m0_core_state, PC_updated, run) begin
        case (m0_core_state) is
            when s_RESET => 
                if (reset = '1') then
                    m0_core_next_state <= s_RESET;
                else 
                    m0_core_next_state <= s_EXEC_INSTA_START;         -- start to enter normal execution mode
                end if;      
            when s_EXEC_INSTA_START =>  
                 if (PC_updated = '0') then
                    m0_core_next_state <= s_EXEC_INSTB;
                else 
                    m0_core_next_state <= s_PC_UPDATED_INVALID;
                end if;   
            when s_EXEC_INSTA => 
                if (PC_updated = '0') then
                    m0_core_next_state <= s_EXEC_INSTB;
                else 
                    m0_core_next_state <= s_PC_UPDATED_INVALID;
                end if;    
            when s_EXEC_INSTB => 
                if (PC_updated = '0') then
                    m0_core_next_state <= s_EXEC_INSTA;
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
                -- Always the last invalid state is s_EXEC_INSTA_INVALID. So if the Pc is unaligned we 
                -- just need to extend the pipeline invalid state one more cycle.
                if (PC_2bit_LSB = B"00") then
                    m0_core_next_state <= s_EXEC_INSTB;
                else
                    m0_core_next_state <= s_PC_UNALIGNED;
                end if;
            when s_EXEC_INSTB_INVALID => m0_core_next_state <= s_EXEC_INSTA_INVALID;
            when s_PC_UNALIGNED => m0_core_next_state <= s_EXEC_INSTA;
            when others => m0_core_next_state <= s_RESET;
        end case;
end process;

              

    state <= m0_core_state;

end Behavioral;
