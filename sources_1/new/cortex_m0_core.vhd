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
        instruction_size : out boolean;
        destination_is_PC : out boolean;
        gp_WR_addr : out STD_LOGIC_VECTOR (3 downto 0);
        gp_addrA: out STD_LOGIC_VECTOR (3 downto 0);
        gp_addrB: out STD_LOGIC_VECTOR (3 downto 0);
        imm8: out STD_LOGIC_VECTOR (7 downto 0);
        execution_cmd: out executor_cmds_t;
        access_mem: out boolean;
        use_base_register : out boolean;
        mem_load_size : out mem_op_size_t;
        mem_load_sign_ext : out boolean;
        LDM_access_mem : out boolean;
        access_mem_mode : out access_mem_mode_t
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
             destination_is_PC : in boolean;
             current_flags : in flag_t;
             access_mem : in boolean;
             gp_data_in_ctrl : in gp_data_in_ctrl_t;
             disable_executor : in boolean;
             cmd_out: out executor_cmds_t;
             set_flags : out boolean;
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
            PC_updated : in boolean;
            imm8 : in std_logic_vector (7 downto 0);
            number_of_ones_initial : in  STD_LOGIC_VECTOR (3 downto 0);
            execution_cmd : in executor_cmds_t;
            LDM_access_mem : in boolean;
            new_PC : in std_logic_vector (31 downto 0);
            access_mem_mode : IN access_mem_mode_t;
            PC : out std_logic_vector(31 downto 0);
            PC_decode : out std_logic_vector (31 downto 0);
            PC_execute :  out std_logic_vector (31 downto 0);
            PC_after_execute :  out std_logic_vector (31 downto 0);
            LDM_mem_address_index :  out unsigned (4 downto 0); 
            gp_data_in_ctrl : out gp_data_in_ctrl_t;
            disable_fetch : out boolean;
            haddr_ctrl : out haddr_ctrl_t; 
            disable_executor : out boolean;
            gp_addrA_executor_ctrl : out boolean;
            LDM_W_reg : out std_logic_vector (3 downto 0);
            LDM_capture_base : out boolean;
            HWRITE : out std_logic
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
    
     component count_ones is
        Port ( byte_in : in STD_LOGIC_VECTOR (7 downto 0);
               ones : out STD_LOGIC_VECTOR (3 downto 0));
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
    signal PC_after_execute:  std_logic_vector (31 downto 0);
	signal instruction_size : boolean;
	signal current_instruction: std_logic_vector (15 downto 0);
	signal enable_decode : std_logic;
	signal data_memory_addr : std_logic_vector (31 downto 0);
	signal data_memory_addr_value : std_logic_vector (31 downto 0);
	signal hrdata_progrm : std_logic_vector (31 downto 0);
	signal hrdata_progrm_value : std_logic_vector (31 downto 0);
	signal hrdata_data : std_logic_vector (31 downto 0);
	signal hrdata_data_value : std_logic_vector (31 downto 0);
	signal hrdata_data_value_sized : std_logic_vector (31 downto 0);
	signal hrdata_data_value_16_sized : std_logic_vector (15 downto 0);
	signal ldm_hrdata_value : std_logic_vector (31 downto 0);
	signal LDM_mem_address_index : unsigned (4 downto 0);
	signal LDM_mem_addr : unsigned (31 downto 0);

	signal imm8_z_ext : std_logic_vector(31 downto 0) := (others => '0');			
	signal imm8_z_ext_value : std_logic_vector(31 downto 0);			

    signal internal_reset: std_logic := '1';
    signal thumb: std_logic := '0';
    signal valid: std_logic := '0';
   
	-- Registers after decoder
	signal gp_WR_addr : std_logic_vector(3 downto 0) := (others => '0');	
	signal gp_WR_addr_value : std_logic_vector(3 downto 0) := (others => '0');	
	signal gp_WR_addr_final : std_logic_vector(3 downto 0) := (others => '0');	
	signal gp_addrA : std_logic_vector(3 downto 0) := (others => '0');	
	signal gp_addrB : std_logic_vector(3 downto 0) := (others => '0');			
	signal gp_addrA_value : std_logic_vector(3 downto 0);			
	signal gp_addrB_value : std_logic_vector(3 downto 0);			
	signal gp_addrB_final : std_logic_vector(3 downto 0);			
	signal gp_ram_dataA : std_logic_vector(31 downto 0);			
	signal gp_ram_dataB : std_logic_vector(31 downto 0);	
	signal gp_addrA_executor : std_logic_vector(31 downto 0);	
	signal gp_data_in : std_logic_vector(31 downto 0);	
   
    -- decoder signals
    signal imm8 : std_logic_vector (7 downto 0);
	signal WE : std_logic;	
	signal use_PC : boolean;
    signal access_mem : boolean;
    signal access_mem_value : boolean;
	signal PC_updated : boolean;	
	signal use_base_register : boolean;	
	signal mem_load_size : mem_op_size_t;	
	signal mem_load_size_value : mem_op_size_t;	
	signal mem_load_sign_ext : boolean;
	signal mem_load_sign_ext_value : boolean;
	signal LDM_access_mem : boolean;
	signal LDM_access_mem_value : boolean;
	signal access_mem_mode : access_mem_mode_t;
	

	-- executor signals
    signal command:  executor_cmds_t := NOT_DEF;
    signal command_value:  executor_cmds_t := NOT_DEF;
    signal result:  std_logic_vector (31 downto 0);
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
    signal disable_fetch : boolean;
    signal gp_data_in_ctrl : gp_data_in_ctrl_t;
    signal haddr_ctrl : haddr_ctrl_t;
    signal disable_executor : boolean;
    signal gp_addrA_executor_ctrl : boolean;
    signal LDM_W_reg :std_logic_vector (3 downto 0);
    signal LDM_capture_base : boolean;
    
   
    signal data_memory_addr_i : unsigned (31 downto 0);
    signal LDR_mul_result : unsigned (7 downto 0);
    signal LDR_mul_result_value : unsigned (7 downto 0);
    signal LDR_multiplier : unsigned (7 downto 0);
    signal base_reg_content : std_logic_vector (31 downto 0);
    signal base_reg_content_LDM : std_logic_vector (31 downto 0);
    signal mem_index_content : std_logic_vector (31 downto 0);
    signal forward_alu_result : boolean;
  
    
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
    
     signal number_of_ones_initial :  STD_LOGIC_VECTOR (3 downto 0);
     signal LDM_total_bytes_read :  STD_LOGIC_VECTOR (4 downto 0);    -- cannot exceed 7 * 4 = 28 bytes
  
	
	-- Simulation signals  
	--synthesis translate off
    signal cortex_m0_opcode : string(1 to 17) := "                 ";
    signal cortex_m0_status : string(1 to 18) := "NN,NZ,NC,NV, -----";
	--synthesis translate on
						
begin

    m0_registers: registers port map (
        clk => HCLK,
        reset => internal_reset,
        WE => WE,
        gp_WR_addr => gp_WR_addr_final, 
        gp_data_in => gp_data_in,
        gp_addrA => gp_addrA,
        gp_addrB => gp_addrB_final,
        gp_ram_dataA => gp_ram_dataA,
        gp_ram_dataB => gp_ram_dataB
    );
    
    m0_decoder: decoder port map ( 
        instruction => current_instruction,
        instruction_size => instruction_size,
        destination_is_PC => PC_updated,
        gp_WR_addr => gp_WR_addr_value,
        gp_addrA => gp_addrA_value,
        gp_addrB => gp_addrB_value,
        imm8 => imm8,
        execution_cmd => command_value,
        access_mem => access_mem_value,
        use_base_register => use_base_register,
        mem_load_size => mem_load_size_value,
        mem_load_sign_ext => mem_load_sign_ext_value,
        LDM_access_mem => LDM_access_mem_value,
        access_mem_mode => access_mem_mode
        );
    
     m0_executor: executor port map (
         clk => HCLK,
         reset => internal_reset,
         operand_A => gp_addrA_executor,	
         operand_B => executor_opernd_B,	
         command => command, 	
         imm8_z_ext => imm8_z_ext,
         destination_is_PC => PC_updated,
         current_flags => flags,
         access_mem => access_mem,
         gp_data_in_ctrl => gp_data_in_ctrl, 
         disable_executor => disable_executor,
         cmd_out => cmd_out,
         set_flags => set_flags,
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
        PC_updated => PC_updated,
        imm8 => imm8_z_ext(7 downto 0),
        number_of_ones_initial => number_of_ones_initial,
        execution_cmd => command_value,
        LDM_access_mem => LDM_access_mem,
        new_PC => result, 
        access_mem_mode => access_mem_mode,
        PC => PC,
        PC_decode => PC_decode,
        PC_execute => PC_execute,
        PC_after_execute => PC_after_execute,
        LDM_mem_address_index => LDM_mem_address_index,
        gp_data_in_ctrl => gp_data_in_ctrl,
        disable_fetch => disable_fetch,
        haddr_ctrl => haddr_ctrl,
        disable_executor => disable_executor,
        gp_addrA_executor_ctrl => gp_addrA_executor_ctrl,
        LDM_W_reg => LDM_W_reg,
        LDM_capture_base => LDM_capture_base,
        HWRITE => HWRITE
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
        
     m0_count_ones: count_ones port map ( 
        byte_in => imm8_z_ext(7 downto 0),
        ones => number_of_ones_initial
        );    
        
    LDM_total_bytes_read <= std_logic_vector (shift_left(unsigned('0' & number_of_ones_initial), 2)); --     
        
    ---------------------------------------------------------------------------------------
    --- Hardware which drives (Cortex-M0) module input/ouput pins
    ---------------------------------------------------------------------------------------    
    
    HWDATA <= gp_ram_dataB;
    
    HSIZE_p : process (mem_load_size) begin
        case (mem_load_size) is
            when WORD           =>  HSIZE <= "010";
            when HALF_WORD      =>  HSIZE <= "001";  
            when BYTE           =>  HSIZE <= "000";  
            when others         =>   null;  
        end case; 
    end process;   
        
    HADDR_p : process (LDM_access_mem, haddr_ctrl, data_memory_addr, data_memory_addr_i, PC(31 downto 2), LDM_mem_addr) begin
        case (haddr_ctrl) is
            when sel_PC     =>  HADDR <= PC(31 downto 2) & B"00";  
            when sel_DATA   =>  HADDR <= data_memory_addr;
            when sel_LDM    =>  HADDR <= std_logic_vector (LDM_mem_addr);
            when sel_WDATA  =>  HADDR <= std_logic_vector (data_memory_addr_i);
        end case;
    end process;   
   
   LDM_mem_addr <= (unsigned (base_reg_content_LDM) + LDM_mem_address_index) and x"FFFF_FFFE";     -- gp_ram_dataA holds the base value (Rn)
    
    internal_reset_p: process (HCLK) begin
        if (rising_edge(HCLK)) then
            internal_reset <= not HRESETn;
        end if;
    end process;

    HBURST <= B"000";
    HMASTLOCK <= '0';
    HPROT <= B"0000";
    HPROT <= B"0000";
    HTRANS <= B"00";
    
    
        
    ---------------------------------------------------------------------------------------
    --- Hardware which drives (Executor) module input pins
    ---------------------------------------------------------------------------------------
    
    gp_addrA_executor_p: process (gp_ram_dataA, hrdata_data, access_mem, 
                                  gp_addrA_executor_ctrl, PC_after_execute) begin
        if (access_mem = true) then       -- Desitinatination register is PC
            gp_addrA_executor <= hrdata_data;        
        else
            if (gp_addrA_executor_ctrl = true) then       -- Desitinatination register is PC
                gp_addrA_executor <= PC_after_execute;        
            else
                gp_addrA_executor <= gp_ram_dataA;
            end if;
        end if;        
    end process;

    executor_opernd_B_p: process (gp_ram_dataB, access_mem, PC) begin
        if (access_mem = true) then
             executor_opernd_B <= PC;  
        else
             executor_opernd_B <= gp_ram_dataB;
        end if;   
    end process; 
    
    ---------------------------------------------------------------------------------------
    --- Hardware which drives (Register) module input pins
    ---------------------------------------------------------------------------------------
    
     gp_WR_addr_final_p: process (LDM_access_mem, LDM_W_reg, gp_WR_addr, disable_executor, gp_AddrA) begin
         if (LDM_access_mem = true) then
            if (disable_executor = true) then 
                gp_WR_addr_final <= gp_AddrA;       -- Save the Rn in LDM instruction into gp_AddrA register.
            else 
                gp_WR_addr_final <= LDM_W_reg;
            end if;  
         else
            gp_WR_addr_final <= gp_WR_addr;
         end if;   
    end process;
    
     gp_data_in_p: process (gp_data_in_ctrl, result, hrdata_data_value_sized, ldm_hrdata_value, LDM_total_bytes_read, gp_ram_dataA) begin
        case (gp_data_in_ctrl) is 
            when ALU_RESULT         => gp_data_in <= result;
            when HRDATA_VALUE_SIZED => gp_data_in <= hrdata_data_value_sized;  
            when LDM_DATA           => gp_data_in <= ldm_hrdata_value;
            when LDM_Rn             => gp_data_in <= std_logic_vector (unsigned (gp_ram_dataA) + unsigned (LDM_total_bytes_read));
            when others             => gp_data_in <= (others => '0'); report " gp_data_in error" severity failure;
        end case;
    end process;
    
      gp_addrB_p: process (use_base_register, gp_addrB_value, gp_addrB) begin
        if (use_base_register = true) then 
             gp_addrB_final <= gp_addrB_value;  
        else
             gp_addrB_final <= gp_addrB;
        end if;   
    end process;
    
    hrdata_data_value_sized_p: process (mem_load_size, mem_load_sign_ext, hrdata_data_value, 
                                        hrdata_data_value_16_sized, data_memory_addr_i(1 downto 0)) 
        variable case_sel: unsigned (1 downto 0);
    begin
        case_sel := data_memory_addr_i (1 downto 0);
        case (mem_load_size) is
            when WORD       => hrdata_data_value_sized <= hrdata_data_value;
            when HALF_WORD  => 
                if (mem_load_sign_ext = true) then
                    if (hrdata_data_value_16_sized(15) = '1') then
                        -- negative sign extension
                        hrdata_data_value_sized <= x"FFFF" & hrdata_data_value_16_sized;    
                    else
                        hrdata_data_value_sized <= x"0000" & hrdata_data_value_16_sized;
                    end if;        
                else
                    hrdata_data_value_sized <= x"0000" & hrdata_data_value_16_sized;
                end if;
            when BYTE       =>
                if (mem_load_sign_ext = true) then
                    case (case_sel) is
                        when B"00" => hrdata_data_value_sized <=  x"0000_00" & hrdata_data_value (7 downto 0);
                        when B"01" => hrdata_data_value_sized <=  x"0000_00" & hrdata_data_value (15 downto 8);
                        when B"10" => hrdata_data_value_sized <=  x"0000_00" & hrdata_data_value (23 downto 16);
                        when B"11" => hrdata_data_value_sized <=  x"0000_00" & hrdata_data_value (31 downto 24);
                        when others =>
                            null;
                    end case;   
                else
                    case (case_sel) is
                        when B"00" => 
                            if (hrdata_data_value(7) = '0') then 
                                hrdata_data_value_sized <=  x"0000_00" & hrdata_data_value (7 downto 0);
                            else
                                hrdata_data_value_sized <=  x"FFFF_FF" & hrdata_data_value (7 downto 0);
                            end if;
                        when B"01" =>
                            if (hrdata_data_value(15) = '0') then 
                                hrdata_data_value_sized <=  x"0000_00" & hrdata_data_value (15 downto 8);
                            else
                                hrdata_data_value_sized <=  x"FFFF_FF" & hrdata_data_value (15 downto 8);
                            end if;
                        when B"10" => 
                            if (hrdata_data_value(23) = '0') then 
                                hrdata_data_value_sized <=  x"0000_00" & hrdata_data_value (23 downto 16);
                            else
                                hrdata_data_value_sized <=  x"FFFF_FF" & hrdata_data_value (23 downto 16);
                            end if;   
                        when B"11" => 
                            if (hrdata_data_value(31) = '0') then 
                                hrdata_data_value_sized <=  x"0000_00" & hrdata_data_value (31 downto 24);
                            else
                                hrdata_data_value_sized <=  x"FFFF_FF" & hrdata_data_value (31 downto 24);
                            end if;   
                        when others =>
                            null;
                    end case;  
                end if;
            when NOT_DEF    => hrdata_data_value_sized <= hrdata_data_value;
        end case;
    end process;

    hrdata_data_value_16_sized_p: process (hrdata_data_value, data_memory_addr_i(1)) begin
        if (data_memory_addr_i(1) = '1') then
            hrdata_data_value_16_sized <= hrdata_data_value (31 downto 16);      -- High Half Word
        else
            hrdata_data_value_16_sized <= hrdata_data_value (15 downto 0);       -- Low Half Word
        end if;    
    end process;
    
   
   

    
    ---------------------------------------------------------------------------------------
    --- Hardware which drives (Decoder)
    ---------------------------------------------------------------------------------------     
    current_instruction_p: process (PC(1), hrdata_progrm) begin
        if (PC(1) = '0') then
            current_instruction <= hrdata_progrm(31 downto 16);    
        else    
            current_instruction <= hrdata_progrm(15 downto 0);    
        end if;
    end process;

    hrdata_p: process (gp_data_in_ctrl, HRDATA) begin
        case (gp_data_in_ctrl) is 
            when ALU_RESULT         => hrdata_progrm_value <= HRDATA;
            when HRDATA_VALUE_SIZED => hrdata_data_value <= HRDATA; 
            when LDM_DATA           => ldm_hrdata_value <= HRDATA; 
            when LDM_Rn             => hrdata_progrm_value <= HRDATA;
            when others             => hrdata_progrm_value <= HRDATA; report " hrdata demux error." severity failure;
        end case;
    end process;
    
    imm8_z_ext_value_p: process  (command_value, imm8) begin
        case (command_value) is
            when MOVS_imm8   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when ADDS_imm3   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when ADDS_imm8   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when SUBS_imm3   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when SUBS_imm8   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when CMP_imm8    => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when LSLS_imm5   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when LSRS_imm5   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when ASRS_imm5   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when LDR_imm5    => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when LDRH_imm5   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when LDRB_imm5   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when LDR_label   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when LDM         => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when STR_imm5    => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when STRH_imm5   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when STRB_imm5   => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when STR_SP_imm8 => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when STM         => imm8_z_ext_value <= x"0000_00" & imm8;  -- Zero extend
            when others  => imm8_z_ext_value <= (others => '0');
        end case;       
    end process; 
    
    -- data_memory_addr_value
    ----------------------------------------------------------------------------------------  
    LDR_multiplier_p: process (mem_load_size_value) begin
         case (mem_load_size_value) is
            when WORD       => LDR_multiplier <= x"02";
            when HALF_WORD  => LDR_multiplier <= x"01";
            when BYTE       => LDR_multiplier <= x"00";
            when NOT_DEF    => LDR_multiplier <= x"02";
        end case;
    end process;
    
    LDR_mul_result_value_p: process (command_value, imm8, LDR_multiplier, mem_index_content(7 downto 0), 
                                     PC_execute, LDR_mul_result_value) begin
        case (command_value) is
            when LDR_imm5 | LDRH_imm5 | LDRB_imm5 | LDR_label | STR_imm5 | STRH_imm5 | STRB_imm5  => 
                LDR_mul_result_value <= shift_left (unsigned (imm8), to_integer(LDR_multiplier));
            when LDR | LDRH | LDRSH | LDRB | LDRSB =>
                LDR_mul_result_value <= shift_left (unsigned (mem_index_content(7 downto 0)), to_integer(LDR_multiplier));     
            when others =>
                        null;    
        end case;
    end process; 
    
    
    forward_alu_result_p: process (gp_WR_addr, gp_addrB_final, gp_addrA_value) begin
        if (gp_WR_addr = gp_addrB_final or gp_WR_addr = gp_addrA_value) then 
            forward_alu_result <= true;
        else
            forward_alu_result <= false;
        end if;   
    end process;
    
    base_reg_content_p: process (forward_alu_result, gp_data_in, gp_ram_dataB, 
                                 gp_ram_dataA, gp_addrA_value) begin
        if (forward_alu_result = true) then 
            if (gp_WR_addr = gp_addrA_value) then
                mem_index_content <= gp_ram_dataB;  
                base_reg_content <= gp_data_in;  
            else
                -- gp_WR_addr = gp_addrB_final 
                mem_index_content <= gp_data_in;
                base_reg_content <= gp_ram_dataA;    
            end if;    
        else
            mem_index_content <= gp_ram_dataB;
            base_reg_content <= gp_ram_dataA;
        end if;   
    end process;
    
    base_reg_content_LDM_p: process (LDM_capture_base, gp_ram_dataA) begin
        if (LDM_capture_base = true) then
            base_reg_content_LDM <= gp_ram_dataA;
       
        end if;   
    end process;
    
    data_memory_addr_value_p: process (command_value, gp_ram_dataA, PC_execute, base_reg_content, 
                                       LDR_mul_result_value, use_base_register) begin
        if (use_base_register = true) then 
            if (command_value = LDM) then
                data_memory_addr_i <=  unsigned (base_reg_content); -- Expected to be aligned or HardFaault
            else
                data_memory_addr_i <= unsigned (base_reg_content) +  unsigned(x"0000_00" & LDR_mul_result_value); 
            end if;    
        else
            case (command_value) is
                when LDR_label => 
                    data_memory_addr_i <= unsigned (PC_execute and x"FFFF_FFFC") +  
                                          unsigned(x"0000_00" & LDR_mul_result_value) + x"0000_0004"; 
                when LDR| LDRH | LDRSH | LDRB =>
                    data_memory_addr_i <= unsigned (gp_ram_dataA) +  unsigned(x"0000_00" & LDR_mul_result_value);     
                when others =>
                        null;     
            end case;
             
        end if;   
    end process;
    
    data_memory_addr_value <= std_logic_vector (data_memory_addr_i);   
    -----------------------------------------------------------------------------------------

    decoder_registers_p: process (HCLK, internal_reset) begin 
        if internal_reset = '1' then
            imm8_z_ext <= (others => '0');
            gp_WR_addr <= (others => '0');
            gp_addrA <= (others => '0');
            gp_addrB <= (others => '0');
            command <= NOP;    
            access_mem <= false;
            hrdata_data <= (others => '0');
            hrdata_progrm <= (others => '0');
            data_memory_addr <= (others => '0');
            LDR_mul_result <= (others => '0');
            mem_load_sign_ext <= false;
            LDM_access_mem <= false;
        else
            if (rising_edge(HCLK)) then
                    imm8_z_ext <= imm8_z_ext_value;
                    gp_WR_addr <= gp_WR_addr_value;
                    gp_addrA <= gp_addrA_value;
                    gp_addrB <= gp_addrB_value;
                    command <= command_value;
                    mem_load_size <= mem_load_size_value;
                    data_memory_addr <= data_memory_addr_value;
                    LDR_mul_result <= LDR_mul_result_value;
                    mem_load_sign_ext <= mem_load_sign_ext_value;
                    LDM_access_mem <= LDM_access_mem_value;
                if (disable_fetch = false) then
                    access_mem <= access_mem_value;
                    hrdata_data <= hrdata_data_value; 
                    hrdata_progrm <= hrdata_progrm_value;
                end if;  
            end if;    
        end if;
    end process;

    -----------------------------------------------------------------------------------------
    -- Simulation related code starts here,
    -- These section will not be synthesized.
    -----------------------------------------------------------------------------------------
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
        
        if internal_reset = '1' then
            cortex_m0_opcode <= "CORE IS RESET!   ";
        else
            -------------------------------------------------------------------------------------- -- MOVS Rd, #(imm8)
            if std_match(current_instruction(15 downto 10), "00100-") then                      
                Rd_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8));               
                imm8_decode(2) :=  hexcharacter (current_instruction (7 downto 4));
                imm8_decode(3) :=  hexcharacter (current_instruction (3 downto 0));
                cortex_m0_opcode <= "MOVS " & Rd_decode & "," & imm8_decode & "      ";    
            -------------------------------------------------------------------------------------- -- MOVS <Rd>,<Rm>     
            elsif std_match(current_instruction(15 downto 6), "0000000000") then                 
                Rd_decode(2) := hexcharacter (current_instruction (3 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                cortex_m0_opcode <= "MOVS " & Rd_decode & "," & Rm_decode & "       "; 
            -------------------------------------------------------------------------------------- -- MOV <Rd>,<Rm>  ,  MOV PC, Rm     
            elsif std_match(current_instruction(15 downto 8), "01000110") then                   
                Rd_decode(2) := hexcharacter (current_instruction (7) & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter (current_instruction (6 downto 3));
                cortex_m0_opcode <= "MOV  " & Rd_decode & "," & Rm_decode & "       ";    
            -------------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,#<imm3>
            elsif std_match(current_instruction(15 downto 9), "0001110") then                    
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                imm8_decode(3) :=   hexcharacter ('0' & current_instruction (8 downto 6));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                cortex_m0_opcode <= "ADDS " & Rd_decode & "," & Rn_decode & "," & imm8_decode & "   ";    
            -------------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,<Rm> 
            elsif std_match(current_instruction(15 downto 9), "0001100") then                   
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (8 downto 6));
                cortex_m0_opcode <= "ADDS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "    ";    
            -------------------------------------------------------------------------------------- -- ADD <Rdn>,<Rm> - ADD PC,<Rm>
            elsif std_match(current_instruction(15 downto 8), "01000100") then                  
                Rd_decode(2) := hexcharacter (current_instruction(7) & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter (current_instruction (6 downto 3));
                cortex_m0_opcode <= "ADD  " & Rd_decode & "," & Rm_decode & "       ";    
            -------------------------------------------------------------------------------------- -- ADDS <Rdn>,#<imm8>
            elsif std_match(current_instruction(15 downto 11), "00110") then                      
                Rd_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8));
                imm8_decode(2) :=   hexcharacter (current_instruction (7 downto 4));
                imm8_decode(3) :=   hexcharacter (current_instruction (3 downto 0));
                cortex_m0_opcode <= "ADDS " & Rd_decode & "," & imm8_decode & "      ";    
            -------------------------------------------------------------------------------------- -- ADCS <Rdn>,<Rm>  
            elsif std_match(current_instruction(15 downto 6), "0100000101") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                cortex_m0_opcode <= "ADCS " & Rd_decode & "," & Rm_decode & "       ";   
            -------------------------------------------------------------------------------------- -- SUBS <Rd>,<Rn>,#<imm3>  
            elsif std_match(current_instruction(15 downto 9), "0001111") then                  
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                imm8_decode(3) :=   hexcharacter ('0' & current_instruction (8 downto 6));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                cortex_m0_opcode <= "SUBS " & Rd_decode & "," & Rn_decode & "," & imm8_decode & "   ";  
            -------------------------------------------------------------------------------------- -- SUBS <Rd>,<Rn>,<Rm>  
            elsif std_match(current_instruction(15 downto 9), "0001101") then                  
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (8 downto 6));    
                cortex_m0_opcode <= "SUBS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "    ";   
            -------------------------------------------------------------------------------------- -- SUBS <Rdn>,#<imm8> 
            elsif std_match(current_instruction(15 downto 11), "00111") then                     
                Rd_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8));
                imm8_decode(2) :=   hexcharacter (current_instruction (7 downto 4));
                imm8_decode(3) :=   hexcharacter (current_instruction (3 downto 0));
                cortex_m0_opcode <= "SUBS " & Rd_decode & "," & imm8_decode & "      ";    
            -------------------------------------------------------------------------------------- -- SBCS <Rdn>,<Rm> 
            elsif std_match(current_instruction(15 downto 6), "0100000110") then                 
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                cortex_m0_opcode <= "SBCS " & Rd_decode & "," & Rm_decode & "       ";   
            -------------------------------------------------------------------------------------- -- RSBS <Rd>,<Rn>,#0 
            elsif std_match(current_instruction(15 downto 6), "0100001001") then                 
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                cortex_m0_opcode <= "RSBS " & Rd_decode & "," & Rn_decode & "       ";   
            -------------------------------------------------------------------------------------- -- MULS <Rdm>,<Rn>,<Rdm>
            elsif std_match(current_instruction(15 downto 6), "0100001101") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                cortex_m0_opcode <= "MULS " & Rd_decode & "," & Rn_decode & "," & Rd_decode & "    ";  
           -------------------------------------------------------------------------------------- -- CMP <Rn>,<Rm> T1
           elsif std_match(current_instruction(15 downto 6), "0100001010") then                
                Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                cortex_m0_opcode <= "CMP  " & Rn_decode & "," & Rm_decode & "       ";   
           -------------------------------------------------------------------------------------- -- CMP <Rn>,<Rm> T2
           elsif std_match(current_instruction(15 downto 8), "01000101") then                
                Rn_decode(2) := hexcharacter (current_instruction(7) & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter (current_instruction (6 downto 3));
                cortex_m0_opcode <= "CMP  " & Rn_decode & "," & Rm_decode & "       ";   
           -------------------------------------------------------------------------------------- -- CMN <Rn>,<Rm> 
           elsif std_match(current_instruction(15 downto 6), "0100001011") then                
                Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));
                cortex_m0_opcode <= "CMN  " & Rn_decode & "," & Rm_decode & "       ";   
           -------------------------------------------------------------------------------------- -- CMP <Rn>,#<imm8> 
           elsif std_match(current_instruction(15 downto 11), "00101") then                
                Rn_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8));
                imm8_decode(2) :=  hexcharacter (current_instruction (7 downto 4));
                imm8_decode(3) :=  hexcharacter (current_instruction (3 downto 0));
                cortex_m0_opcode <= "CMP  " & Rd_decode & "," & imm8_decode & "      "; 
           -------------------------------------------------------------------------------------- -- ANDS <Rdn>,<Rm>
           elsif std_match(current_instruction(15 downto 6), "0100000000") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                cortex_m0_opcode <= "ANDS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "    ";
           -------------------------------------------------------------------------------------- -- EORS <Rdn>,<Rm>
           elsif std_match(current_instruction(15 downto 6), "0100000001") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                cortex_m0_opcode <= "EORS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "    ";
           -------------------------------------------------------------------------------------- -- ORRS <Rdn>,<Rm>
           elsif std_match(current_instruction(15 downto 6), "0100001100") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                cortex_m0_opcode <= "ORRS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "    ";
           -------------------------------------------------------------------------------------- -- BICS <Rdn>,<Rm>
           elsif std_match(current_instruction(15 downto 6), "0100001110") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                cortex_m0_opcode <= "BICS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "    ";
           -------------------------------------------------------------------------------------- -- MVNS <Rd>,<Rm>
           elsif std_match(current_instruction(15 downto 6), "0100001111") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                cortex_m0_opcode <= "MVNS " & Rd_decode & "," & Rm_decode &  "       "; 
           -------------------------------------------------------------------------------------- -- TST <Rn>,<Rm>
           elsif std_match(current_instruction(15 downto 6), "0100001000") then                
                Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                cortex_m0_opcode <= "TST  " & Rn_decode & "," & Rm_decode &  "       "; 
           -------------------------------------------------------------------------------------- -- LSLS <Rd>,<Rm>,#<imm5>
           elsif std_match(current_instruction(15 downto 11), "00000") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));  
                imm8_decode(2) :=  hexcharacter ("000" & current_instruction (10));
                imm8_decode(3) :=  hexcharacter (current_instruction (9 downto 6));  
                cortex_m0_opcode <= "LSLS " & Rd_decode & "," & Rm_decode & "," & imm8_decode & "   ";  
            -------------------------------------------------------------------------------------- -- LSLS <Rdn>,<Rm>
           elsif std_match(current_instruction(15 downto 6), "0100000010") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                cortex_m0_opcode <= "LSLS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "    ";  
           -------------------------------------------------------------------------------------- -- LSRS <Rd>,<Rm>,#<imm5>
           elsif std_match(current_instruction(15 downto 11), "00001") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));  
                imm8_decode(2) :=  hexcharacter ("000" & current_instruction (10));
                imm8_decode(3) :=  hexcharacter (current_instruction (9 downto 6));  
                cortex_m0_opcode <= "LSRS " & Rd_decode & "," & Rm_decode & "," & imm8_decode & "   ";  
            -------------------------------------------------------------------------------------- -- LSRS <Rdn>,<Rm>
           elsif std_match(current_instruction(15 downto 6), "0100000011") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                cortex_m0_opcode <= "LSRS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "    ";             
           -------------------------------------------------------------------------------------- -- ASRS <Rd>,<Rm>,#<imm5>
           elsif std_match(current_instruction(15 downto 11), "00010") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));  
                imm8_decode(2) :=  hexcharacter ("000" & current_instruction (10));
                imm8_decode(3) :=  hexcharacter (current_instruction (9 downto 6));  
                cortex_m0_opcode <= "ASRS " & Rd_decode & "," & Rm_decode & "," & imm8_decode & "   ";  
            -------------------------------------------------------------------------------------- -- ASRS <Rdn>,<Rm>
           elsif std_match(current_instruction(15 downto 6), "0100000100") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                cortex_m0_opcode <= "ASRS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "    ";             
           -------------------------------------------------------------------------------------- -- RORS <Rdn>,<Rm>
           elsif std_match(current_instruction(15 downto 6), "0100000111") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rn_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0));
                Rm_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3));    
                cortex_m0_opcode <= "RORS " & Rd_decode & "," & Rn_decode & "," & Rm_decode & "    ";
          -------------------------------------------------------------------------------------- -- LDR <Rt>, [<Rn>{,#<imm5>}]
          elsif std_match(current_instruction(15 downto 11), "01101") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                imm8_decode(2) :=  hexcharacter ("000" & current_instruction (10));
                imm8_decode(3) :=  hexcharacter (current_instruction (9 downto 6));  
                cortex_m0_opcode <= "LDR  " & Rd_decode & ",[" & Rn_decode & "," & imm8_decode & "] ";  
          -------------------------------------------------------------------------------------- -- LDRH <Rt>, [<Rn>{,#<imm5>}]
          elsif std_match(current_instruction(15 downto 11), "10001") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                imm8_decode(2) :=  hexcharacter ("000" & current_instruction (10));
                imm8_decode(3) :=  hexcharacter (current_instruction (9 downto 6));  
                cortex_m0_opcode <= "LDRH " & Rd_decode & ",[" & Rn_decode & "," & imm8_decode & "] ";  
          -------------------------------------------------------------------------------------- -- LDRB <Rt>, [<Rn>{,#<imm5>}]
          elsif std_match(current_instruction(15 downto 11), "01111") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                imm8_decode(2) :=  hexcharacter ("000" & current_instruction (10));
                imm8_decode(3) :=  hexcharacter (current_instruction (9 downto 6));  
                cortex_m0_opcode <= "LDRB " & Rd_decode & ",[" & Rn_decode & "," & imm8_decode & "] ";  
          -------------------------------------------------------------------------------------- -- LDR <Rt>,[<Rn>,<Rm>]
          elsif std_match(current_instruction(15 downto 9), "0101100") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                Rm_decode(2) := hexcharacter ('0' & current_instruction (8 downto 6)); -- Rm 
                cortex_m0_opcode <= "LDR  " & Rd_decode & ",[" & Rn_decode & "," & Rm_decode & "]  "; 
           -------------------------------------------------------------------------------------- -- LDRH <Rt>,[<Rn>,<Rm>]
           elsif std_match(current_instruction(15 downto 9), "0101101") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                Rm_decode(2) := hexcharacter ('0' & current_instruction (8 downto 6)); -- Rm 
                cortex_m0_opcode <= "LDRH " & Rd_decode & ",[" & Rn_decode & "," & Rm_decode & "]  ";                  
           -------------------------------------------------------------------------------------- -- LDRSH <Rt>,[<Rn>,<Rm>]
           elsif std_match(current_instruction(15 downto 9), "0101111") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                Rm_decode(2) := hexcharacter ('0' & current_instruction (8 downto 6)); -- Rm 
                cortex_m0_opcode <= "LDRSH" & Rd_decode & ",[" & Rn_decode & "," & Rm_decode & "]  ";                  
           -------------------------------------------------------------------------------------- -- LDRB <Rt>,[<Rn>,<Rm>]
           elsif std_match(current_instruction(15 downto 9), "0101110") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                Rm_decode(2) := hexcharacter ('0' & current_instruction (8 downto 6)); -- Rm 
                cortex_m0_opcode <= "LDRB " & Rd_decode & ",[" & Rn_decode & "," & Rm_decode & "]  ";      
           -------------------------------------------------------------------------------------- -- LDR <Rt>,<label>
           elsif std_match(current_instruction(15 downto 11), "01001") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8)); --Rt 
                imm8_decode(2) :=  hexcharacter (current_instruction (7 downto 4));
                imm8_decode(3) :=  hexcharacter (current_instruction (3 downto 0));
                cortex_m0_opcode <= "LDR  " & Rd_decode & ",[pc," & imm8_decode & "] ";    
           ------------------------------------------------------------------------------------- -- LDM <Rn>!,<registers>
           elsif std_match(current_instruction(15 downto 11), "11001") then                
                Rn_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8)); -- Rn 
                imm8_decode(2) :=  hexcharacter (current_instruction (7 downto 4));
                imm8_decode(3) :=  hexcharacter (current_instruction (3 downto 0));  
                cortex_m0_opcode <= "LDM " & Rd_decode & ",{" & imm8_decode & "}"  & "     ";   
             
           -------------------------------------------------------------------------------------- -- STR <Rt>, [<Rn>{,#<imm5>}]
           elsif std_match(current_instruction(15 downto 11), "01100") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                imm8_decode(2) :=  hexcharacter ("000" & current_instruction (10));
                imm8_decode(3) :=  hexcharacter (current_instruction (9 downto 6));  
                cortex_m0_opcode <= "STR  " & Rd_decode & ",[" & Rn_decode & "," & imm8_decode & "] ";  
           -------------------------------------------------------------------------------------- -- STRH <Rt>, [<Rn>{,#<imm5>}]
           elsif std_match(current_instruction(15 downto 11), "10000") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                imm8_decode(2) :=  hexcharacter ("000" & current_instruction (10));
                imm8_decode(3) :=  hexcharacter (current_instruction (9 downto 6));  
                cortex_m0_opcode <= "STRH " & Rd_decode & ",[" & Rn_decode & "," & imm8_decode & "] ";  
           -------------------------------------------------------------------------------------- -- STRB <Rt>, [<Rn>{,#<imm5>}]
           elsif std_match(current_instruction(15 downto 11), "01110") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                imm8_decode(2) :=  hexcharacter ("000" & current_instruction (10));
                imm8_decode(3) :=  hexcharacter (current_instruction (9 downto 6));  
                cortex_m0_opcode <= "STRB " & Rd_decode & ",[" & Rn_decode & "," & imm8_decode & "] ";  
            -------------------------------------------------------------------------------------- -- STR <Rt>,[<Rn>,<Rm>]
           elsif std_match(current_instruction(15 downto 9), "0101000") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                Rm_decode(2) := hexcharacter ('0' & current_instruction (8 downto 6)); -- Rm 
                cortex_m0_opcode <= "STR  " & Rd_decode & ",[" & Rn_decode & "," & Rm_decode & "]  ";     
           -------------------------------------------------------------------------------------- -- STRH <Rt>,[<Rn>,<Rm>]
           elsif std_match(current_instruction(15 downto 9), "0101001") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                Rm_decode(2) := hexcharacter ('0' & current_instruction (8 downto 6)); -- Rm 
                cortex_m0_opcode <= "STRH " & Rd_decode & ",[" & Rn_decode & "," & Rm_decode & "]  ";                  
           -------------------------------------------------------------------------------------- -- STRB <Rt>,[<Rn>,<Rm>]
           elsif std_match(current_instruction(15 downto 9), "0101010") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (2 downto 0)); -- Rt
                Rn_decode(2) := hexcharacter ('0' & current_instruction (5 downto 3)); -- Rn 
                Rm_decode(2) := hexcharacter ('0' & current_instruction (8 downto 6)); -- Rm 
                cortex_m0_opcode <= "STRB " & Rd_decode & ",[" & Rn_decode & "," & Rm_decode & "]  ";     
           -------------------------------------------------------------------------------------- -- STR <Rt>,[SP,#<imm8>]   
           elsif std_match(current_instruction(15 downto 11), "10010") then                
                Rd_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8)); --Rt 
                imm8_decode(2) :=  hexcharacter (current_instruction (7 downto 4));
                imm8_decode(3) :=  hexcharacter (current_instruction (3 downto 0));
                cortex_m0_opcode <= "STR  " & Rd_decode & ",[sp," & imm8_decode & "] ";      
           ------------------------------------------------------------------------------------- -- STM <Rn>!,<registers>
           elsif std_match(current_instruction(15 downto 11), "11000") then                
                Rn_decode(2) := hexcharacter ('0' & current_instruction (10 downto 8)); -- Rn 
                imm8_decode(2) :=  hexcharacter (current_instruction (7 downto 4));
                imm8_decode(3) :=  hexcharacter (current_instruction (3 downto 0));  
                cortex_m0_opcode <= "STM " & Rd_decode & ",{" & imm8_decode & "}"  & "     ";                                   
              
           end if;
        end if;
    end process;
 
 --synthesis translate on
      
end Behavioral;
