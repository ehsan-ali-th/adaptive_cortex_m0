----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/20/2020 07:02:13 PM
-- Design Name: 
-- Module Name: pipeline_invalidator - Behavioral
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

entity pipeline_invalidator is
    Port (
        clk : in std_logic;
        reset : in std_logic;
        trigger : in boolean;
        invalidate_pipeline : out boolean
     );
end pipeline_invalidator;

architecture Behavioral of pipeline_invalidator is
    type state_t is (
        s_RESET,
        s_READY,
        s_DISENGAGE
    );
    
    signal state : state_t;
    signal next_state : state_t;

begin

     state_p: process (clk) begin
        if (rising_edge(clk)) then
            if (reset = '0')then
                state <= next_state;
            else
                state <= s_RESET;
            end if;
        end if;
    end process;
    
     next_state_p: process (state, trigger) begin
        case (state) is
            when s_RESET => next_state <= s_READY;
            when s_READY => if (trigger = true) then next_state <= s_DISENGAGE; else  next_state <= s_READY; end if;
            when s_DISENGAGE => next_state <= s_READY;
            when others => next_state <= s_RESET;
        end case;
    end process;

     invalidate_pipeline_p: process (state, trigger) begin
        case (state) is
            when s_RESET => invalidate_pipeline <= false;
            when s_READY => invalidate_pipeline <= trigger;
            when s_DISENGAGE => invalidate_pipeline <= false;
            when others =>invalidate_pipeline <= false;
        end case;
    end process;
    
end Behavioral;
