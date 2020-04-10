----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/04/2020 05:39:03 AM
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
        pc_updated : in std_logic;
        pipeline_is_invalid: out std_logic
    );
end pipeline_invalidator;

architecture Behavioral of pipeline_invalidator is
    type state_t is (pipeline_invalid1, pipeline_invalid2, pipeline_invalid3, pipeline_valid);  -- Executor commands
    signal state : state_t;
    signal next_state : state_t;

begin

     state_p: process (clk) begin
        if (rising_edge(clk)) then
            if (reset = '0') then
               state <= next_state; 
            else
                state <= pipeline_valid; 
            end if;    
        end if;
    end process;
    
    next_state_p: process (state, reset, pc_updated) begin
        if (reset = '0') then
            case (state) is
                when pipeline_valid    => 
                    if (pc_updated = '0') then
                        next_state <= pipeline_valid;
                    else 
                        next_state <= pipeline_invalid1;
                    end if;    
                when pipeline_invalid1 => next_state <= pipeline_invalid2;
                when pipeline_invalid2 => next_state <= pipeline_invalid3;
                when pipeline_invalid3 => next_state <= pipeline_valid;
                when others =>            next_state <= pipeline_valid;
            end case;
        else
            next_state <= pipeline_valid; 
        end if;  
    end process;
    
    
    output_p: process (state) begin
        case (state) is
            when pipeline_valid    => pipeline_is_invalid <= '0';
            when pipeline_invalid1 => pipeline_is_invalid <= '1';
            when pipeline_invalid2 => pipeline_is_invalid <= '1';
            when pipeline_invalid3 => pipeline_is_invalid <= '1';
            when others =>            pipeline_is_invalid <= '0';
         end case;       
    end process;
    

end Behavioral;
