----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/16/2020 11:59:53 AM
-- Design Name: 
-- Module Name: bus_matrix - Behavioral
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

entity bus_matrix is
    Port ( 
        clk : in std_logic;
        reset : in std_logic;
        cortex_m0_HADDR : in std_logic_vector (31 downto 0); 
        cortex_m0_HWDATA : in std_logic_vector (31 downto 0);
        -- HWRITE:
        --   Indicates the transfer direction. When HIGH this signal indicates a write transfer
        --      and when LOW a read transfer. It has the same timing as the address signals,
        --      however, it must remain constant throughout a burst transfer.        
        cortex_m0_HWRITE : in std_logic;
        cortex_m0_HSIZE : in std_logic_vector (2 downto 0);
        cortex_m0_HRDATA : out std_logic_vector (31 downto 0);
            
        code_bram_DOUTA : in std_logic_vector (31 downto 0); 
        code_bram_ADDRA : out std_logic_vector (14 downto 0); 
        code_bram_DINA : out std_logic_vector (31 downto 0); 
        code_bram_ENA : out std_logic; 
        code_bram_WEA : out std_logic_vector (3 downto 0); 

        data_bram_DOUTA : in std_logic_vector (31 downto 0); 
        data_bram_ADDRA : out std_logic_vector (14 downto 0); 
        data_bram_DINA : out std_logic_vector (31 downto 0); 
        data_bram_ENA : out std_logic; 
        data_bram_WEA : out std_logic_vector (3 downto 0)

    );
end bus_matrix;

architecture Behavioral of bus_matrix is
    signal internal_reset : std_logic;
    signal HSEL_code_bram_value : std_logic;
    signal HSEL_data_bram_value : std_logic;
    signal HSEL_code_bram : std_logic;
    signal HSEL_data_bram : std_logic;

begin

    internal_reset <= not reset;

    -- We need to delay select signals by one clock cycle for memory reads
    HSEL_p: process (clk) begin
        if (internal_reset = '1') then
            HSEL_code_bram <= '1';      -- Initially start reading from code memory
            HSEL_data_bram <= '0';
        else
            if (rising_edge(clk)) then
                HSEL_code_bram <= HSEL_code_bram_value;
                HSEL_data_bram <= HSEL_data_bram_value;    
            end if;                       
        end if;
    end process;
    
    address_decoder_p: process (cortex_m0_HADDR) 
        variable mem_address_int : integer;
    begin
        mem_address_int := to_integer(unsigned(cortex_m0_HADDR));
        case (mem_address_int) is
            when 0          to     32767      => HSEL_code_bram_value <= '1'; HSEL_data_bram_value <= '0';      -- Select Code RAM Block : 0x0000_0000 to 0x0000_8000 
            when 536870912  to     536903680  => HSEL_code_bram_value <= '0'; HSEL_data_bram_value <= '1';      -- Select Data RAM Block : 0x2000_0000 to 0x2000_8000
            when others                       => HSEL_code_bram_value <= '0'; HSEL_data_bram_value <= '0';      -- Select None  
        end case;
    end process;
    
    rdata_mux_p: process (HSEL_code_bram, HSEL_data_bram, code_bram_DOUTA, data_bram_DOUTA) 
        variable mux_sel : std_logic_vector (1 downto 0);
    begin
        mux_sel := HSEL_code_bram & HSEL_data_bram;
        case (mux_sel) is
            when "10"   => cortex_m0_HRDATA <= code_bram_DOUTA;      -- Read from Code Block RAM
            when "01"   => cortex_m0_HRDATA <= data_bram_DOUTA;      -- Read from Data Block RAM
            when others => cortex_m0_HRDATA <= (others => '1');
        end case;
   end process;
    
    en_p: process (HSEL_code_bram_value, HSEL_data_bram_value) 
        variable mux_sel : std_logic_vector (1 downto 0);
    begin
        mux_sel := HSEL_code_bram_value & HSEL_data_bram_value;
        case (mux_sel) is
            when "10"   => code_bram_ENA <= '1'; data_bram_ENA <= '0';      -- Enable Code Block RAM
            when "01"   => code_bram_ENA <= '0'; data_bram_ENA <= '1';      -- Enable Data Block RAM
            when others => code_bram_ENA <= '0'; data_bram_ENA <= '0';      -- Enable None
        end case;
   end process;
   
    we_p: process (cortex_m0_HWRITE, HSEL_code_bram_value, HSEL_data_bram_value, cortex_m0_HSIZE) 
        variable mux_sel : std_logic_vector (1 downto 0);
    begin
        mux_sel := HSEL_code_bram_value & HSEL_data_bram_value;
        if (cortex_m0_HWRITE = '1') then        
            case (mux_sel) is
                when "10"   => 
                    case (cortex_m0_HSIZE) is
                        when "000" => code_bram_WEA <= "0001"; data_bram_WEA <= "0000";      -- Write Enable Code Block RAM - Byte
                        when "001" => code_bram_WEA <= "0011"; data_bram_WEA <= "0000";      -- Write Enable Code Block RAM - Half-Word
                        when "010" => code_bram_WEA <= "1111"; data_bram_WEA <= "0000";      -- Write Enable Code Block RAM - Word
                        when others => code_bram_WEA <= "0000"; data_bram_WEA <= "0000"; 
                    end case;
                when "01"   => 
                    case (cortex_m0_HSIZE) is
                        when "000" => code_bram_WEA <= "0000"; data_bram_WEA <= "0001";      -- Write Enable Data Block RAM - Byte
                        when "001" => code_bram_WEA <= "0000"; data_bram_WEA <= "0011";      -- Write Enable Data Block RAM - Half-Word
                        when "010" => code_bram_WEA <= "0000"; data_bram_WEA <= "1111";      -- Write Enable Data Block RAM - Word
                        when others => code_bram_WEA <= "0000"; data_bram_WEA <= "0000"; 
                    end case;
                when others => code_bram_WEA <= "0000"; data_bram_WEA <= "0000";      -- Write Enable None
            end case;
        else
            code_bram_WEA <= "0000"; data_bram_WEA <= "0000"; 
        end if;    
    end process;   
    
    DINA_p: process (cortex_m0_HWDATA, HSEL_code_bram_value, HSEL_data_bram_value) 
        variable mux_sel : std_logic_vector (1 downto 0);
    begin
        mux_sel := HSEL_code_bram_value & HSEL_data_bram_value;
        case (mux_sel) is
            when "10"   => code_bram_DINA <= cortex_m0_HWDATA;
            when "01"   => data_bram_DINA <= cortex_m0_HWDATA;
            when others => null;
        end case;
    end process;   
    
    code_bram_ADDRA (14 downto 13) <= "00";
    data_bram_ADDRA (14 downto 13) <= "00";
    code_bram_ADDRA (12 downto 0) <= cortex_m0_HADDR (14 downto 2);              -- Word Size (32-bit) read 
    data_bram_ADDRA (12 downto 0) <= cortex_m0_HADDR (14 downto 2);

end Behavioral;
