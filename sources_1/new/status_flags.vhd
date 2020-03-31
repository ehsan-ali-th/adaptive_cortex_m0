----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/24/2020 04:40:02 PM
-- Design Name: 
-- Module Name: status_flags - Behavioral
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

entity status_flags is
    Port (
        clk : in std_logic;
        reset : in std_logic;
        WE : in std_logic;                              -- Write Enable
        
        N  : in std_logic;                              -- Negative    
        Z  : in std_logic;                              -- Zero 
        C  : in std_logic;                              -- Carry
        V  : in std_logic;                              -- Overflow
        EN : in std_logic_vector (5 downto 0);          -- Exception Number.
        T  : in std_logic;                              -- Thumb code is executed.
 
        RN  : out std_logic;                            -- Read Negative    
        RZ  : out std_logic;                            -- Read Zero 
        RC  : out std_logic;                            -- Read Carry
        RV  : out std_logic;                            -- Read Overflow
        REN : out std_logic_vector (5 downto 0);        -- Read Exception Number.
        RT  : out std_logic                             -- Read Thumb code is executed.
    );
end status_flags;

architecture Behavioral of status_flags is
    signal status_flags : std_logic_vector(31 downto 0) := (others=>'0');
begin

    FlagProc: process(clk) begin
        if rising_edge(clk) then
            if reset = '0' then 
                if WE = '1' then
                    status_flags (31) <= N;
                    status_flags (30) <= Z;
                    status_flags (29) <= C;
                    status_flags (28) <= V;
                    status_flags (5 downto 0) <= EN;
                    status_flags (24) <= T;
                end if;
            else  
                status_flags <= (others => '0');
            end if;
        end if;
    end process FlagProc;

    RN <= status_flags (31);
    RZ <= status_flags (30);
    RC <= status_flags (29);
    RV <= status_flags (28);
    REN <= status_flags (5 downto 0);
    RT <= status_flags (24);
end Behavioral;
