----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/24/2020 04:10:47 PM
-- Design Name: 
-- Module Name: registers - Behavioral
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

entity registers is
    Port (
        clk : in std_logic;
        reset : in std_logic;
        WE : in std_logic;
        gp_data_in : in std_logic_vector(31 downto 0);
        gp_WR_addr: in std_logic_vector(3 downto 0);
        gp_addrA: in std_logic_vector(3 downto 0);
        gp_addrB: in std_logic_vector(3 downto 0);
        gp_addrC: in std_logic_vector(3 downto 0);
        gp_ram_dataA : out std_logic_vector(31 downto 0);
        gp_ram_dataB : out std_logic_vector(31 downto 0);
        gp_ram_dataC : out std_logic_vector(31 downto 0)
    );
end registers;

architecture Behavioral of registers is

    component ram is        
        generic (
            DATA_WIDTH : positive;
            ADDRESS_WIDTH : positive);
        port ( 
            WCLK : in std_logic;
            reset : in std_logic;
            WE : in std_logic;
            WR_ADDR: in std_logic_vector (ADDRESS_WIDTH-1 downto 0) := (OTHERS => '0');
            DI: in std_logic_vector (DATA_WIDTH-1 downto 0);
            ADDRA: in std_logic_vector (ADDRESS_WIDTH-1 downto 0) := (OTHERS => '0');
            DOA: out std_logic_vector (DATA_WIDTH-1 downto 0);
            ADDRB: in std_logic_vector (ADDRESS_WIDTH-1 downto 0) := (OTHERS => '0');
            DOB: out std_logic_vector (DATA_WIDTH-1 downto 0);
            ADDRC: in std_logic_vector (ADDRESS_WIDTH-1 downto 0) := (OTHERS => '0');   -- Read address C
            DOC: out std_logic_vector (DATA_WIDTH-1 downto 0)   
        );
    end component;
    
begin

     gp_registers: ram 
        generic map (
            DATA_WIDTH => 32,        -- 16 x 32-bit RAM
            ADDRESS_WIDTH => 4    
        )
        port map (
            WCLK => clk,
            reset => reset,
            WE => WE,
            WR_ADDR => gp_WR_addr,
            DI => gp_data_in,
            ADDRA => gp_addrA,
            DOA => gp_ram_dataA,   
            ADDRB => gp_addrB,
            DOB => gp_ram_dataB, 
            ADDRC => gp_addrC,
            DOC => gp_ram_dataC   
        );
        
end Behavioral;
