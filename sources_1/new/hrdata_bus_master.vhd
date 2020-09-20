----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/13/2020 07:47:58 AM
-- Design Name: 
-- Module Name: hrdata_bus_master - Behavioral
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

entity hrdata_bus_master is
 Port (
         clk : in std_logic;
         reset : in std_logic;
         hrdata_ctrl : in hrdata_ctrl_t;	
         hrdata : in std_logic_vector(31 downto 0);	
         hrdata_program_value : out std_logic_vector(31 downto 0);	
         hrdata_data_value : out std_logic_vector(31 downto 0);	
         ldm_hrdata_value : out std_logic_vector(31 downto 0);	
         SP_main_init : out std_logic_vector(31 downto 0);	
         PC_init : out std_logic_vector(31 downto 0);	
         SVC_addr : out std_logic_vector(31 downto 0)
     );
end hrdata_bus_master;

architecture Behavioral of hrdata_bus_master is

         signal hrdata_program_value_cur :  std_logic_vector(31 downto 0);	
         signal hrdata_program_value_ns :  std_logic_vector(31 downto 0);	
         
         signal hrdata_data_value_cur :  std_logic_vector(31 downto 0);	
         signal hrdata_data_value_ns :  std_logic_vector(31 downto 0);	
         
         signal ldm_hrdata_value_cur :  std_logic_vector(31 downto 0);	
         signal ldm_hrdata_value_ns :  std_logic_vector(31 downto 0);	

         signal SP_main_init_cur :  std_logic_vector(31 downto 0);	
         signal SP_main_init_ns :  std_logic_vector(31 downto 0);	

         signal PC_init_cur :  std_logic_vector(31 downto 0);
         signal PC_init_ns :  std_logic_vector(31 downto 0);

         signal SVC_addr_cur :  std_logic_vector(31 downto 0);
         signal SVC_addr_ns :  std_logic_vector(31 downto 0);
 
begin
    
        hrdata_program_value_p : process (hrdata_ctrl, hrdata, hrdata_program_value_cur) begin
            if (hrdata_ctrl = sel_ALU_RESULT or hrdata_ctrl = sel_LDM_Rn) then
                hrdata_program_value     <= hrdata;
                hrdata_program_value_ns  <= hrdata;
            else
                hrdata_program_value     <= hrdata_program_value_cur;
                hrdata_program_value_ns  <= hrdata_program_value_cur;
            end if;
        end process;
        
        hrdata_data_value_p : process (hrdata_ctrl, hrdata, hrdata_data_value_cur) begin
            if (hrdata_ctrl = sel_HRDATA_VALUE_SIZED) then
                hrdata_data_value     <= hrdata;
                hrdata_data_value_ns  <= hrdata;
            else
                hrdata_data_value     <= hrdata_data_value_cur;
                hrdata_data_value_ns  <= hrdata_data_value_cur;
            end if;
        end process;

        ldm_hrdata_value_p : process (hrdata_ctrl, hrdata, ldm_hrdata_value_cur) begin
            if (hrdata_ctrl = sel_LDM_DATA) then
                ldm_hrdata_value     <= hrdata;
                ldm_hrdata_value_ns  <= hrdata;
            else
                ldm_hrdata_value     <= ldm_hrdata_value_cur;
                ldm_hrdata_value_ns  <= ldm_hrdata_value_cur;
            end if;
        end process;

        SP_main_init_p : process (hrdata_ctrl, hrdata, SP_main_init_cur) begin
            if (hrdata_ctrl = sel_SP_main_init) then
                SP_main_init     <= hrdata;
                SP_main_init_ns  <= hrdata;
            else
                SP_main_init     <= SP_main_init_cur;
                SP_main_init_ns  <= SP_main_init_cur;
            end if;
        end process;
        
        PC_init_p : process (hrdata_ctrl, hrdata, PC_init_cur) begin
            if (hrdata_ctrl = sel_PC_init) then
                PC_init     <= hrdata;
                PC_init_ns  <= hrdata;
            else
                PC_init     <= PC_init_cur;
                PC_init_ns  <= PC_init_cur;
            end if;
        end process;
         
        SVC_addr_p : process (hrdata_ctrl, hrdata, SVC_addr_cur) begin
            if (hrdata_ctrl = sel_SVC) then
                SVC_addr     <= hrdata;
                SVC_addr_ns  <= hrdata;
            else
                SVC_addr     <= SVC_addr_cur;
                SVC_addr_ns  <= SVC_addr_cur;
            end if;
        end process;

        registers_p : process (clk) begin
            if (reset = '1') then
                hrdata_program_value_cur <= (others => '0');
                hrdata_data_value_cur <= (others => '0');
                ldm_hrdata_value_cur <= (others => '0');
                SP_main_init_cur <= (others => '0');
                PC_init_cur <= (others => '0');
                SVC_addr_cur <= (others => '0');
            else
                if (rising_edge(clk)) then
                    hrdata_program_value_cur <= hrdata_program_value_ns;
                    hrdata_data_value_cur <= hrdata_data_value_ns;
                    ldm_hrdata_value_cur <= ldm_hrdata_value_ns;
                    SP_main_init_cur <= SP_main_init_ns;
                    PC_init_cur <= PC_init_ns;
                    SVC_addr_cur <= SVC_addr_ns;
                end if;    
            end if;
        end process;

end Behavioral;
