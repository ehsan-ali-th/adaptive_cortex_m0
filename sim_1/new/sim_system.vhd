----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/22/2020 05:44:50 PM
-- Design Name: 
-- Module Name: sim_system - Behavioral
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

use STD.textio.all;
use ieee.std_logic_textio.all;

library xil_defaultlib;
use xil_defaultlib.GlobalSignalsPkg.all;

library xil_defaultlib;
use xil_defaultlib.helper_funcs.all;

entity sim_system is
--  Port ( );
end sim_system;

architecture Behavioral of sim_system is

    component system is
      port (
        LED0 : out STD_LOGIC;
        LED1 : out STD_LOGIC;
        clk_300mhz_clk_n : in STD_LOGIC;
        clk_300mhz_clk_p : in STD_LOGIC;
        reset : in STD_LOGIC
      );
    end component;

  -- inputs
    signal clk300Mhz_n: std_logic := '0';
    signal clk300Mhz_p: std_logic := '1';
    signal reset: std_logic := '0';

    -- outputs
    signal led0: std_logic := '0';
    signal led1: std_logic := '0';

    constant half_period300 : time := 3.3333 ns; -- produce 300Mhz clock  
    
    file trace_file_handler     : text;
    
    signal cortex_m0_clk : std_logic;
    signal cortex_m0_instruction : std_logic_vector (15 downto 0);
    signal cortex_m0_next_state : core_state_t;
    signal cortex_m0_opcode : string(1 to 18);
    signal cortex_m0_use_accelerator : boolean;
    
    --type INT_ARRAY is array (integer range <>) of integer;
    type STRING_ARRAY is array (natural range <>) of string(1 to 5);
    --signal INT_TABLE: INT_ARRAY(0 to 675000);
    signal STRING_TABLE: STRING_ARRAY(0 to 1000000);

    
begin

    clk300Mhz_n <= not clk300Mhz_n after half_period300;
    clk300Mhz_p <= not clk300Mhz_p after half_period300;
    
    tb: process begin
        wait for 100 ns; 
        reset <= '1';
        wait for 500 ns;
        reset <= '0';
        wait; -- wait forever
    end process;

    -- Instantiate UUT
    uut: system port map (
        clk_300mhz_clk_n => clk300Mhz_n,
        clk_300mhz_clk_p => clk300Mhz_p,
        reset => reset,
        LED0 => led0,
        LED1 => led1
    );
    
    cortex_m0_clk <= << signal .sim_system.uut.clk_wiz_0_CLK : std_logic >>;
    cortex_m0_instruction <= << signal .sim_system.uut.cortex_m0_core_0.U0.current_instruction_final : std_logic_vector (15 downto 0) >>;
    cortex_m0_next_state <= << signal .sim_system.uut.cortex_m0_core_0.U0.m0_core_state_m.m0_core_next_state : core_state_t >>;
    cortex_m0_opcode <= << signal .sim_system.uut.cortex_m0_core_0.U0.cortex_m0_opcode : string(1 to 18) >>;
    cortex_m0_use_accelerator <= << signal .sim_system.uut.cortex_m0_core_0.U0.accelerator_state : boolean >>;
     
    process begin
        wait for 200 ms;
        report "Simulation finished"  severity note;
        std.env.finish;
    end process;
    
--     if (PUSH_write_counter =  B"00000" and PC_execute(1) = '0') then
--                    report "PUSH R5: sel_LDM_Rn " & integer'image (to_integer(PUSH_write_counter)) & 
--                        " PC_execute(1)= " &  std_logic'image(PC_execute(1)) severity note;

    valid_sequence_file_p: process
        variable inst_line       : line;
        variable inst            : string (1 to 5);
        variable i               : integer := 0;
        file valid_sequence_file : text open READ_MODE is "C:/workspace/Cortex_M0/Cortex_M0.sim/trace.trc";
    begin
        while not endfile(valid_sequence_file) loop
            readline (valid_sequence_file, inst_line);
            read (inst_line, inst);
            STRING_TABLE(i) <=  inst;
            i := i +1;
        end loop;
        wait;     -- added prevents needless loops
    
    end process valid_sequence_file_p;
    
    
    trace_file_p : process (cortex_m0_clk)
       
        variable inst_LINE     : line;
--        variable file_is_open:  boolean := false;
        file trace_file: text open WRITE_MODE is "vivado_trace.txt";
        variable instr_counter : integer := 0;
    begin
       
        if (rising_edge (cortex_m0_clk)) then
            if (cortex_m0_next_state = s_FINISH_PUSH or
                cortex_m0_next_state = s_RUN or
                cortex_m0_next_state = s_EXECUTE_DATA_MEM_R or
                cortex_m0_next_state = s_EXECUTE_DATA_MEM_W or
                cortex_m0_next_state = s_BRANCH_BL_UNCOND_PC_UPDATED or 
                cortex_m0_next_state = s_BRANCH_PC_UPDATED or 
                cortex_m0_next_state = s_BRANCH_UNCOND_PC_UPDATED or
                cortex_m0_next_state = s_DATA_MEM_ACCESS_POP or 
                cortex_m0_next_state = s_BX_PC_UPDATED or
                cortex_m0_next_state = s_DATA_MEM_ACCESS_LDM or
                cortex_m0_next_state = s_FINISH_STM) then -- or
               
                write(inst_LINE, to_string(instr_counter) & HT & cortex_m0_opcode (1 to 5));
                writeline(trace_file, inst_LINE); 
                if (cortex_m0_use_accelerator = false) then
                    if (cortex_m0_opcode (1 to 5) /= STRING_TABLE(instr_counter)) then 
                        report "cortex_m0_opcode = " & cortex_m0_opcode (1 to 5) & 
                            "STRING_TABLE(" & to_string(instr_counter) & ") = " & STRING_TABLE(instr_counter) severity note;
                        report "INST NO = " & to_string(instr_counter) & " MISMATCH." severity failure;
                    end if;
                end if;    
                instr_counter := instr_counter + 1;
            end if;  
        end if;

    end process trace_file_p;

end Behavioral;
