-- Miniature Accelerator Memory VHDL File:
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.Numeric_Std.all;

entity RC_accel_rom is
    port (
        clk   : in  std_logic;
        addr : in  std_logic_vector (3 downto 0);
        dataout : out std_logic_vector (7 downto 0)
    );
end entity RC_accel_rom;

architecture RTL of RC_accel_rom is

type ram_type is array (0 to (2**addr'length)-1) of std_logic_vector (dataout'range);
signal ram : ram_type := (
	x"2a",
	x"2a",
	x"08",
	x"0e",
	x"31",
	x"21",
	x"21",
	x"21",
	x"20",
	x"21",
	x"22",
	x"22",
	x"00"
);
signal read_addr : std_logic_vector(addr'range);

begin

    RamProc: process(clk) is begin
        if rising_edge(clk) then
            read_addr <= addr;
        end if;
    end process RamProc;

    dataout <= ram(to_integer(unsigned(read_addr)));

end architecture RTL;
-- Miniature Accelerator Memory VHDL File ends here
