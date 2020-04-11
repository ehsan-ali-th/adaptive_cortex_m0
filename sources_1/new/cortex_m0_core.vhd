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
            HCLK : in STD_LOGIC;                        -- Clock
         HRESETn : in STD_LOGIC;                        -- Asynchronous reset
  

            -- AMBA 3 AHB-LITE INTERFACE INPUTS
          HRDATA : in STD_LOGIC_VECTOR (31 downto 0);   -- AHB read-data
          HREADY : in STD_LOGIC;                        -- AHB stall signal
           HRESP : in STD_LOGIC;                        -- AHB error response

            -- INTERRUPT INPUTS
             NMI : in STD_LOGIC;
             IRQ : in STD_LOGIC_VECTOR (15 downto 0);
            
            -- EVENT INPUT
            RXEV : in STD_LOGIC;

            -- AMBA 3 AHB-LITE INTERFACE OUTPUTS
           HADDR : out STD_LOGIC_VECTOR (31 downto 0);  -- AHB transaction address  format [Lower byte-Upper byte | Lower byte-Upper byte]
          HBURST : out STD_LOGIC_VECTOR (2 downto 0);   -- AHB burst: tied to single
       HMASTLOCK : out STD_LOGIC;                       -- AHB locked transfer (always zero)
           HPROT : out STD_LOGIC_VECTOR (3 downto 0);   -- AHB protection: priv; data or inst
           HSIZE : out STD_LOGIC_VECTOR (2 downto 0);   -- AHB size: byte, half-word or word
          HTRANS : out STD_LOGIC_VECTOR (1 downto 0);   -- AHB transfer: non-sequential only
          HWDATA : out STD_LOGIC_VECTOR (31 downto 0);  -- AHB write-data
          HWRITE : out STD_LOGIC;                       -- AHB write control
            
            -- STATUS OUPUTS
        LOCKUP   : out STD_LOGIC;    
      SLEEPING   : out STD_LOGIC;    
   SYSTESETREQ   : out STD_LOGIC;    
            
            -- EVENT OUTPUT
          TXEV   : out STD_LOGIC
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
        run : in std_logic; 
        instruction : in STD_LOGIC_VECTOR (15 downto 0);
        destination_is_PC : out std_logic;
        thumb : out std_logic;                               -- indicates wether the decoded instruction is 16-bit thumb or 32-bit  
        gp_WR_addr : out STD_LOGIC_VECTOR (3 downto 0);
        gp_addrA: out STD_LOGIC_VECTOR (3 downto 0);
        gp_addrB: out STD_LOGIC_VECTOR (3 downto 0);
        imm8: out STD_LOGIC_VECTOR (7 downto 0);
        execution_cmd: out executor_cmds_t
        --execution_cmd: out STD_LOGIC_VECTOR (4 downto 0)
    );
    end component;
    
    component executor is
        Port (
             clk : in std_logic;
             reset : in std_logic;
             run : in std_logic;
             operand_A : in std_logic_vector(31 downto 0);	
             operand_B : in std_logic_vector(31 downto 0);	
             command: in executor_cmds_t;	
             imm8_z_ext : in  std_logic_vector(31 downto 0);
             destination_is_PC : in std_logic;
             state: in core_state_t;
             PC_updated: out std_logic;
             result : out std_logic_vector(31 downto 0);
             WE: out std_logic
         );
    end component;
    
    component core_state is
        Port (
            clk : in std_logic;
            reset : in std_logic;
            run : in std_logic;
            PC_updated : in std_logic;
            PC_2bit_LSB :  std_logic_vector(1 downto 0);
            state : out core_state_t
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
			
	-- signals
	signal Select_Inst_A_B : std_logic;                        -- = 0 inst A, = 1, inst B 
	signal imm8_z_ext : std_logic_vector(31 downto 0) := (others => '0');			
	signal imm8_z_ext_value : std_logic_vector(31 downto 0);			
    signal PC:  STD_LOGIC_VECTOR (31 downto 0);
    signal PC_VALUE:  STD_LOGIC_VECTOR (31 downto 0);
    signal PC_plus_4:  STD_LOGIC_VECTOR (31 downto 0);
    signal internal_reset: std_logic := '1';
    signal run: std_logic := '0'; 
    signal load_current_inst_permitted: std_logic := '0'; 
    signal thumb: std_logic := '0';
    signal valid: std_logic := '0';
    signal decode_phase : std_logic;     
    signal decode_phase_value : std_logic;     
    signal PC_decode:  STD_LOGIC_VECTOR (31 downto 0);
    signal PC_execute:  STD_LOGIC_VECTOR (31 downto 0);
    
	-- Registers
	signal gp_WR_addr : std_logic_vector(3 downto 0) := (others => '0');	
	signal gp_WR_addr_value : std_logic_vector(3 downto 0) := (others => '0');	
	signal gp_addrA : std_logic_vector(3 downto 0) := (others => '0');	
	signal gp_addrB : std_logic_vector(3 downto 0) := (others => '0');			
	signal gp_addrA_value : std_logic_vector(3 downto 0);			
	signal gp_addrB_value : std_logic_vector(3 downto 0);			
	signal gp_ram_dataA : std_logic_vector(31 downto 0);			
	signal gp_ram_dataB : std_logic_vector(31 downto 0);	
	signal gp_addrA_executor : std_logic_vector(31 downto 0);	
    
    -- decoder signals
    signal imm8:  STD_LOGIC_VECTOR (7 downto 0);
	signal WE :  std_logic;	
	
	-- executor signals
    signal command:  executor_cmds_t := NOT_DEF;
    signal command_value:  executor_cmds_t := NOT_DEF;
    signal result:  STD_LOGIC_VECTOR (31 downto 0);
	signal destination_is_PC :  std_logic := '0';	
	signal destination_is_PC_value :  std_logic := '0';	
	signal PC_updated : std_logic;	
	
	
	-- core state signals
	signal m0_core_state: core_state_t; 
    
  

    -- aliases
    -- Little endian:
    -- [      inst A 1st half    ] [     inst A 2nd half     ] [    inst B 1st half    ]   [ inst B 2nd half ] 
    -- [31 30 29 28 - 27 26 25 24] [23 22 21 20 - 19 18 17 16] [15 14 13 12 - 11 10 9 8] - [7 6 5 4 - 3 2 1 0]
    alias inst_A_1st_half : STD_LOGIC_VECTOR(7 downto 0) is HRDATA (31 downto 24);
    alias inst_A_2nd_half : STD_LOGIC_VECTOR(7 downto 0) is HRDATA (23 downto 16);
    alias inst_B_1st_half : STD_LOGIC_VECTOR(7 downto 0) is HRDATA (15 downto 8);
    alias inst_B_2nd_half : STD_LOGIC_VECTOR(7 downto 0) is HRDATA (7 downto 0);

    signal current_instruction: STD_LOGIC_VECTOR (15 downto 0);
	
	-- Simulation signals  
	--synthesis translate off
    signal cortex_m0_opcode : string(1 to 14) := "              ";
    signal cortex_m0_status : string(1 to 18) := " N, Z, C, V, -----";
	--synthesis translate on
					
						
begin

    m0_registers: registers port map (
        clk => HCLK,
        reset => internal_reset,
        WE => WE,
        gp_WR_addr => gp_WR_addr, 
        gp_data_in => result,
        gp_addrA => gp_addrA,
        gp_addrB => gp_addrB,
        gp_ram_dataA => gp_ram_dataA,
        gp_ram_dataB => gp_ram_dataB
    );
    
    m0_decoder: decoder port map ( 
        run => run,
        instruction => current_instruction,
        destination_is_PC => destination_is_PC_value,
        thumb => thumb,
        gp_WR_addr => gp_WR_addr_value,
        gp_addrA => gp_addrA_value,
        gp_addrB => gp_addrB_value,
        imm8 => imm8,
        execution_cmd => command_value
        );
    
     m0_executor: executor port map (
             clk => HCLK,
             reset => internal_reset,
             run => run,
             operand_A => gp_addrA_executor,	
             operand_B => gp_ram_dataB,	
             command => command, 	
             imm8_z_ext => imm8_z_ext,
             destination_is_PC => destination_is_PC,
             state => m0_core_state,
             PC_updated => PC_updated,
             result => result,
             WE => WE
         );
         
    m0_core_state_m: core_state port map (
            clk => HCLK,
            reset => internal_reset,
            run => run,
            PC_updated => PC_updated,
            PC_2bit_LSB => PC(1 downto 0),
            state => m0_core_state
        ); 
    
    internal_reset_p: process (HCLK) begin
        if (rising_edge(HCLK)) then
            internal_reset <= not HRESETn;
            load_current_inst_permitted <= run; 
        end if;
    end process;


     run_p: process (HCLK) begin
        if (rising_edge(HCLK)) then    
            run <= not internal_reset;
        end if;    
     end process;       
    
     -- Drives the PC   
    drive_pc_p: process (HCLK) begin
        if (rising_edge(HCLK)) then
            PC <= PC_value;
            PC_decode <= PC;
            PC_execute <= PC_decode;
        end if;
    end process;
    
    PC_plus_4 <=  STD_LOGIC_VECTOR (unsigned (PC) + 4);
    
    decode_phase_p: process (HCLK) begin
        if (rising_edge(HCLK)) then
            if (run = '1') then
                decode_phase <= decode_phase_value;
            else
                decode_phase <= '0';
            end if;    
        end if;
    end process;
    
    gp_addrA_executor_p: process (PC_execute, destination_is_PC, gp_ram_dataA) begin
        if (destination_is_PC = '1') then       -- Desitinatination register is PC
            gp_addrA_executor <= PC_execute;        
        else
            gp_addrA_executor <= gp_ram_dataA;
        end if;    
    end process;

    decode_phase_value_p: process (decode_phase) begin
                decode_phase_value <= not decode_phase;
    end process;
    
    pc_value_p: process  (HCLK) begin
        if (rising_edge(HCLK)) then
            case (m0_core_state) is
                when s_RESET =>   
                    if (internal_reset = '1') then
                        PC_VALUE <= x"0000_0000";    -- zero    
                    else 
                        if (run = '1') then 
                            PC_VALUE <= x"0000_0004";    -- 4
                        else
                            PC_VALUE <= x"0000_0000";    -- 4
                        end if;    
                    end if;    
                when s_EXEC_INSTA_START =>      PC_VALUE <= x"0000_0004";
                when s_EXEC_INSTA =>
                    if (PC_updated = '1') then
                        PC_VALUE <= result;         -- Result
                    else
                        PC_VALUE <= PC_VALUE;       -- No change  
                    end if;
                when s_EXEC_INSTB => 
                    if (PC_updated = '1') then
                        PC_VALUE <= result;         -- Result
                    else
                        PC_VALUE <= PC_plus_4;      -- PC + 4
                    end if;
                when s_PC_UPDATED_INVALID =>    PC_VALUE <= PC_VALUE;       -- No change
                when s_EXEC_INSTA_INVALID =>    PC_VALUE <= PC_VALUE;       -- No change
                when s_EXEC_INSTB_INVALID =>    PC_VALUE <= PC_plus_4;      -- PC + 4
                when others =>                  PC_VALUE <= x"0000_0000"; 
            end case;
         end if;
     end process;
    

    Select_Inst_A_B_p: process  (internal_reset, run, m0_core_state, inst_A_2nd_half, inst_A_1st_half, inst_B_2nd_half, inst_B_1st_half) begin
        if (internal_reset = '0') then  
            if (run = '1') then  
                if (S_PROGRAM_MEMORY_ENDIAN = FALSE) then 
                    if (m0_core_state = s_EXEC_INSTA or m0_core_state = s_EXEC_INSTA_START or m0_core_state = s_EXEC_INSTA_INVALID) then 
                        current_instruction <= inst_A_2nd_half & inst_A_1st_half;
                    elsif (m0_core_state = s_EXEC_INSTB or m0_core_state = s_EXEC_INSTB_INVALID or m0_core_state = s_PC_UNALIGNED) then
                        current_instruction <= inst_B_2nd_half & inst_B_1st_half;
                    else
                        current_instruction <= (others => '0');    
                    end if;
                else
                    if (m0_core_state = s_EXEC_INSTA or m0_core_state = s_EXEC_INSTA_START or m0_core_state = s_EXEC_INSTA_INVALID) then 
                        current_instruction <= inst_A_1st_half & inst_A_2nd_half;
                    elsif (m0_core_state = s_EXEC_INSTB or m0_core_state = s_EXEC_INSTB_INVALID or m0_core_state = s_PC_UNALIGNED) then
                        current_instruction <= inst_B_1st_half & inst_B_2nd_half;
                    else
                        current_instruction <= (others => '0'); 
                    end if;
                end if;
            end if;    
        end if;
    end process;
    
     regs_p: process (HCLK) begin 
        if (rising_edge(HCLK)) then
            if (internal_reset = '0') then
                imm8_z_ext <= imm8_z_ext_value;
                gp_WR_addr <= gp_WR_addr_value;
                gp_addrA <= gp_addrA_value;
                gp_addrB <= gp_addrB_value;
                command <= command_value;
                destination_is_PC <= destination_is_PC_value;
            end if;
        end if;
    end process;

   
    
     imm8_z_ext_value_p: process  (command_value, imm8) begin
        case (command_value) is
            when MOVS_imm8 => imm8_z_ext_value <= B"0000_0000_0000_0000_0000_0000" & imm8;  -- Zero extend
            when ADDS_imm3 => imm8_z_ext_value <= B"0000_0000_0000_0000_0000_0000" & imm8;  -- Zero extend
            when ADDS_imm8 => imm8_z_ext_value <= B"0000_0000_0000_0000_0000_0000" & imm8;  -- Zero extend
            when others  => imm8_z_ext_value <= (others => '0');
        end case;       
    end process;
    
    HADDR <= PC;
    HTRANS <= B"10";

    

    -- Simulation related code
    --synthesis translate off
    
    simulation_p: process (HCLK, internal_reset, HRDATA, Select_inst_A_B, current_instruction) 
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
            if std_match(current_instruction(15 downto 10), "00100-") then                      -- MOVS Rd, #(imm8)
                Rd_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8));               
                imm8_decode(2) :=  hexcharacter (current_instruction (7 downto 4));
                imm8_decode(3) :=  hexcharacter (current_instruction (3 downto 0));
                cortex_m0_opcode <= "MOVS " & Rd_decode & "," & imm8_decode & "   ";    
            elsif std_match(current_instruction(15 downto 6), "0000000000") then                -- MOVS <Rd>,<Rm>   
                Rd_decode(2) := hexcharacter (current_instruction (3 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                cortex_m0_opcode <= "MOVS " & Rd_decode & "," & Rm_decode & "    ";    
            elsif std_match(current_instruction(15 downto 8), "01000110") then                  -- MOV <Rd>,<Rm>  ,  MOV PC, Rm 
                Rd_decode(2) := hexcharacter (current_instruction (7) & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter (current_instruction (6 downto 3));
                cortex_m0_opcode <= "MOV  " & Rd_decode & "," & Rm_decode & "    ";    
            elsif std_match(current_instruction(15 downto 9), "0001110") then                  -- ADDS <Rd>,<Rn>,#<imm3>  
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                imm8_decode(3) :=   hexcharacter ('0' & current_instruction (8 downto 6));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                cortex_m0_opcode <= "ADDS " & Rd_decode & "," & Rn_decode & "," & imm8_decode;    
            elsif std_match(current_instruction(15 downto 9), "0001100") then                  -- ADDS <Rd>,<Rn>,<Rm>  
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (8 downto 6));
                cortex_m0_opcode <= "ADDS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & " ";    
            elsif std_match(current_instruction(15 downto 8), "01000100") then                  -- ADD <Rdn>,<Rm> - ADD PC,<Rm>
                Rd_decode(2) := hexcharacter (current_instruction(7) & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter (current_instruction (6 downto 3));
                cortex_m0_opcode <= "ADD  " & Rd_decode & "," & Rm_decode & "    ";    
            elsif std_match(current_instruction(15 downto 11), "00110") then                    -- ADDS <Rdn>,#<imm8>  
                Rd_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8));
                imm8_decode(2) :=   hexcharacter (current_instruction (7 downto 4));
                imm8_decode(3) :=   hexcharacter (current_instruction (3 downto 0));
                cortex_m0_opcode <= "ADDS " & Rd_decode & "," & imm8_decode & "   ";    
            elsif std_match(current_instruction(15 downto 6), "0100000101") then                -- ADCS <Rdn>,<Rm>  
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                cortex_m0_opcode <= "ADCS " & Rd_decode & "," & Rm_decode & "    ";    
            end if;
            
          if rising_edge(HCLK) then 
            if internal_reset = '1' then
                cortex_m0_status(13 to 18) <= ",Reset";
            else
                cortex_m0_status(13 to 18) <= "      ";
            end if;
        end if;
    end process;
 --synthesis translate on
      
end Behavioral;
