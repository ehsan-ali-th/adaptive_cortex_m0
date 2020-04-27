----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/21/2020 11:31:12 PM
-- Design Name: 
-- Module Name: cortex_m0_core - Behavioral
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

library xil_defaultlib;
use xil_defaultlib.helper_funcs.all;


entity cortex_m0_core is
    generic (S_PROGRAM_MEMORY_ENDIAN: boolean := FALSE);           -- little endian = 0, big endian = 1
    Port ( 
            HCLK : in std_logic;                        -- Clock
         HRESETn : in std_logic;                        -- Asynchronous reset
  

            -- AMBA 3 AHB-LITE INTERFACE INPUTS
          HRDATA : in std_logic_vector (31 downto 0);   -- AHB read-data
          HREADY : in std_logic;                        -- AHB stall signal
           HRESP : in std_logic;                        -- AHB error response

            -- INTERRUPT INPUTS
             NMI : in std_logic;
             IRQ : in std_logic_vector (15 downto 0);
            
            -- EVENT INPUT
            RXEV : in std_logic;

            -- AMBA 3 AHB-LITE INTERFACE OUTPUTS
           HADDR : out std_logic_vector (31 downto 0);  -- AHB transaction address  format [Lower byte-Upper byte | Lower byte-Upper byte]
          HBURST : out std_logic_vector (2 downto 0);   -- AHB burst: tied to single
       HMASTLOCK : out std_logic;                       -- AHB locked transfer (always zero)
           HPROT : out std_logic_vector (3 downto 0);   -- AHB protection: priv; data or inst
           HSIZE : out std_logic_vector (2 downto 0);   -- AHB size: byte, half-word or word
          HTRANS : out std_logic_vector (1 downto 0);   -- AHB transfer: non-sequential only
          HWDATA : out std_logic_vector (31 downto 0);  -- AHB write-data
          HWRITE : out std_logic;                       -- AHB write control
            
            -- STATUS OUPUTS
        LOCKUP   : out std_logic;    
      SLEEPING   : out std_logic;    
   SYSTESETREQ   : out std_logic;    
            
            -- EVENT OUTPUT
          TXEV   : out std_logic
        );
end cortex_m0_core;

architecture Behavioral of cortex_m0_core is

    -- Components
    component registers is
    Port (
        clk : in std_logic;
        reset : in std_logic;
        WE : in std_logic;
        gp_WR_addr: in std_logic_vector(3 downto 0);
        gp_data_in : in std_logic_vector(31 downto 0);
        gp_addrA: in std_logic_vector(3 downto 0);
        gp_addrB: in std_logic_vector(3 downto 0);
        gp_ram_dataA : out std_logic_vector(31 downto 0);
        gp_ram_dataB : out std_logic_vector(31 downto 0)
    );
    end component;
    
    component decoder is
    Port ( 
        instruction : in std_logic_vector (15 downto 0);
        PC : in std_logic_vector (31 downto 0);
        instruction_size : out boolean;
        destination_is_PC : out std_logic;
        gp_WR_addr : out STD_LOGIC_VECTOR (3 downto 0);
        gp_addrA: out STD_LOGIC_VECTOR (3 downto 0);
        gp_addrB: out STD_LOGIC_VECTOR (3 downto 0);
        imm8: out STD_LOGIC_VECTOR (7 downto 0);
        execution_cmd: out executor_cmds_t;
        data_memory_addr: out  std_logic_vector (31 downto 0); 
        access_mem: out boolean
    );
    end component;
    
    component executor is
        Port (
             clk : in std_logic;
             reset : in std_logic;
             operand_A : in std_logic_vector(31 downto 0);	
             operand_B : in std_logic_vector(31 downto 0);	
             command: in executor_cmds_t;	
             imm8_z_ext : in  std_logic_vector(31 downto 0);
             destination_is_PC : in std_logic;
             current_flags : in flag_t;
             access_mem : in boolean;
             execute_mem_rw: in boolean;
             disable_executor : in boolean;
             cmd_out: out executor_cmds_t;
             set_flags : out boolean;
             PC_updated: out std_logic;
             result : out std_logic_vector(31 downto 0);
             alu_temp_32 : out std_logic;
             overflow_status : out std_logic_vector(2 downto 0);
             WE: out std_logic
         );
    end component;
    
    component core_state is
        Port (
            clk : in std_logic;
            reset : in std_logic;
            instruction_size : in boolean;      -- false = 16-bit (2 bytes), true = 32-bit (4 bytes) 
            access_mem : in boolean;
            PC : out std_logic_vector(31 downto 0);
            PC_decode : out std_logic_vector (31 downto 0);
            PC_execute :  out std_logic_vector (31 downto 0);
            execute_mem_rw : out boolean;
            disable_fetch : out boolean;
            haddr_ctrl : out boolean;
            disable_executor : out boolean;
            refetch : out boolean     
        );
    end component;
    
     component status_flags is
        Port (
            clk : in std_logic;
            reset : in std_logic;
            result : in std_logic_vector(31 downto 0);
            C_in : in std_logic;
            overflow_status : in std_logic_vector(2 downto 0);
            cmd: in executor_cmds_t;
            set_flags : in boolean; 
            flags_o : out flag_t
            );
    end component;
    
    -- Declare clock interface
    ATTRIBUTE X_INTERFACE_INFO : STRING;
    ATTRIBUTE X_INTERFACE_INFO of HCLK: SIGNAL is "xilinx.com:signal:clock:1.0 HCLK CLK";
    ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER of HCLK: SIGNAL is "ASSOCIATED_RESET HRESETn, FREQ_HZ 50000000";
    
    -- Declare reset interface
    ATTRIBUTE X_INTERFACE_INFO of HRESETn: SIGNAL is "xilinx.com:signal:reset:1.0 HRESETn RST";
    ATTRIBUTE X_INTERFACE_PARAMETER of HRESETn: SIGNAL is "POLARITY ACTIVE_HIGH";
			
	-- M0 Core signals 
    signal PC: std_logic_vector (31 downto 0);
    signal PC_decode:  std_logic_vector (31 downto 0);
    signal PC_execute:  std_logic_vector (31 downto 0);
	signal instruction_size : boolean;
	signal current_instruction: std_logic_vector (15 downto 0);
	signal enable_decode : std_logic;
	signal data_memory_addr : std_logic_vector (31 downto 0);
	signal data_memory_addr_value : std_logic_vector (31 downto 0);
	signal hrdata_progrm : std_logic_vector (31 downto 0);
	signal hrdata_progrm_value : std_logic_vector (31 downto 0);
	signal hrdata_data : std_logic_vector (31 downto 0);
	signal hrdata_data_value : std_logic_vector (31 downto 0);
	
	signal imm8_z_ext : std_logic_vector(31 downto 0) := (others => '0');			
	signal imm8_z_ext_value : std_logic_vector(31 downto 0);			

--    signal PC_aligned:  std_logic_vector (31 downto 0);
    signal internal_reset: std_logic := '1';
    signal thumb: std_logic := '0';
    signal valid: std_logic := '0';
    signal decode_phase : std_logic;     
    signal decode_phase_value : std_logic;     
  
    signal instA_access_mem : boolean;
    signal instB_access_mem : boolean;
    
	-- Registers after decoder
	signal gp_WR_addr : std_logic_vector(3 downto 0) := (others => '0');	
	signal gp_WR_addr_value : std_logic_vector(3 downto 0) := (others => '0');	
	signal gp_addrA : std_logic_vector(3 downto 0) := (others => '0');	
	signal gp_addrB : std_logic_vector(3 downto 0) := (others => '0');			
	signal gp_addrA_value : std_logic_vector(3 downto 0);			
	signal gp_addrB_value : std_logic_vector(3 downto 0);			
	signal gp_ram_dataA : std_logic_vector(31 downto 0);			
	signal gp_ram_dataB : std_logic_vector(31 downto 0);	
	signal gp_addrA_executor : std_logic_vector(31 downto 0);	
	signal gp_data_in : std_logic_vector(31 downto 0);	
    signal enable_execute : std_logic;
	signal enable_execute_value : std_logic;
    
    -- decoder signals
    signal imm8:  std_logic_vector (7 downto 0);
	signal WE :  std_logic;	
	signal use_PC:  boolean;
--	signal use_PC_value:  boolean;
    signal access_mem:  boolean;
    signal access_mem_value:  boolean;
   


	
	-- executor signals
    signal command:  executor_cmds_t := NOT_DEF;
    signal command_value:  executor_cmds_t := NOT_DEF;
    signal result:  std_logic_vector (31 downto 0);
	signal destination_is_PC :  std_logic := '0';	
	signal destination_is_PC_value :  std_logic := '0';	
	signal PC_updated : std_logic;	
	signal cmd_out : executor_cmds_t;	
	signal set_flags : boolean;
	signal mem_access_exec : boolean;
	signal alu_temp_32 : std_logic;
	signal overflow_status : std_logic_vector (2 downto 0);
	signal data_mem_addr_out : std_logic_vector (31 downto 0);
	signal executor_opernd_B : std_logic_vector (31 downto 0);
	
	-- core state signals
	signal m0_core_state: core_state_t; 
    signal m0_next_state : core_state_t;
    signal m0_previous_state : core_state_t;
    signal flags       :  flag_t;
    signal instr_ptr : std_logic;
    signal HADDR_out :  std_logic_vector (31 downto 0);
    signal execute_mem_rw : boolean;
    signal disable_fetch : boolean;
    signal haddr_ctrl : boolean;
    signal disable_executor : boolean;
    signal refetch : boolean;
    
    
    
    
    
    -- pipeline_invalidator signals
    

    -- aliases
    -- Little endian:
    -- [      inst A 1st half    ] [     inst A 2nd half     ] [    inst B 1st half    ]   [ inst B 2nd half ] 
    -- [31 30 29 28 - 27 26 25 24] [23 22 21 20 - 19 18 17 16] [15 14 13 12 - 11 10 9 8] - [7 6 5 4 - 3 2 1 0]
   --alias fetched_32_bit_instruction : std_logic_vector(31 downto 0) is hrdata_progrm (31 downto 0);
    
    
    
    alias inst_A_1st_half : std_logic_vector(7 downto 0) is hrdata_progrm (31 downto 24);
    alias inst_A_2nd_half : std_logic_vector(7 downto 0) is hrdata_progrm (23 downto 16);
    alias inst_B_1st_half : std_logic_vector(7 downto 0) is hrdata_progrm (15 downto 8);
    alias inst_B_2nd_half : std_logic_vector(7 downto 0) is hrdata_progrm (7 downto 0);
    
--    alias f32_inst_A_1st_half : std_logic_vector(7 downto 0) is fetched_32_bit_instruction (31 downto 24);
--    alias f32_inst_A_2nd_half : std_logic_vector(7 downto 0) is fetched_32_bit_instruction (23 downto 16);
--    alias f32_inst_B_1st_half : std_logic_vector(7 downto 0) is fetched_32_bit_instruction (15 downto 8);
--    alias f32_inst_B_2nd_half : std_logic_vector(7 downto 0) is fetched_32_bit_instruction (7 downto 0);
    
    

  
	
	-- Simulation signals  
	--synthesis translate off
    signal cortex_m0_opcode : string(1 to 16) := "                ";
    signal cortex_m0_status : string(1 to 18) := "NN,NZ,NC,NV, -----";
	--synthesis translate on
						
begin

    m0_registers: registers port map (
        clk => HCLK,
        reset => internal_reset,
        WE => WE,
        gp_WR_addr => gp_WR_addr, 
        gp_data_in => gp_data_in,
        gp_addrA => gp_addrA,
        gp_addrB => gp_addrB,
        gp_ram_dataA => gp_ram_dataA,
        gp_ram_dataB => gp_ram_dataB
    );
    
    m0_decoder: decoder port map ( 
        PC => PC_execute,
        instruction => current_instruction,
        instruction_size => instruction_size,
        destination_is_PC => destination_is_PC_value,
        gp_WR_addr => gp_WR_addr_value,
        gp_addrA => gp_addrA_value,
        gp_addrB => gp_addrB_value,
        imm8 => imm8,
        execution_cmd => command_value,
        data_memory_addr => data_memory_addr_value,
        access_mem => access_mem_value
        );
    
     m0_executor: executor port map (
             clk => HCLK,
             reset => internal_reset,
             operand_A => gp_addrA_executor,	
             operand_B => executor_opernd_B,	
             command => command, 	
             imm8_z_ext => imm8_z_ext,
             destination_is_PC => destination_is_PC,
             current_flags => flags,
             access_mem => access_mem,
             execute_mem_rw => execute_mem_rw, 
             disable_executor => disable_executor,
             cmd_out => cmd_out,
             set_flags => set_flags,
             PC_updated => PC_updated,
             result => result,
             alu_temp_32 => alu_temp_32,
             overflow_status => overflow_status,
             WE => WE
         );
         
      m0_core_state_m: core_state port map (
            clk => HCLK,
            reset => internal_reset,
            instruction_size => instruction_size,
            access_mem => access_mem_value,
            PC => PC,
            PC_decode => PC_decode,
            PC_execute => PC_execute,
            execute_mem_rw => execute_mem_rw,
            disable_fetch => disable_fetch,
            haddr_ctrl => haddr_ctrl,
            disable_executor => disable_executor,
            refetch => refetch
        ); 
        
     m0_core_flags: status_flags port map (
            clk => HCLK,
            reset => internal_reset,
            result => result,
            C_in => alu_temp_32,
            cmd => cmd_out,
            set_flags => set_flags,
            overflow_status => overflow_status,
            flags_o  => flags
        );
        
        
    HADDR_p : process (haddr_ctrl, data_memory_addr_value, PC(31 downto 2)) begin
        if (haddr_ctrl = true) then
            -- true = put data memory address on the bus, 
            HADDR <= data_memory_addr_value;
        else  
            -- false = put program memory address on the bus
            HADDR <= PC(31 downto 2) & B"00";  
        end if; 
    end process;    
        
        
 
        
    internal_reset_p: process (HCLK) begin
        if (rising_edge(HCLK)) then
            internal_reset <= not HRESETn;
        end if;
    end process;

    current_instruction_p: process (PC(1), hrdata_progrm) begin
     
            if (PC(1) = '0') then
                current_instruction <= hrdata_progrm(31 downto 16);    
            else    
                current_instruction <= hrdata_progrm(15 downto 0);    
            end if;
        
    end process;

    
--    PC_plus_2 <=  STD_LOGIC_VECTOR (unsigned (PC) + 2);
    
    decode_phase_p: process (HCLK) begin
        if (rising_edge(HCLK)) then
                decode_phase <= decode_phase_value;
        end if;
    end process;
    
    gp_addrA_executor_p: process (gp_ram_dataA, hrdata_data, access_mem, destination_is_PC, PC) begin
        if (access_mem = true) then       -- Desitinatination register is PC
            gp_addrA_executor <= hrdata_data;        
        else
            if (destination_is_PC = '1') then       -- Desitinatination register is PC
                gp_addrA_executor <= PC;        
            else
                gp_addrA_executor <= gp_ram_dataA;
            end if;
        end if;        
    end process;

    decode_phase_value_p: process (decode_phase) begin
        decode_phase_value <= not decode_phase;
    end process;
    
  
     
    hrdata_p: process (execute_mem_rw, HRDATA) begin
        if (execute_mem_rw = true) then
            hrdata_data_value <= HRDATA; 
        else   
            hrdata_progrm_value <= HRDATA;
        end if;    
    end process;
      
    gp_data_in_p: process (execute_mem_rw, hrdata_data_value, result) begin
        if (execute_mem_rw = true) then 
             gp_data_in <= hrdata_data_value;  
        else
             gp_data_in <= result;
        end if;   
    end process;
    
    executor_opernd_B_p: process (gp_ram_dataB, access_mem, PC) begin
        if (access_mem = true) then
             executor_opernd_B <= PC;  
        else
             executor_opernd_B <= gp_ram_dataB;
        end if;   
    end process;
    
   
    
--    pc_value_p: process  (m0_core_state, internal_reset, PC_updated, result, PC_plus_2,
--                            access_mem_value, PC, instA_access_mem, instB_access_mem) begin
--            case (m0_core_state) is
--                when s_RESET => PC_VALUE <= x"0000_0000";    -- zero    
--                when s_RUN =>   PC_VALUE <= x"0000_0000";
--                when s_FETCH_32_ALIGNED =>   PC_VALUE <= x"0000_0000";
----                when s_EXEC_INSTA =>
----                    if (PC_updated = '1') then
----                        PC_VALUE <= result;         -- Result
----                    else
----                        if (access_mem_value = true) then
----                            PC_VALUE <= PC; 
----                        else
----                            if (instB_access_mem = true) then
----                                PC_VALUE <= PC;
----                            else
----                                PC_VALUE <= PC_plus_4;      -- PC + 4
----                            end if;      
----                        end if;    
----                    end if;
----                when s_EXEC_INSTB => 
----                    if (PC_updated = '1') then
----                        PC_VALUE <= result;         -- Result
----                    else
----                        if (access_mem_value = true) then
----                            if (instA_access_mem = true) then
----                                PC_VALUE <= PC_plus_4;      -- PC + 4
----                            else
----                                if (instB_access_mem = true) then
----                                    PC_VALUE <= PC_plus_4;      -- PC + 4
----                                else
----                                    PC_VALUE <= PC;
----                                end if;    
----                            end if;      
----                        else
----                           PC_VALUE <= PC;  
----                        end if;

----                    end if;
----                when s_PC_UPDATED_INVALID =>        --PC_VALUE <= PC_VALUE;       -- No change
----                when s_EXEC_INSTA_INVALID =>        --PC_VALUE <= PC_VALUE;       -- No change
----                when s_EXEC_INSTB_INVALID =>        PC_VALUE <= PC_plus_4;      -- PC + 4
----                when s_PC_UNALIGNED =>              --PC_VALUE <= PC_VALUE;       -- No change
----                when s_REFETCH_INSTA =>             
----                        if (instB_access_mem = true) then
----                            PC_VALUE <= PC;
----                        else
----                            PC_VALUE <= PC_plus_4;      -- PC + 4  
----                        end if;     
----                when s_REFETCH_INSTB =>             --PC_VALUE <= PC_VALUE;       -- No change
                

--                when others =>                      PC_VALUE <= x"0000_0000"; 
--            end case;
--     end process;
    

--    Select_Inst_A_B_p: process  (internal_reset, m0_core_state, 
--                                 inst_A_2nd_half, inst_A_1st_half, inst_B_2nd_half, inst_B_1st_half,
--                                 f32_inst_A_2nd_half, f32_inst_A_1st_half, f32_inst_B_2nd_half, f32_inst_B_1st_half, access_mem) begin
--        if (internal_reset = '0') then  
--                if (S_PROGRAM_MEMORY_ENDIAN = FALSE) then 
--                    if (access_mem = true) then
--                        if (m0_core_state = s_EXEC_INSTA) then 
--                            current_instruction <= f32_inst_A_2nd_half & f32_inst_A_1st_half;
--                        elsif (m0_core_state = s_EXEC_INSTB) then
--                            current_instruction <= f32_inst_B_2nd_half & f32_inst_B_1st_half;
----                        else
----                            current_instruction <= (others => '0'); 
--                        end if;    
--                    else
--                        if (m0_core_state = s_EXEC_INSTA or 
--                            --m0_core_state = s_EXEC_INSTA_START or 
--                            m0_core_state = s_EXEC_INSTA_INVALID or
--                            m0_core_state = s_REFETCH_INSTA) then 
--                            current_instruction <= inst_A_2nd_half & inst_A_1st_half;
--                        elsif (m0_core_state = s_EXEC_INSTB or 
--                               m0_core_state = s_EXEC_INSTB_INVALID or
--                               m0_core_state = s_PC_UNALIGNED or 
--                               m0_core_state = s_REFETCH_INSTB) then
--                            current_instruction <= inst_B_2nd_half & inst_B_1st_half;
--                        else
--                            current_instruction <= (others => '0');    
--                        end if;
--                   end if;
--                else
--                    if (access_mem = true) then
--                        if (m0_core_state = s_EXEC_INSTA) then 
--                            current_instruction <= f32_inst_A_1st_half & f32_inst_A_2nd_half;
--                        elsif (m0_core_state = s_EXEC_INSTB) then
--                            current_instruction <= f32_inst_B_1st_half & f32_inst_B_2nd_half;
----                        else
----                            current_instruction <= (others => '0'); 
--                        end if;    
--                    else     
--                        if (m0_core_state = s_EXEC_INSTA or 
--                            --m0_core_state = s_EXEC_INSTA_START or 
--                            m0_core_state = s_EXEC_INSTA_INVALID or
--                            m0_core_state = s_REFETCH_INSTA) then 
--                            current_instruction <= inst_A_1st_half & inst_A_2nd_half;
--                        elsif (m0_core_state = s_EXEC_INSTB or 
--                               m0_core_state = s_EXEC_INSTB_INVALID or
--                               m0_core_state = s_PC_UNALIGNED or 
--                               m0_core_state = s_REFETCH_INSTB) then
--                            current_instruction <= inst_B_1st_half & inst_B_2nd_half;
--                        else
--                            current_instruction <= (others => '0'); 
--                        end if;
--                    end if;        
--                end if;
--            end if;    
--    end process;
    
    
    instB_access_mem_p: process (inst_A_1st_half, inst_A_2nd_half,  inst_B_1st_half, inst_B_2nd_half) begin
         if (S_PROGRAM_MEMORY_ENDIAN = FALSE) then  
            if (std_match(inst_A_2nd_half, "01001---")) then
                instB_access_mem <= true;
            else
                instB_access_mem <= false;
            end if;
            if (std_match(inst_B_2nd_half, "01001---")) then
                instB_access_mem <= true;
            else
                instB_access_mem <= false;
            end if;
         else
            if (std_match(inst_A_1st_half, "01001---")) then
                instA_access_mem <= true;
            else
                instA_access_mem <= false;
            end if;
            if (std_match(inst_B_1st_half, "01001---")) then
                instB_access_mem <= true;
            else
                instB_access_mem <= false;
            end if;
         end if;   
        end process;
    
    
     decoder_registers_p: process (HCLK, internal_reset) begin 
        if internal_reset = '1' then
            imm8_z_ext <= (others => '0');
            gp_WR_addr <= (others => '0');
            gp_addrA <= (others => '0');
            gp_addrB <= (others => '0');
            command <= NOP;    
            access_mem <= false;
            enable_execute <= '0';
            hrdata_data <= (others => '0');
            hrdata_progrm <= (others => '0');
            data_memory_addr <= (others => '0');
        else
            if (rising_edge(HCLK)) then
                    imm8_z_ext <= imm8_z_ext_value;
                    gp_WR_addr <= gp_WR_addr_value;
                    gp_addrA <= gp_addrA_value;
                    gp_addrB <= gp_addrB_value;
                    command <= command_value;
                if (refetch = false) then
                    access_mem <= access_mem_value;
                    enable_execute <= enable_execute_value;
                    hrdata_data <= hrdata_data_value; 
                    hrdata_progrm <= hrdata_progrm_value;
                    data_memory_addr <= data_memory_addr_value;
                end if;  
            end if;    
        end if;
    end process;

   
    
     imm8_z_ext_value_p: process  (command_value, imm8) begin
        case (command_value) is
            when MOVS_imm8 => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when ADDS_imm3 => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when ADDS_imm8 => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when SUBS_imm3 => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when SUBS_imm8 => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when CMP_imm8  => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when LDR_imm5  => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when LDR_imm8  => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when others  => imm8_z_ext_value <= (others => '0');
        end case;       
    end process;
    
    
 
  
                                        
--    fetched_32_bit_instruction_p: process (HCLK, HRDATA, m0_core_state, access_mem_value) begin
--         if (rising_edge(HCLK)) then
--            if (access_mem_value = true) then
--                fetched_32_bit_instruction <= HRDATA;  
--            end if;    
--        end if;   
--    end process;

    
--    PC_aligned <= PC & x"FFFF_FFFC";
   
    HBURST <= B"000";
    HMASTLOCK <= '0';
    HPROT <= B"0000";
    HPROT <= B"0000";
    HSIZE <= "000";
    HTRANS <= B"00";
    HWDATA <= (others => '0');
    HWRITE <= '0';

    

    -- Simulation related code
    --synthesis translate off
    
    simulation_status_p: process (HCLK, internal_reset, flags) 
    begin
      
        if rising_edge(HCLK) then 
            if internal_reset = '1' then
                cortex_m0_status <= "NN,NZ,NC,NV, Reset"; 
            else
                if (flags.N = '1') then cortex_m0_status(1 to 3)   <= " N,"; else cortex_m0_status(1 to 3)   <= "NN,"; end if;
                if (flags.Z = '1') then cortex_m0_status(4 to 6)   <= " Z,"; else cortex_m0_status(4 to 6)   <= "NZ,"; end if;
                if (flags.C = '1') then cortex_m0_status(7 to 9)   <= " C,"; else cortex_m0_status(7 to 9)   <= "NC,"; end if;
                if (flags.V = '1') then cortex_m0_status(10 to 12) <= " V,"; else cortex_m0_status(10 to 12) <= "NV,"; end if;
                cortex_m0_status(13 to 18) <= " ,Run ";
            end if;      
        end if;      
    end process;

    simulation_p: process (internal_reset, current_instruction)
        -- Variables for contents of each register in each bank
        -- variable sim_r0 : std_logic_vector(31 downto 0) := X"0000";
        variable     Rd_decode : string(1 to 2);   -- Rd register specification
        variable     Rm_decode : string(1 to 2);   -- Rd register specification
        variable     Rn_decode : string(1 to 2);   -- Rn register specification
        variable     imm8_decode : string(1 to 3);   -- immediate 8 specification
    begin  
        Rd_decode(1) := 'r';
        Rm_decode(1) := 'r';
        Rn_decode(1) := 'r';
        imm8_decode(1) :=  '#';
        
        -- [15 14 13 12 - 11 10 9 8] - [7 6 5 4 - 3 2 1 0]
        --if rising_edge(HCLK) then 
            if internal_reset = '1' then
                cortex_m0_opcode <= "CORE IS RESET!  ";
            else
                -------------------------------------------------------------------------------------- -- MOVS Rd, #(imm8)
                if std_match(current_instruction(15 downto 10), "00100-") then                      
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8));               
                    imm8_decode(2) :=  hexcharacter (current_instruction (7 downto 4));
                    imm8_decode(3) :=  hexcharacter (current_instruction (3 downto 0));
                    cortex_m0_opcode <= "MOVS " & Rd_decode & "," & imm8_decode & "     ";    
                -------------------------------------------------------------------------------------- -- MOVS <Rd>,<Rm>     
                elsif std_match(current_instruction(15 downto 6), "0000000000") then                 
                    Rd_decode(2) := hexcharacter (current_instruction (3 downto 0));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                    cortex_m0_opcode <= "MOVS " & Rd_decode & "," & Rm_decode & "      "; 
                -------------------------------------------------------------------------------------- -- MOV <Rd>,<Rm>  ,  MOV PC, Rm     
                elsif std_match(current_instruction(15 downto 8), "01000110") then                   
                    Rd_decode(2) := hexcharacter (current_instruction (7) & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter (current_instruction (6 downto 3));
                    cortex_m0_opcode <= "MOV  " & Rd_decode & "," & Rm_decode & "      ";    
                -------------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,#<imm3>
                elsif std_match(current_instruction(15 downto 9), "0001110") then                    
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    imm8_decode(3) :=   hexcharacter ('0' & current_instruction (8 downto 6));
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                    cortex_m0_opcode <= "ADDS " & Rd_decode & "," & Rn_decode & "," & imm8_decode & "  ";    
                -------------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,<Rm> 
                elsif std_match(current_instruction(15 downto 9), "0001100") then                   
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (8 downto 6));
                    cortex_m0_opcode <= "ADDS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "   ";    
                -------------------------------------------------------------------------------------- -- ADD <Rdn>,<Rm> - ADD PC,<Rm>
                elsif std_match(current_instruction(15 downto 8), "01000100") then                  
                    Rd_decode(2) := hexcharacter (current_instruction(7) & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter (current_instruction (6 downto 3));
                    cortex_m0_opcode <= "ADD  " & Rd_decode & "," & Rm_decode & "      ";    
                -------------------------------------------------------------------------------------- -- ADDS <Rdn>,#<imm8>
                elsif std_match(current_instruction(15 downto 11), "00110") then                      
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8));
                    imm8_decode(2) :=   hexcharacter (current_instruction (7 downto 4));
                    imm8_decode(3) :=   hexcharacter (current_instruction (3 downto 0));
                    cortex_m0_opcode <= "ADDS " & Rd_decode & "," & imm8_decode & "     ";    
                -------------------------------------------------------------------------------------- -- ADCS <Rdn>,<Rm>  
                elsif std_match(current_instruction(15 downto 6), "0100000101") then                
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                    cortex_m0_opcode <= "ADCS " & Rd_decode & "," & Rm_decode & "      ";   
                -------------------------------------------------------------------------------------- -- SUBS <Rd>,<Rn>,#<imm3>  
                elsif std_match(current_instruction(15 downto 9), "0001111") then                  
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    imm8_decode(3) :=   hexcharacter ('0' & current_instruction (8 downto 6));
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                    cortex_m0_opcode <= "SUBS " & Rd_decode & "," & Rn_decode & "," & imm8_decode & "  ";  
                -------------------------------------------------------------------------------------- -- SUBS <Rd>,<Rn>,<Rm>  
                elsif std_match(current_instruction(15 downto 9), "0001101") then                  
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (8 downto 6));    
                    cortex_m0_opcode <= "SUBS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "   ";   
                -------------------------------------------------------------------------------------- -- SUBS <Rdn>,#<imm8> 
                elsif std_match(current_instruction(15 downto 11), "00111") then                     
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8));
                    imm8_decode(2) :=   hexcharacter (current_instruction (7 downto 4));
                    imm8_decode(3) :=   hexcharacter (current_instruction (3 downto 0));
                    cortex_m0_opcode <= "SUBS " & Rd_decode & "," & imm8_decode & "     ";    
                -------------------------------------------------------------------------------------- -- SBCS <Rdn>,<Rm> 
                elsif std_match(current_instruction(15 downto 6), "0100000110") then                 
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                    cortex_m0_opcode <= "SBCS " & Rd_decode & "," & Rm_decode & "      ";   
                -------------------------------------------------------------------------------------- -- RSBS <Rd>,<Rn>,#0 
                elsif std_match(current_instruction(15 downto 6), "0100001001") then                 
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                    cortex_m0_opcode <= "RSBS " & Rd_decode & "," & Rn_decode & "      ";   
                -------------------------------------------------------------------------------------- -- MULS <Rdm>,<Rn>,<Rdm>
                elsif std_match(current_instruction(15 downto 6), "0100001101") then                
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                    cortex_m0_opcode <= "MULS " & Rd_decode & "," & Rn_decode & "," & Rd_decode & "   ";  
               -------------------------------------------------------------------------------------- -- CMP <Rn>,<Rm> T1
               elsif std_match(current_instruction(15 downto 6), "0100001010") then                
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                    cortex_m0_opcode <= "CMP  " & Rn_decode & "," & Rm_decode & "      ";   
               -------------------------------------------------------------------------------------- -- CMP <Rn>,<Rm> T2
               elsif std_match(current_instruction(15 downto 8), "01000101") then                
                    Rn_decode(2) := hexcharacter (current_instruction(7) & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter (current_instruction (6 downto 3));
                    cortex_m0_opcode <= "CMP  " & Rn_decode & "," & Rm_decode & "      ";   
               -------------------------------------------------------------------------------------- -- CMN <Rn>,<Rm> 
               elsif std_match(current_instruction(15 downto 6), "0100001011") then                
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                    cortex_m0_opcode <= "CMN  " & Rn_decode & "," & Rm_decode & "      ";   
               -------------------------------------------------------------------------------------- -- CMP <Rn>,#<imm8> 
               elsif std_match(current_instruction(15 downto 11), "00101") then                
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8));
                    imm8_decode(2) :=  hexcharacter (current_instruction (7 downto 4));
                    imm8_decode(3) :=  hexcharacter (current_instruction (3 downto 0));
                    cortex_m0_opcode <= "CMP  " & Rd_decode & "," & imm8_decode & "     "; 
               -------------------------------------------------------------------------------------- -- ANDS <Rdn>,<Rm>
               elsif std_match(current_instruction(15 downto 6), "0100000000") then                
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                    cortex_m0_opcode <= "ANDS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "   ";
               -------------------------------------------------------------------------------------- -- EORS <Rdn>,<Rm>
               elsif std_match(current_instruction(15 downto 6), "0100000001") then                
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                    cortex_m0_opcode <= "EORS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "   ";
               -------------------------------------------------------------------------------------- -- ORRS <Rdn>,<Rm>
               elsif std_match(current_instruction(15 downto 6), "0100001100") then                
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                    cortex_m0_opcode <= "ORRS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "   ";
               -------------------------------------------------------------------------------------- -- BICS <Rdn>,<Rm>
               elsif std_match(current_instruction(15 downto 6), "0100001110") then                
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                    cortex_m0_opcode <= "BICS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "   ";
               -------------------------------------------------------------------------------------- -- MVNS <Rd>,<Rm>
               elsif std_match(current_instruction(15 downto 6), "0100001111") then                
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                    cortex_m0_opcode <= "MVNS " & Rd_decode & "," & Rm_decode &  "      "; 
               -------------------------------------------------------------------------------------- -- TST <Rn>,<Rm>
               elsif std_match(current_instruction(15 downto 6), "0100001000") then                
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                    cortex_m0_opcode <= "TST  " & Rn_decode & "," & Rm_decode &  "      "; 
               -------------------------------------------------------------------------------------- -- RORS <Rdn>,<Rm>
               elsif std_match(current_instruction(15 downto 6), "0100000111") then                
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                    Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                    cortex_m0_opcode <= "RORS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "   ";
               -------------------------------------------------------------------------------------- -- LDR <Rt>, [<Rn>{,#<imm5>}]
               elsif std_match(current_instruction(15 downto 11), "01001") then                
                    Rd_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8)); --Rt 
                    imm8_decode(2) :=  hexcharacter (current_instruction (7 downto 4));
                    imm8_decode(3) :=  hexcharacter (current_instruction (3 downto 0));
                    cortex_m0_opcode <= "LDR  " & Rd_decode & ",[pc," & imm8_decode & "]";    
                  
               end if;
            end if;
       -- end if;
    end process;
 
 --synthesis translate on
      
end Behavioral;
