----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/24/2020 04:12:29 PM
-- Design Name: 
-- Module Name: ram - Behavioral
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

entity ram is
    generic (DATA_WIDTH : positive;
           ADDRESS_WIDTH : positive);
    port ( 
        WCLK : in std_logic;
        reset : in std_logic;
        WE : in std_logic;
        WR_ADDR: in std_logic_vector (ADDRESS_WIDTH-1 downto 0) := (OTHERS => '0'); -- Wrtie address
        DI: in std_logic_vector (DATA_WIDTH-1 downto 0);
        ADDRA: in std_logic_vector (ADDRESS_WIDTH-1 downto 0) := (OTHERS => '0');   -- Read address A
        DOA: out std_logic_vector (DATA_WIDTH-1 downto 0);
        ADDRB: in std_logic_vector (ADDRESS_WIDTH-1 downto 0) := (OTHERS => '0');   -- Read address B
        DOB: out std_logic_vector (DATA_WIDTH-1 downto 0)  
    );
end ram;

architecture Behavioral of ram is
    type ram_type is array ((2**ADDRA'length) - 1 downto 0) of std_logic_vector(DI'range);
    signal ram_s : ram_type := (others=> (others=>'0'));
begin

    -- Synchronous write, asynchronous read
    RamProc: process(WCLK) begin
        --if (reset = '0') then
            if rising_edge(WCLK) then
                if WE = '1' then
                    ram_s(to_integer(unsigned(WR_ADDR))) <= DI;
                end if;
            end if;      
        --end if;
    end process RamProc;

--    read_p: process(reset) begin
--        if (reset = '0') then
--            DOA <= ram_s(to_integer(unsigned(ADDRA)));
--            DOB <= ram_s(to_integer(unsigned(ADDRB)));
--        else 
--            DOA <= (others => '0');    
--            DOB <= (others => '0');    
--        end if;
--    end process read_p;

            DOA <= ram_s(to_integer(unsigned(ADDRA)));
            DOB <= ram_s(to_integer(unsigned(ADDRB)));

end Behavioral;