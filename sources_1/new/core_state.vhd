----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/05/2020 05:03:27 PM
-- Design Name: 
-- Module Name: core_state - Behavioral
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

entity core_state is
    generic (
        USE_ACCELERATOR: boolean := false
    );
    Port (
        clk : in std_logic;
        reset : in std_logic;
        access_mem : in boolean;
        PC_updated : in boolean;
        cond : in std_logic_vector (3 downto 0);
        current_flags : in flag_t;
        imm8 : in std_logic_vector (7 downto 0);
        imm8_value : in std_logic_vector (7 downto 0);
        imm11_10_downto_8 : in std_logic_vector (2 downto 0);
        imm11_value_10_downto_8 : in std_logic_vector (2 downto 0);
        LR_PC : in std_logic;
        number_of_ones_initial : in  std_logic_vector (3 downto 0);
        execution_cmd_value : in executor_cmds_t;
        LDM_STM_access_mem : in boolean;
        new_PC : in std_logic_vector (31 downto 0);
        access_mem_mode : in access_mem_mode_t;
        SP_main_init : in std_logic_vector (31 downto 0);
        PC_init : in std_logic_vector (31 downto 0);
        pos_A_is_multi_cycle : in boolean;
        ldm_hrdata_value : in std_logic_vector(31 downto 0);	
        inst32_detected_value : in boolean;
        current_instruction_32bit_HI : in std_logic_vector (15 downto 0);
        current_instruction : in std_logic_vector (15 downto 0);
        msr_update_MSP : in boolean;
        msr_update_PSP : in boolean;
        msr_update_PRIMASK : in boolean;
        msr_update_CONTROL : in boolean;
        new_PRIMASK : std_logic_vector (0 downto 0);
        new_CONTROL : std_logic_vector (1 downto 0);
        new_SP : in std_logic_vector (31 downto 0);
        SP_updated : in boolean;
        invoke_accelerator : in std_logic;
        invoke_accelerator_next : in std_logic;
        invoke_accelerator_next2 : in std_logic;     
        
        PC : out std_logic_vector (31 downto 0);
        SP_main : out std_logic_vector (31 downto 0);
        SP_main_value : out std_logic_vector (31 downto 0);
        SP_process : out std_logic_vector (31 downto 0);
        PC_decode : out std_logic_vector (31 downto 0);
        PC_execute :  out std_logic_vector (31 downto 0);
        PC_after_execute :  out std_logic_vector (31 downto 0);
        -- Because max no. of LDM registers is 7 so the range: 7 * 4 => 28
        LDM_STM_mem_address_index :  out unsigned (4 downto 0);              
        gp_data_in_ctrl : out gp_data_in_ctrl_t;
        hrdata_ctrl : out hrdata_ctrl_t;
        disable_fetch : out boolean;
        haddr_ctrl : out haddr_ctrl_t;                      -- true  = put data memory address on the bus, 
                                                            -- false = put program memory address on the bus
        disable_executor : out boolean;
        gp_addrA_executor_ctrl : out boolean;
        LDM_W_STM_R_reg : out std_logic_vector (3 downto 0);
        LDM_STM_capture_base : out boolean;
        HWRITE : out std_logic;
        VT_ctrl : out VT_ctrl_t;
        branch_target_address : out std_logic_vector (31 downto 0);
        branch_target_address_val : out std_logic_vector (31 downto 0);
        SDC_push_read_address : out SDC_push_read_address_t;
        inst32_detected : out boolean;
        Rn : out std_logic_vector (31 downto 28);
        PRIMASK : out std_logic_vector (0 downto 0);
        CONTROL : out std_logic_vector (1 downto 0);                    -- nPRIV, bit[0]
                                                                        --      0: Thread mode has privileged access.
                                                                        --      1: Thread mode has unprivileged access.
                                                                        -- SPSEL, bit[1]
                                                                        --      0: Use SP_main as the current stack.
                                                                        --      1: In Thread mode, use SP_process as the current stack.
        m0_core_state_o : out core_state_t
);
end core_state;

architecture Behavioral of core_state is

    signal m0_core_state : core_state_t;
    signal m0_core_next_state : core_state_t;
    signal PC_value : unsigned(31 downto 0);
    signal SP_process_value : std_logic_vector(31 downto 0);
	signal refetch_i : boolean;
    signal LDM_counter : unsigned (3 downto 0);             -- Starts with the total number of target registers 
    signal LDM_counter_value : unsigned (3 downto 0);      
    signal LDM_read_counter : unsigned (4 downto 0);        -- Starts with 0 and counts uo to the max no. of target registers
    signal STM_write_counter : unsigned (4 downto 0);       
    signal PUSH_write_counter : unsigned (4 downto 0);       
    signal STM_PUSH_counter_diff : unsigned (4 downto 0);
    signal LDM_cur_target_reg : low_register_t;
    signal any_access_mem : boolean;
    signal PUSH_POP_number_of_ones_initial : unsigned (3 downto 0);
    signal cond_satisfied : boolean;
    signal cond_satisfied_value : boolean;
    signal branch_target_address_value : signed (31 downto 0);
    signal BL_target_address_value : std_logic_vector (24 downto 0);        -- 25 bits:  S:I1:I2:imm10:imm11:'0'
    signal BL_target_address_value_sign_ext : std_logic_vector (31 downto 0);        
    signal imm11 : std_logic_vector(10 downto 0);
    signal imm8_sign_ext : std_logic_vector(31 downto 0);
    signal imm11_sign_ext : std_logic_vector(31 downto 0);
    signal BL_I1 : std_logic;
    signal BL_I2 : std_logic;
    signal update_target_branch_triggered : boolean;
    signal execution_cmd : executor_cmds_t;
    signal inst32_tempor : boolean;
    signal PRIMASK_value : std_logic_vector(0 downto 0);
    signal CONTROL_value : std_logic_vector(1 downto 0);
    signal is_last_pop : boolean;
    signal is_last_pop_val : boolean;
    signal is_last_push : boolean;
    signal is_last_push_val : boolean;
                                                                        
    
    component sign_ext is
        generic(
            in_byte_width : integer := 8
        );
        Port (
            in_byte:    in  std_logic_vector(in_byte_width - 1 downto 0);
            ret:        out std_logic_vector(31 downto 0)
        );
    end component;

    alias BL_S: std_logic is current_instruction_32bit_HI (10); 
    alias BL_imm10: std_logic_vector (9 downto 0) is current_instruction_32bit_HI (9 downto 0); 
    alias BL_J1: std_logic is current_instruction (13);  
    alias BL_J2: std_logic is current_instruction (11);
    alias BL_imm11: std_logic_vector (10 downto 0) is current_instruction (10 downto 0); 
    
    signal CYCLECOUNTER : std_logic_vector(31 downto 0);

    
begin

    CYCLECOUNTER_p : process (clk, reset) begin
        if (reset = '1') then
            CYCLECOUNTER <= (others => '0');
        else
            if (rising_edge (clk)) then
                if (m0_core_state = s_RUN or
                    m0_core_state = s_EXECUTE_DATA_MEM_W or
                    m0_core_state = s_EXECUTE_DATA_MEM_R or 
                    m0_core_state = s_DATA_MEM_ACCESS_LDM or
                    m0_core_state = s_FINISH_STM or
                    m0_core_state = s_FINISH_PUSH or 
                    m0_core_state = s_DATA_MEM_ACCESS_POP or
                    m0_core_state = s_BRANCH_Phase2
                    ) then
                    CYCLECOUNTER <= std_logic_vector( unsigned(CYCLECOUNTER) + 1);
                end if;    
            end if;
        end if;
    end process;         

    any_access_mem <= access_mem or LDM_STM_access_mem;
    
    PUSH_POP_number_of_ones_initial <= unsigned (number_of_ones_initial) + LR_PC;
    
    imm11 <= imm11_10_downto_8 & imm8;
    
    branch_target_address_val <= std_logic_vector (branch_target_address_value);

    BL_I1 <= not (BL_J1 xor BL_S);        -- I1 = NOT(J1 EOR S);
    BL_I2 <= not (BL_J2 xor BL_S);        -- I2 = NOT(J2 EOR S);
    
    m0_core_state_o <= m0_core_state;
     
    sign_extend_imm8: sign_ext port map (
        in_byte => imm8,
        ret => imm8_sign_ext
    );
    
    sign_extend_imm11: sign_ext generic map (in_byte_width => 11) port map (
        in_byte => imm11,
        ret => imm11_sign_ext
    );
    
    sign_extend_BL_target_address_value: sign_ext generic map (in_byte_width => 25) port map (
        in_byte => BL_target_address_value,
        ret => BL_target_address_value_sign_ext
    );
    
   BL_target_address_value_p: process (execution_cmd_value, BL_S, BL_I1, BL_I2, BL_imm10, BL_imm11) begin
        if (execution_cmd_value = BL) then
            BL_target_address_value <= BL_S & BL_I1 & BL_I2 & BL_imm10 & BL_imm11 & '0';      -- S:I1:I2:imm10:imm11:'0'
        else
            BL_target_address_value <= (others => '0');
        end if;      
    end process;
    
    
    branch_target_address_value_p: process (execution_cmd, execution_cmd_value, PC_execute, PC_after_execute, imm8_sign_ext, 
                                            imm11_sign_ext, BL_target_address_value_sign_ext, new_PC, m0_core_state) begin
        if (execution_cmd_value = BL) then
            branch_target_address_value <= 
                signed(PC_after_execute) + (signed (BL_target_address_value_sign_ext) + 4);
--        elsif (execution_cmd_value = ISB or execution_cmd_value = DSB or execution_cmd_value = DMB) then
--             branch_target_address_value <= 
--                signed(PC_after_execute) + 4;        
        elsif (m0_core_state = s_SVC_PC_UPDATED) then
            branch_target_address_value <= signed (new_PC);     -- SVC exception no. = 11 * 4 = 44 = 0x2C                                        
        elsif (execution_cmd = BRANCH) then
            branch_target_address_value <= 
                signed(PC_after_execute) + (shift_left (signed (imm8_sign_ext), 1) + 4);
        elsif (execution_cmd = BRANCH_imm11) then
            branch_target_address_value <= 
                signed(PC_after_execute) + (shift_left (signed (imm11_sign_ext), 1) + 4);
        elsif (execution_cmd = BX) then
            branch_target_address_value <= signed (new_PC);     -- Rm
        elsif (execution_cmd = BLX) then
            branch_target_address_value <= signed (new_PC);     -- Rm             
        else
            branch_target_address_value <=  x"0000_0000"; 
        end if;        
    end process;     

   check_branch_cond_p: process (reset, cond, current_flags) begin
        if (reset = '1') then
            cond_satisfied_value <= false;
        else
            case (cond) is
                when EQ => if (current_flags.Z = '1') then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when NE => if (current_flags.Z = '0') then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when CS => if (current_flags.C = '1') then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when CC => if (current_flags.C = '0') then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when MI => if (current_flags.N = '1') then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when PL => if (current_flags.N = '0') then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when VS => if (current_flags.V = '1') then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when VC => if (current_flags.V = '0') then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when HI => if (current_flags.C = '1' and 
                               current_flags.Z = '0') then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when LS => if (current_flags.C = '0' or
                               current_flags.Z = '1') then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when GE => if (current_flags.N  = current_flags.V) then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when LT => if (current_flags.N /= current_flags.V) then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when GT => if (current_flags.Z  = '0' and
                               current_flags.N  = current_flags.V) then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when LE => if (current_flags.Z  = '1' or
                               (current_flags.N /= current_flags.V)) then cond_satisfied_value <= true; else cond_satisfied_value <= false; end if;
                when AL => cond_satisfied_value <= true; 
                when others => cond_satisfied_value <= false;
            end case;
        end if;
    end process;    

    LDM_STM_mem_address_index_p: process (LDM_read_counter, STM_write_counter, execution_cmd_value) begin
        if (execution_cmd_value = LDM) then
            LDM_STM_mem_address_index <=  shift_left (LDM_read_counter, 2);     --    LDM_read_counter * 4
        elsif (execution_cmd_value = STM) then       
            LDM_STM_mem_address_index <=  shift_left (STM_write_counter, 2);    --    STM_write_counter * 4
        else
            LDM_STM_mem_address_index <= B"00000";
        end if;                
    end process;
    
    -- STM_write_counter is an up counter starts from -1 , we use this signal to mark the two cycle before the end 
    --  of STM instruction so we can fetch and decode the next instruction in right time.
    STM_PUSH_counter_diff_p: process (execution_cmd_value, number_of_ones_initial, PUSH_POP_number_of_ones_initial, 
                                      STM_write_counter, PUSH_write_counter) begin
        if (execution_cmd_value = STM) then                  
            STM_PUSH_counter_diff <= unsigned("0" & number_of_ones_initial) - STM_write_counter;
        elsif (execution_cmd_value = PUSH) then
            STM_PUSH_counter_diff <= unsigned("0" & PUSH_POP_number_of_ones_initial) - PUSH_write_counter;
        else
            STM_PUSH_counter_diff <= B"00000";
        end if;    
    end process;  
    
    accelerator_PC_g: if USE_ACCELERATOR generate      
        PC_p: process (clk, reset) 
--            variable PC_final : std_logic_vector (31 downto 0);            
        begin
            if (reset = '1') then
                PC <= x"0000_0000";
                SP_main <= x"0000_0000";
                SP_process <= x"0000_0000";
                PC_decode <= x"0000_0000";
                PC_execute <= x"0000_0000"; 
                PC_after_execute  <= x"0000_0000"; 
                branch_target_address <= x"0000_0000";
                execution_cmd <= NOT_DEF;
                inst32_detected <= false;
                Rn <= B"0000";
                PRIMASK <= B"0";
                CONTROL(0) <= mode_privileged;           -- nPRIV
                CONTROL(1) <= SP_mode_main;              -- SPSEL
                is_last_pop <= false;
                is_last_push <= false;
                cond_satisfied <= false;
               
            else    
                if (rising_edge(clk)) then
                    cond_satisfied <= cond_satisfied_value;
                    execution_cmd <= execution_cmd_value;
                    if (m0_core_state /= s_BRANCH_PC_UPDATED and 
                        m0_core_state /= s_BRANCH_Phase1) then
                            inst32_detected <= inst32_detected_value;
                    else
                         inst32_detected <= false;    
                    end if;        
                    SP_main <= SP_main_value;
                    SP_process <= SP_process_value;
                    PRIMASK <= PRIMASK_value;
                    CONTROL <= CONTROL_value; 
                    is_last_pop <= is_last_pop_val;
                    is_last_push <= is_last_push_val;
                    if (m0_core_next_state = s_INST32_DETECTED) then
                        Rn <= current_instruction(3 downto 0);
                    end if; 
                       
                    if (execution_cmd = BRANCH or 
                        execution_cmd = BRANCH_imm11 or -- BRANCH_imm11 covers BL and unconditional branch
                        execution_cmd_value = BL or
                        execution_cmd_value = ISB or
                        execution_cmd_value = DSB or
                        execution_cmd_value = DMB) then        
                        branch_target_address <= std_logic_vector (branch_target_address_value);    
                    end if;  
                    
                    if (m0_core_state = s_BRANCH_BL_UNCOND_PC_UPDATED and execution_cmd = BL) then 
                        if (invoke_accelerator_next = '1') then 
                            PC <= std_logic_vector (unsigned (branch_target_address) + 4); -- branch_target_address + 2 + n where n = 2
                        else
                            PC <= std_logic_vector (unsigned (branch_target_address) + 2);
                        end if;    
                        PC_decode <= std_logic_vector (branch_target_address);
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;   
                    elsif (m0_core_state = s_BRANCH_PC_UPDATED and cond_satisfied = true) then
                        if (invoke_accelerator_next = '1') then 
                            PC <= std_logic_vector (unsigned (branch_target_address_value) + 4);  -- branch_target_address_value + 2 + n where n = 2
                        else
                            PC <= std_logic_vector (unsigned (branch_target_address_value) + 2); 
                        end if;
                        PC_decode <= std_logic_vector (branch_target_address_value);
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;
                    elsif (m0_core_state = s_BRANCH_UNCOND_PC_UPDATED) then    
                        if (invoke_accelerator_next = '1') then 
                            PC <= std_logic_vector (unsigned (branch_target_address_value) + 4);  -- branch_target_address_value + 2 + n where n = 2
                        else
                            PC <= std_logic_vector (unsigned (branch_target_address_value) + 2); 
                        end if;
                        PC_decode <= std_logic_vector (branch_target_address_value);
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;    
                    elsif (m0_core_state = s_BX_PC_UPDATED) then 
                        if (invoke_accelerator_next = '1') then 
                            PC <= std_logic_vector (unsigned (branch_target_address_value) + 4);  -- branch_target_address_value + 2 + n where n = 2
                        else
                            PC <= std_logic_vector (unsigned (branch_target_address_value) + 2); 
                        end if;
                        PC_decode <= std_logic_vector (branch_target_address_value);
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;
                    elsif (m0_core_state = s_BLX_PC_UPDATED) then 
                        if (invoke_accelerator_next = '1') then 
                            PC <= std_logic_vector (unsigned (branch_target_address_value) + 4);  -- branch_target_address_value + 2 + n where n = 2
                        else
                            PC <= std_logic_vector (unsigned (branch_target_address_value) + 2); 
                        end if;
                        PC_decode <= std_logic_vector (branch_target_address_value);
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;
                    elsif (m0_core_state = s_SVC_PC_UPDATED) then 
                        if (invoke_accelerator_next = '1') then 
                            PC <= std_logic_vector (unsigned (branch_target_address_value) + 4);  -- branch_target_address_value + 2 + n where n = 2
                        else
                            PC <= std_logic_vector (unsigned (branch_target_address_value) + 2); 
                        end if;
                        PC_decode <= std_logic_vector (branch_target_address_value);
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;            
                    elsif (m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_PC) then
                        if (invoke_accelerator_next = '1') then 
                            PC <= std_logic_vector (unsigned (ldm_hrdata_value) + 1);  -- ldm_hrdata_value + n where n = 2
                        else
                            PC <= ldm_hrdata_value; 
                        end if;
                        PC <= ldm_hrdata_value;
                        PC_decode <= PC;
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;
                    elsif (refetch_i = false) then 
                        if (invoke_accelerator_next = '1') then 
                            if (gp_addrA_executor_ctrl = false) then
                                PC <= std_logic_vector (unsigned (PC_value) + 2);           -- PC_value + n where n = 2
                            else
                                PC <= new_PC;             
                            end if;    
                        else
                            if (gp_addrA_executor_ctrl = false) then
                                PC <= std_logic_vector (PC_value);           -- normal
                            else
                                PC <= new_PC;
                            end if;    
                        end if;
                        PC_decode <= PC;
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;
                    end if;
                end if;    
            end if;
        end process;
    end generate;

    no_accelerator_PC_g: if USE_ACCELERATOR = false  generate      
        PC_p: process (clk, reset) begin
            if (reset = '1') then
                PC <= x"0000_0000";
                SP_main <= x"0000_0000";
                SP_process <= x"0000_0000";
                PC_decode <= x"0000_0000";
                PC_execute <= x"0000_0000"; 
                PC_after_execute  <= x"0000_0000"; 
                branch_target_address <= x"0000_0000";
                execution_cmd <= NOT_DEF;
                inst32_detected <= false;
                Rn <= B"0000";
                PRIMASK <= B"0";
                CONTROL(0) <= mode_privileged;           -- nPRIV
                CONTROL(1) <= SP_mode_main;              -- SPSEL
                is_last_pop <= false;
                is_last_push <= false;
                cond_satisfied <= false;
               
            else    
                if (rising_edge(clk)) then
                    cond_satisfied <= cond_satisfied_value;
                    execution_cmd <= execution_cmd_value;
                    if (m0_core_state /= s_BRANCH_PC_UPDATED and 
                        m0_core_state /= s_BRANCH_Phase1) then
                            inst32_detected <= inst32_detected_value;
                    else
                         inst32_detected <= false;    
                    end if;        
                    SP_main <= SP_main_value;
                    SP_process <= SP_process_value;
                    PRIMASK <= PRIMASK_value;
                    CONTROL <= CONTROL_value; 
                    is_last_pop <= is_last_pop_val;
                    is_last_push <= is_last_push_val;
                    if (m0_core_next_state = s_INST32_DETECTED) then
                        Rn <= current_instruction(3 downto 0);
                    end if; 
                       
                    if (execution_cmd = BRANCH or 
                        execution_cmd = BRANCH_imm11 or -- BRANCH_imm11 covers BL and unconditional branch
                        execution_cmd_value = BL or
                        execution_cmd_value = ISB or
                        execution_cmd_value = DSB or
                        execution_cmd_value = DMB) then        
                        branch_target_address <= std_logic_vector (branch_target_address_value);    
                    end if;  
                    
                    if (m0_core_state = s_BRANCH_BL_UNCOND_PC_UPDATED and execution_cmd = BL) then 
                        PC <=  std_logic_vector (unsigned (branch_target_address) + 2); 
                        PC_decode <= std_logic_vector (branch_target_address);
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;   
                    elsif (m0_core_state = s_BRANCH_PC_UPDATED and cond_satisfied = true) then    
                        PC <=  std_logic_vector (unsigned (branch_target_address_value) + 2); 
                        PC_decode <= std_logic_vector (branch_target_address_value);
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;
                    elsif (m0_core_state = s_BRANCH_UNCOND_PC_UPDATED) then    
                        PC <=  std_logic_vector (unsigned (branch_target_address_value) + 2); 
                        PC_decode <= std_logic_vector (branch_target_address_value);
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;    
                    elsif (m0_core_state = s_BX_PC_UPDATED) then 
                        PC <=  std_logic_vector (unsigned (branch_target_address_value) + 2); 
                        PC_decode <= std_logic_vector (branch_target_address_value);
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;
                    elsif (m0_core_state = s_BLX_PC_UPDATED) then 
                        PC <=  std_logic_vector (unsigned (branch_target_address_value) + 2); 
                        PC_decode <= std_logic_vector (branch_target_address_value);
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;
                    elsif (m0_core_state = s_SVC_PC_UPDATED) then 
                        PC <=  std_logic_vector (unsigned (branch_target_address_value) + 2); 
                        PC_decode <= std_logic_vector (branch_target_address_value);
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;            
                    elsif (m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_PC) then
                        PC <= ldm_hrdata_value;
                        PC_decode <= PC;
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;
                    elsif (refetch_i = false) then 
                        if (gp_addrA_executor_ctrl = false) then
                            PC <= std_logic_vector (PC_value);           -- normal
                        else
                            PC <= new_PC;
                        end if;    
                        PC_decode <= PC;
                        PC_execute <= PC_decode;
                        PC_after_execute <= PC_execute;
                    end if;
                end if;    
            end if;
        end process;
    end generate;
    
    accelerator_PC_value_g: if USE_ACCELERATOR  generate  
        PC_value_p : process (PC, m0_core_state, refetch_i, PC_init, 
                                execution_cmd_value, invoke_accelerator) begin
            if (invoke_accelerator) then
                -- accelerator is on
                if (m0_core_state = s_SET_PC) then
                    PC_value <= unsigned (PC_init (31 downto 1) & '0');
                else  
                     if (refetch_i = false) then 
                        PC_value <= x"0000_0004" + unsigned (PC);   
                     end if;      
                end if;       
            else  
                -- normal operation with accelarator option turned off                    
                if (m0_core_state = s_SET_PC) then
                    PC_value <= unsigned (PC_init (31 downto 1) & '0');
                else  
                     if (refetch_i = false) then 
                        PC_value <= x"0000_0002" + unsigned (PC);   
                     end if;      
                end if; 
            end if;      
        end process;
    end generate;
    
    no_accelerator_PC_value_g: if USE_ACCELERATOR = false generate  
        PC_value_p : process (PC, m0_core_state, refetch_i, PC_init, 
                                execution_cmd_value) begin
            if (m0_core_state = s_SET_PC) then
                PC_value <= unsigned (PC_init (31 downto 1) & '0');
            else  
                if (refetch_i = false) then 
                    PC_value <= x"0000_0002" + unsigned (PC);   
                end if;      
            end if; 
        end process;
    end generate;  
    
    
    
    SP_main_value_p : process (m0_core_state, SP_main_init, SP_main, new_SP, 
                                msr_update_MSP, SP_updated, is_last_pop_val, is_last_push) begin
        if (m0_core_state = s_RESET) then
            SP_main_value <= x"0000_0000";
        else  
            if (m0_core_state = s_SET_SP) then 
                SP_main_value <= SP_main_init;
            elsif ( m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R0 or 
                    m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R1 or
                    m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R2 or
                    m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R3 or
                    m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R4 or
                    m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R5 or
                    m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R6 or 
                    m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R7 or
                    m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_LR or
                    m0_core_state = s_SVC_PUSH_R0 or
                    m0_core_state = s_SVC_PUSH_R1 or
                    m0_core_state = s_SVC_PUSH_R2 or
                    m0_core_state = s_SVC_PUSH_R3 or
                    m0_core_state = s_SVC_PUSH_R12 or
                    m0_core_state = s_SVC_PUSH_R14 or
                    m0_core_state = s_SVC_PUSH_RETURN_ADDR or
                    m0_core_state = s_SVC_PUSH_xPSR) then
                        -- the last push should not tamper the SP_main    
                        if (is_last_push = false) then
                            if (SP_updated) then
                                SP_main_value <= std_logic_vector (unsigned(new_SP) - 4);
                            else    
                                SP_main_value <= std_logic_vector (unsigned(SP_main) - 4);
                            end if; 
                        end if;   
            elsif (  m0_core_state = s_DATA_MEM_ACCESS_POP or 
                     m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R0 or
                     m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R1 or
                     m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R2 or
                     m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R3 or
                     m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R4 or
                     m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R5 or
                     m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R6 or
                     m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R7 or
                     m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_PC) then
                     -- the last pop should not tamper the SP_main    
                        if (is_last_pop_val = false) then
                            if (SP_updated) then
                                SP_main_value <= std_logic_vector (unsigned(new_SP) + 4);
                            else    
                                SP_main_value <= std_logic_vector (unsigned(SP_main) + 4);
                            end if;
                        else
                              SP_main_value <= std_logic_vector (unsigned(SP_main) + 0);  
                        end if; 
            elsif (m0_core_state = s_MSR) and msr_update_MSP then
                SP_main_value <= new_SP; 
            elsif (m0_core_state = s_RUN) and SP_updated then
                SP_main_value <= new_SP;                 
            else
                SP_main_value <= std_logic_vector (unsigned(SP_main) + 0);
            end if;      
        end if; 
    end process;
    
     is_last_pop_val_p : process (m0_core_state, imm8, LR_PC) 
        variable v_CONCATENATE : std_logic_vector(8 downto 0);
     begin
        v_CONCATENATE := LR_PC & imm8;
        if               (m0_core_state = s_DATA_MEM_ACCESS_POP and v_CONCATENATE <= B"0_0000_0001" ) then
            is_last_pop_val <= true;    
        elsif (m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R0 and v_CONCATENATE <= B"0_0000_0010" ) then
            is_last_pop_val <= true;    
        elsif (m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R1 and v_CONCATENATE <= B"0_0000_0100" ) then
            is_last_pop_val <= true;    
        elsif (m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R2 and v_CONCATENATE <= B"0_0000_1000" ) then
            is_last_pop_val <= true;    
        elsif (m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R3 and v_CONCATENATE <= B"0_0001_0000" ) then
            is_last_pop_val <= true;    
        elsif (m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R4 and v_CONCATENATE <= B"0_0010_0000" ) then
            is_last_pop_val <= true;    
        elsif (m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R5 and v_CONCATENATE <= B"0_0100_0000" ) then
            is_last_pop_val <= true;    
        elsif (m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R6 and v_CONCATENATE <= B"0_1000_0000" ) then
            is_last_pop_val <= true;    
        elsif (m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_R7 and v_CONCATENATE <= B"1_0000_0000" ) then
            is_last_pop_val <= true;    
        elsif (m0_core_state = s_DATA_MEM_ACCESS_EXECUTE_POP_PC) then
            is_last_pop_val <= true;    
        else
            is_last_pop_val <= false;    
        end if;     
     end process;
    
     is_last_push_val_p : process (m0_core_state, imm8, LR_PC) 
        variable v_CONCATENATE : std_logic_vector(8 downto 0);
     begin
        v_CONCATENATE := LR_PC & imm8;
        if    (m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_LR and v_CONCATENATE = B"1_0000_0000" ) then
            is_last_push_val <= true;    
        elsif (m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R7 and imm8 = B"1000_0000" ) then
            is_last_push_val <= true;    
        elsif (m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R6 and imm8(6 downto 0) = B"100_0000" ) then
            is_last_push_val <= true;    
        elsif (m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R6 and imm8(5 downto 0) = B"10_0000" ) then
            is_last_push_val <= true;    
        elsif (m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R4 and imm8(4 downto 0) = B"1_0000" ) then
            is_last_push_val <= true;    
        elsif (m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R3 and imm8(3 downto 0) = B"1000" ) then
            is_last_push_val <= true;    
        elsif (m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R2 and imm8(2 downto 0) = B"100" ) then
            is_last_push_val <= true;    
        elsif (m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R1 and imm8(1 downto 0) = B"10" ) then
            is_last_push_val <= true;    
        elsif (m0_core_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R0) then
            is_last_push_val <= true;    
        else
            is_last_push_val <= false;    
        end if;     
     end process;
    
    SP_process_value_p : process (m0_core_state, new_SP, msr_update_PSP) begin
        if (m0_core_state = s_RESET) then
            SP_process_value <= x"0000_0000";
        else  
            if (m0_core_state = s_MSR) and msr_update_PSP then
                SP_process_value <= new_SP;                 
            end if;      
        end if; 
    end process;
    
    PRIMASK_value_p : process (execution_cmd_value, m0_core_state, msr_update_PRIMASK, new_PRIMASK, imm8_value) begin
        if (m0_core_state = s_RESET) then
            PRIMASK_value <= B"0";
        else  
            if (execution_cmd_value = CPS)  then
                PRIMASK_value <= imm8_value (0 downto 0);
            elsif (m0_core_state = s_MSR) and msr_update_PRIMASK then
                PRIMASK_value <= new_PRIMASK;  
                                
            end if;      
        end if; 
    end process;
    
   CONTROL_value_p : process (m0_core_state, msr_update_CONTROL, new_CONTROL) begin
        if (m0_core_state = s_RESET) then
            CONTROL_value <= B"00";
        else  
            if (m0_core_state = s_MSR) and msr_update_CONTROL then
                CONTROL_value <= new_CONTROL;                 
            end if;      
        end if; 
    end process;

    state_p: process (clk) begin
        if (reset = '1') then
             m0_core_state <= s_RESET;
             LDM_counter <= (others => '0');
        else
            if (rising_edge(clk)) then
                  m0_core_state <= m0_core_next_state;
                  LDM_counter <= LDM_counter_value;
            end if;                       
        end if;
    end process;
        
    LDM_read_counter_p: process (clk) begin
         if (reset = '1') then
            LDM_read_counter <= (others => '0');
            STM_write_counter  <= (others => '0');
            PUSH_write_counter <= (others => '0');
         else
            if (rising_edge(clk)) then             
                if (m0_core_next_state = s_RUN or m0_core_next_state = s_DATA_MEM_ACCESS_LDM) then
                    LDM_read_counter <= (others => '0');  
                elsif (any_access_mem = true) then
                    LDM_read_counter <= LDM_read_counter + 1;        
                end if;
            end if;    
            if (rising_edge(clk)) then             
                if (m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R0 or 
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R1 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R2 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R3 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R4 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R5 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R6 or 
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_STM_R7 or
                    m0_core_next_state = s_FINISH_STM) then
                    STM_write_counter <= STM_write_counter + 1;
                else
                    STM_write_counter <= B"11111";  
                end if;
            end if;   
            if (rising_edge(clk)) then             
                if (m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R0 or 
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R1 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R2 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R3 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R4 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R5 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R6 or 
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_R7 or
                    m0_core_next_state = s_DATA_REG_ACCESS_EXECUTE_PUSH_LR or
                    m0_core_next_state = s_FINISH_PUSH) then
                    PUSH_write_counter <= PUSH_write_counter + 1;
                else
                    PUSH_write_counter <= B"11111";  
                end if;
            end if;     
         end if;      
    end process;
    
--    size_of_executed_instruction_p: process (instruction_size) begin
--        -- false = 16-bit (2 bytes), true = 32-bit (4 bytes) 
--        if (instruction_size = true) then
--            size_of_executed_instruction <= x"0000_0004";
--        else
--            size_of_executed_instruction <= x"0000_0002";
--        end if;
--    end process;
    
    LDM_counter_value_p: process (m0_core_state, number_of_ones_initial, PUSH_POP_number_of_ones_initial, LDM_counter) begin
        if (m0_core_state = s_RUN) then
            LDM_counter_value <= "0000";
        elsif (m0_core_state = s_DATA_MEM_ACCESS_LDM) then  
            LDM_counter_value <= unsigned(number_of_ones_initial);
        elsif (m0_core_state = s_DATA_MEM_ACCESS_POP) then  
            LDM_counter_value <= unsigned(PUSH_POP_number_of_ones_initial);
        else    
            LDM_counter_value <= unsigned(LDM_counter) - 1;  
        end if;    
    end process;
    
    LDM_W_STM_R_reg_p: process (LDM_cur_target_reg) begin
        case (LDM_cur_target_reg) is
            when REG_R0 => LDM_W_STM_R_reg <= "0000";
            when REG_R1 => LDM_W_STM_R_reg <= "0001";
            when REG_R2 => LDM_W_STM_R_reg <= "0010";
            when REG_R3 => LDM_W_STM_R_reg <= "0011";
            when REG_R4 => LDM_W_STM_R_reg <= "0100";
            when REG_R5 => LDM_W_STM_R_reg <= "0101";
            when REG_R6 => LDM_W_STM_R_reg <= "0110";
            when REG_R7 => LDM_W_STM_R_reg <= "0111";
            when REG_LR => LDM_W_STM_R_reg <= "1110";       -- Link register    = r14
            when REG_PC => LDM_W_STM_R_reg <= "1111";       -- PC               = r14
            when others => LDM_W_STM_R_reg <= "0000";
        end case;   
    end process;

    next_state_p: process ( m0_core_state, reset, any_access_mem, PC_updated, execution_cmd_value, 
                            LDM_counter, LDM_counter_value, access_mem_mode, imm8, imm8_value, LR_PC, cond_satisfied_value) begin
        if (reset = '1') then
             m0_core_next_state <= s_RESET;
        else     
            case (m0_core_state) is
                when s_RESET                 => m0_core_next_state <= s_SET_SP;
                when s_SET_SP                => m0_core_next_state <= s_FETCH_PC;
                when s_FETCH_PC              => m0_core_next_state <= s_SET_PC;
                when s_SET_PC                => m0_core_next_state <= s_PRE1_RUN;
                when s_PRE1_RUN              => m0_core_next_state <= s_PRE2_RUN;
                when s_PRE2_RUN              => m0_core_next_state <= s_RUN_FIRST_CYCLE;
                when s_RUN_FIRST_CYCLE       => m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                when s_RUN                   => m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                when s_DATA_MEM_ACCESS_R     => m0_core_next_state <= s_EXECUTE_DATA_MEM_R; 
                when s_EXECUTE_DATA_MEM_R    => m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                when s_DATA_MEM_ACCESS_W     => m0_core_next_state <= s_EXECUTE_DATA_MEM_W; 
--                when s_DATA_MEM_ACCESS_W_STR => m0_core_next_state <= s_EXECUTE_DATA_MEM_W; 
                when s_EXECUTE_DATA_MEM_W    => m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                when s_PC_UPDATED            => m0_core_next_state <= s_PIPELINE_FLUSH1;
                when s_PIPELINE_FLUSH1       => m0_core_next_state <= s_PIPELINE_FLUSH2;
                when s_PIPELINE_FLUSH2       => m0_core_next_state <= s_PIPELINE_FLUSH3;
                when s_PIPELINE_FLUSH3       => m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                when s_DATA_MEM_ACCESS_LDM   =>
                    if    (imm8(0) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R0;
                    elsif (imm8(1) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R1;
                    elsif (imm8(2) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R2;
                    elsif (imm8(3) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R3;
                    elsif (imm8(4) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R4;
                    elsif (imm8(5) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R5;
                    elsif (imm8(6) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                    elsif (imm8(7) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                    else
                        m0_core_next_state <= s_RUN;  
                    end if;  
                when s_DATA_MEM_ACCESS_EXECUTE_LDM_R0 =>  
                    -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                    else
                        if (imm8(1) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R1;
                        elsif (imm8(2) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R2;
                        elsif (imm8(3) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R3;
                        elsif (imm8(4) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R4;
                        elsif (imm8(5) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R5;
                        elsif (imm8(6) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                        elsif (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                        end if;  
                    end if;                       
               when s_DATA_MEM_ACCESS_EXECUTE_LDM_R1 =>  
                    -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                    else
                        if (imm8(2) = '1') then   
                            m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R2;
                        elsif (imm8(3) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R3;
                        elsif (imm8(4) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R4;
                        elsif (imm8(5) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R5;
                        elsif (imm8(6) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                        elsif (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                        end if;  
                    end if;    
               when s_DATA_MEM_ACCESS_EXECUTE_LDM_R2 =>  
                    -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                    else
                        if (imm8(3) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R3;
                        elsif (imm8(4) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R4;
                        elsif (imm8(5) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R5;
                        elsif (imm8(6) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                        elsif (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);   
                        end if;  
                    end if;    
                when s_DATA_MEM_ACCESS_EXECUTE_LDM_R3 =>  
                    -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                    else
                        if (imm8(4) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R4;
                        elsif (imm8(5) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R5;
                        elsif (imm8(6) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                        elsif (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                            m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);    
                        end if;  
                    end if;   
                when s_DATA_MEM_ACCESS_EXECUTE_LDM_R4 =>  
                -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                    else
                        if (imm8(5) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R5;
                        elsif (imm8(6) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                        elsif (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state); 
                        end if;  
                    end if;
                when s_DATA_MEM_ACCESS_EXECUTE_LDM_R5 =>  
                    -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                    else
                        if (imm8(6) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R6;
                        elsif (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);   
                        end if;  
                    end if; 
                when s_DATA_MEM_ACCESS_EXECUTE_LDM_R6 =>  
                    -- if we reach this state we are sure that LDM_counter is greater than 1
                    if (LDM_counter = 0) then
                        m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                    else
                        if (imm8(7) = '1') then   
                             m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_LDM_R7;
                        else
                             m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);       
                        end if;  
                    end if; 
                when s_DATA_MEM_ACCESS_EXECUTE_LDM_R7 =>  
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                when s_FINISH_STM =>
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                when s_DATA_REG_ACCESS_EXECUTE_STM_R0 =>  
                    if (imm8_value(1) = '1') then   
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R1;
                    elsif (imm8_value(2) = '1') then   
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R2;
                    elsif (imm8_value(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R3;
                    elsif (imm8_value(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R4;
                    elsif (imm8_value(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R5;
                    elsif (imm8_value(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                    elsif (imm8_value(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R1 =>  
                    if (imm8_value(2) = '1') then   
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R2;
                    elsif (imm8_value(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R3;
                    elsif (imm8_value(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R4;
                    elsif (imm8_value(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R5;
                    elsif (imm8_value(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                    elsif (imm8_value(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R2 =>  
                    if (imm8_value(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R3;
                    elsif (imm8_value(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R4;
                    elsif (imm8_value(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R5;
                    elsif (imm8_value(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                    elsif (imm8_value(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;    
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R3 =>  
                    if (imm8_value(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R4;
                    elsif (imm8_value(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R5;
                    elsif (imm8_value(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                    elsif (imm8_value(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R4 =>  
                    if (imm8_value(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R5;
                    elsif (imm8_value(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                    elsif (imm8_value(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;    
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R5 =>  
                    if (imm8_value(6) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R6;
                    elsif (imm8_value(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;     
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R6 =>  
                    if (imm8_value(7) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_STM_R7;
                    else
                         m0_core_next_state <= s_FINISH_STM;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_STM_R7 =>  
                    m0_core_next_state <= s_FINISH_STM;
                when s_FINISH_PUSH =>
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_LR =>  
                    if (imm8_value(7) = '1') then   
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R7;
                    elsif (imm8_value(6) = '1') then   
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R6;
                    elsif (imm8_value(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R5;
                    elsif (imm8_value(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R4;
                    elsif (imm8_value(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R3;
                    elsif (imm8_value(2) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R2;
                    elsif (imm8_value(1) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R1;
                    elsif (imm8_value(0) = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R0;     
                    else
                         m0_core_next_state <= s_FINISH_PUSH;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_R7 =>  
                    if (imm8_value(6) = '1') then   
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R6;
                    elsif (imm8_value(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R5;
                    elsif (imm8_value(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R4;
                    elsif (imm8_value(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R3;
                    elsif (imm8_value(2) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R2;
                    elsif (imm8_value(1) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R1;
                    elsif (imm8_value(0) = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R0;     
                    else
                         m0_core_next_state <= s_FINISH_PUSH;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_R6 =>  
                    if (imm8_value(5) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R5;
                    elsif (imm8_value(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R4;
                    elsif (imm8_value(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R3;
                    elsif (imm8_value(2) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R2;
                    elsif (imm8_value(1) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R1;
                    elsif (imm8_value(0) = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R0;     
                    else
                         m0_core_next_state <= s_FINISH_PUSH;    
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_R5 =>  
                    if (imm8_value(4) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R4;
                    elsif (imm8_value(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R3;
                    elsif (imm8_value(2) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R2;
                    elsif (imm8_value(1) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R1;
                    elsif (imm8_value(0) = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R0;     
                    else
                         m0_core_next_state <= s_FINISH_PUSH;
                    end if;  
                when s_DATA_REG_ACCESS_EXECUTE_PUSH_R4 =>  
                    if (imm8_value(3) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R3;
                    elsif (imm8_value(2) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R2;
                    elsif (imm8_value(1) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R1;
                    elsif (imm8_value(0) = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R0;     
                    else
                         m0_core_next_state <= s_FINISH_PUSH;    
                    end if;  
               when s_DATA_REG_ACCESS_EXECUTE_PUSH_R3 =>  
                    if (imm8_value(2) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R2;
                    elsif (imm8_value(1) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R1;
                    elsif (imm8_value(0) = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R0;     
                    else
                         m0_core_next_state <= s_FINISH_PUSH;     
                    end if;  
               when s_DATA_REG_ACCESS_EXECUTE_PUSH_R2 =>  
                    if (imm8_value(1) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R1;
                    elsif (imm8_value(0) = '1') then
                        m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R0;
                    else    
                         m0_core_next_state <= s_FINISH_PUSH;
                    end if;  
               when s_DATA_REG_ACCESS_EXECUTE_PUSH_R1 =>  
                     if (imm8_value(0) = '1') then   
                         m0_core_next_state <= s_DATA_REG_ACCESS_EXECUTE_PUSH_R0;
                    else
                         m0_core_next_state <= s_FINISH_PUSH;
                    end if; 
               when s_DATA_REG_ACCESS_EXECUTE_PUSH_R0 =>    
                    m0_core_next_state <= s_FINISH_PUSH;
               when s_DATA_MEM_ACCESS_POP  =>
                    if    (imm8_value(0) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R0;
                    elsif (imm8_value(1) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R1;
                    elsif (imm8_value(2) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R2;
                    elsif (imm8_value(3) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R3;
                    elsif (imm8_value(4) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R4;
                    elsif (imm8_value(5) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R5;
                    elsif (imm8_value(6) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R6;
                    elsif (imm8_value(7) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R7;
                    elsif (LR_PC = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_PC;
                    else
                        m0_core_next_state <= s_RUN;  
                    end if;  
             when s_DATA_MEM_ACCESS_EXECUTE_POP_R0 =>  
                -- if we reach this state we are sure that LDM_counter is greater than 1
                if (LDM_counter = 0) then
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                else
                    if (imm8(1) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R1;
                    elsif (imm8(2) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R2;
                    elsif (imm8(3) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R3;
                    elsif (imm8(4) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R4;
                    elsif (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R7;
                    elsif (LR_PC = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_PC;
                    else
                         m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                    end if;  
                end if;                       
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R1 =>  
                -- if we reach this state we are sure that LDM_counter is greater than 1
                if (LDM_counter = 0) then
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                else
                    if (imm8(2) = '1') then   
                        m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R2;
                    elsif (imm8(3) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R3;
                    elsif (imm8(4) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R4;
                    elsif (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R7;
                    elsif (LR_PC = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_PC;
                    else
                         m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                    end if;  
                end if;    
           when s_DATA_MEM_ACCESS_EXECUTE_POP_R2 =>  
                -- if we reach this state we are sure that LDM_counter is greater than 1
                if (LDM_counter = 0) then
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                else
                    if (imm8(3) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R3;
                    elsif (imm8(4) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R4;
                    elsif (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R7;
                    elsif (LR_PC = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_PC;
                    else
                         m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);   
                    end if;  
                end if;    
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R3 =>  
                -- if we reach this state we are sure that LDM_counter is greater than 1
                if (LDM_counter = 0) then
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                else
                    if (imm8(4) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R4;
                    elsif (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R7;
                    elsif (LR_PC = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_PC;     
                    else
                         m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);    
                    end if;  
                end if;   
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R4 =>  
                -- if we reach this state we are sure that LDM_counter is greater than 1
                if (LDM_counter = 0) then
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                else
                    if (imm8(5) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R5;
                    elsif (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R7;
                    elsif (LR_PC = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_PC;      
                    else
                         m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state); 
                    end if;  
                end if;
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R5 =>  
                -- if we reach this state we are sure that LDM_counter is greater than 1
                if (LDM_counter = 0) then
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                else
                    if (imm8(6) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R6;
                    elsif (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R7;
                    elsif (LR_PC = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_PC;     
                    else
                         m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);   
                    end if;  
                end if; 
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R6 =>  
                -- if we reach this state we are sure that LDM_counter is greater than 1
                if (LDM_counter = 0) then
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
                else
                    if (imm8(7) = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_R7;
                    elsif (LR_PC = '1') then   
                         m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_PC; 
                    else
                         m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);       
                    end if;  
                end if; 
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R7 =>  
               if (LR_PC = '1') then   
                    m0_core_next_state <= s_DATA_MEM_ACCESS_EXECUTE_POP_PC;
               else     
                    m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
               end if;
            when  s_DATA_MEM_ACCESS_EXECUTE_POP_PC =>
                m0_core_next_state <= s_PIPELINE_FLUSH1; 
            when s_BRANCH_PC_UPDATED =>
                m0_core_next_state <= s_BRANCH_Phase1;  
            when s_BRANCH_UNCOND_PC_UPDATED =>
                m0_core_next_state <= s_BRANCH_Phase1;
            when s_BRANCH_BL_UNCOND_PC_UPDATED =>
                m0_core_next_state <= s_BRANCH_Phase1;
            when s_BX_PC_UPDATED =>
                m0_core_next_state <= s_BRANCH_Phase1;   
            when s_BRANCH_Phase1 =>
                m0_core_next_state <= s_BRANCH_Phase2;
            when s_BRANCH_Phase2 =>
                m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
            when  s_BLX_PC_UPDATED =>
                m0_core_next_state <= s_BLX_Phase1;   
            when s_BLX_Phase1 =>
                m0_core_next_state <= s_BLX_Phase2;
            when s_BLX_Phase2 =>
                m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
            when s_SVC_PUSH_R0 =>
                m0_core_next_state <= s_SVC_PUSH_R1;
            when s_SVC_PUSH_R1 =>
                m0_core_next_state <= s_SVC_PUSH_R2;
            when s_SVC_PUSH_R2 =>
                m0_core_next_state <= s_SVC_PUSH_R3;
            when s_SVC_PUSH_R3 =>
                m0_core_next_state <= s_SVC_PUSH_R12;
            when s_SVC_PUSH_R12 =>
                m0_core_next_state <= s_SVC_PUSH_R14;
            when s_SVC_PUSH_R14 =>
                m0_core_next_state <= s_SVC_PUSH_RETURN_ADDR;
            when s_SVC_PUSH_RETURN_ADDR =>
                m0_core_next_state <= s_SVC_PUSH_xPSR;
            when s_SVC_PUSH_xPSR =>
                m0_core_next_state <= s_SVC_FETCH_NEW_PC;
            when s_SVC_FETCH_NEW_PC =>
                m0_core_next_state <= s_SVC_PC_UPDATED;           
            when s_SVC_PC_UPDATED =>
                m0_core_next_state <= s_BRANCH_Phase1;   
            when s_INST32_DETECTED =>     
                m0_core_next_state <= inst32_next_state_calc (execution_cmd_value);
            when s_MRS =>
                m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
            when s_MSR =>
                m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
            when s_ISB | s_DMB | s_DSB =>
                m0_core_next_state <= run_next_state_calc (any_access_mem, access_mem_mode, execution_cmd_value, PC_updated, imm8_value, LR_PC, cond_satisfied_value, m0_core_state);
  
                     
            
                    
            when others => m0_core_next_state <= s_RESET;
            end case;
        end if;            
    end process;

    output_p: process ( m0_core_state, PC(1), PC_execute(1), LDM_counter, LDM_counter_value, STM_PUSH_counter_diff,
                        STM_write_counter, PUSH_write_counter, any_access_mem, branch_target_address) begin
        case (m0_core_state) is
            when s_RESET => 
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_SP_main_init; 
                hrdata_ctrl <= sel_SP_main_init; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_SET_SP => 
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_SP_main_init; 
                hrdata_ctrl <= sel_SP_main_init; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_VECTOR_TABLE; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0';     
                VT_ctrl <= VT_SP_main;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_FETCH_PC => 
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_VECTOR_TABLE; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0';     
                VT_ctrl <= VT_RESET;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_SET_PC => 
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_PC_init; 
                hrdata_ctrl <=  sel_PC_init; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_VECTOR_TABLE; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0';     
                VT_ctrl <= VT_RESET;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_PRE1_RUN =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                LDM_cur_target_reg <= REG_NONE;
                disable_fetch <= false;
                gp_addrA_executor_ctrl <= false; 
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_PRE2_RUN =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                LDM_cur_target_reg <= REG_NONE;   
                disable_fetch <= false;
                gp_addrA_executor_ctrl <= false; 
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_RUN_FIRST_CYCLE =>  
                refetch_i <= any_access_mem; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                disable_fetch <= any_access_mem;
                LDM_cur_target_reg <= REG_NONE;
                gp_addrA_executor_ctrl <= false; 
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_RUN =>  
                refetch_i <= any_access_mem; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_executor <= false; 
                haddr_ctrl <= sel_PC;
                disable_fetch <= any_access_mem;
                LDM_cur_target_reg <= REG_NONE;
                gp_addrA_executor_ctrl <= false; 
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
             when s_DATA_MEM_ACCESS_R =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                if (PC(1) = '0') then
                    -- LDR is located in position A: 
                    hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                else
                    -- LDR is located in position B:
                    if (pos_A_is_multi_cycle = true) then 
                        hrdata_ctrl <= sel_NC;          -- Do not update hrdata_program_value
                    else
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                    end if;    
                end if;
                disable_executor <= true; 
                if (PC(1) = '1') then
                    disable_fetch <= false;
                else
                    disable_fetch <= any_access_mem;
                end if;
                haddr_ctrl <= sel_DATA;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_EXECUTE_DATA_MEM_R =>  
                refetch_i <= any_access_mem; 
                gp_data_in_ctrl <= sel_HRDATA_VALUE_SIZED; 
                hrdata_ctrl <= sel_HRDATA_VALUE_SIZED; 
                disable_executor <= false; 
                haddr_ctrl <= sel_PC;
                disable_fetch <= any_access_mem;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_W =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_executor <= true; 
                haddr_ctrl <= sel_WDATA;
                if (PC(1) = '1') then
                    disable_fetch <= false;
                else
                    disable_fetch <= any_access_mem;
                end if;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
--          when s_DATA_MEM_ACCESS_W_STR =>  
--                refetch_i <= false; 
--                gp_data_in_ctrl <= sel_ALU_RESULT; 
--                hrdata_ctrl <= sel_ALU_RESULT; 
--                disable_executor <= true; 
--                haddr_ctrl <= sel_WDATA_STR;
--                if (PC(1) = '1') then
--                    disable_fetch <= false;
--                else
--                    disable_fetch <= any_access_mem;
--                end if;
--                gp_addrA_executor_ctrl <= false; 
--                LDM_cur_target_reg <= REG_NONE;
--                LDM_STM_capture_base <= false; 
--                HWRITE <= '1'; 
--                VT_ctrl <= VT_NONE;
--                SDC_push_read_address <= SDC_read_R0;
--                inst32_tempor <= false;
           when s_EXECUTE_DATA_MEM_W =>  
                refetch_i <= any_access_mem; 
                gp_data_in_ctrl <= sel_MEM_W; 
                hrdata_ctrl <=  sel_HRDATA_VALUE_SIZED; 
                disable_executor <= false; 
                haddr_ctrl <= sel_PC;
                disable_fetch <= any_access_mem;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
          when s_PC_UPDATED =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_fetch <= false;
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= true; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_PIPELINE_FLUSH1 =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_fetch <= false; 
                disable_executor <= true;
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= false;
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
          when s_PIPELINE_FLUSH2 =>  
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_PIPELINE_FLUSH3 =>  
                refetch_i <= any_access_mem; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_fetch <= any_access_mem; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_DATA_MEM_ACCESS_LDM =>
                LDM_STM_capture_base <= true; 
                if (LDM_counter_value = 1) then
                    -- it means the LDM instruction has only 1 register in its register_list
                    -- therefor we have to finish the LDM in next cycle.
                    refetch_i <= false;
                     if (PC_execute(1) = '1') then
                        disable_fetch <= false; 
                    else
                        disable_fetch <= any_access_mem; 
                    end if;
                   
                else
                    refetch_i <= true;
                    disable_fetch <= true;
                end if;
                if (PC(1) = '0') then
                    -- LDR is located in position A: 
                    hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                else
                    -- LDR is located in position B:
                    if (pos_A_is_multi_cycle = true) then 
                        hrdata_ctrl <= sel_NC;          -- Do not update hrdata_program_value
                    else
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                    end if;    
                end if;
                gp_data_in_ctrl <= sel_LDM_Rn; 
                haddr_ctrl <= sel_LDM;
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R0 =>  
                LDM_cur_target_reg <= REG_R0;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_PC;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R1 =>  
                LDM_cur_target_reg <= REG_R1;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_PC;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R2 =>  
                LDM_cur_target_reg <= REG_R2;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_PC;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <=  sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_DATA_MEM_ACCESS_EXECUTE_LDM_R3 =>            
                LDM_cur_target_reg <= REG_R3;  
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_PC;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R4 =>  
                LDM_cur_target_reg <= REG_R4;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_PC;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if;  
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R5 =>  
                LDM_cur_target_reg <= REG_R5;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_PC;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R6 =>  
                LDM_cur_target_reg <= REG_R6;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_LDM;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_LDM_R7 =>  
                LDM_cur_target_reg <= REG_R7;  
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of LDM is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_LDM;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_FINISH_STM =>
                -- In this state we need to write the total number of bytes written into memory to register bank
                LDM_STM_capture_base <= false; 
                --  we have to finish the STM in next cycle.
                refetch_i <= any_access_mem; 
                disable_fetch <= any_access_mem;
--                if (PC(1) = '1') then
--                    hrdata_ctrl <= sel_NC; 
--                   else
--                    hrdata_ctrl <= sel_NC;
--                end if;
                hrdata_ctrl <= sel_NC;
                gp_data_in_ctrl <= sel_STM_total_bytes_wrote; 
                haddr_ctrl <= sel_PC;                           -- Not used
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_REG_ACCESS_EXECUTE_STM_R0 =>  
               LDM_cur_target_reg <= REG_R0;
               LDM_STM_capture_base <= true;
               if (STM_PUSH_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
               else
                    refetch_i <= true; 
                    disable_fetch <= true; 
               end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_DATA_REG_ACCESS_EXECUTE_STM_R1 =>  
                LDM_cur_target_reg <= REG_R1;
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;   
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_REG_ACCESS_EXECUTE_STM_R2 =>  
                LDM_cur_target_reg <= REG_R2;
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                 if (STM_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_REG_ACCESS_EXECUTE_STM_R3 =>            
                LDM_cur_target_reg <= REG_R3;
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                 if (STM_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_DATA_REG_ACCESS_EXECUTE_STM_R4 =>  
                LDM_cur_target_reg <= REG_R4;
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;   
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_DATA_REG_ACCESS_EXECUTE_STM_R5 =>  
                LDM_cur_target_reg <= REG_R5;
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                    gp_data_in_ctrl <= sel_gp_data_in_NC;  
                 if (STM_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;   
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_REG_ACCESS_EXECUTE_STM_R6 =>  
                LDM_cur_target_reg <= REG_R6;
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
               if (STM_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_DATA_REG_ACCESS_EXECUTE_STM_R7 =>  
                LDM_cur_target_reg <= REG_R7;
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_STM;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                if (STM_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if; 
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_FINISH_PUSH =>
                -- In this state we need to write the total number of bytes written into memory to register bank
                LDM_STM_capture_base <= false; 
                --  we have to finish the STM in next cycle.
                refetch_i <= any_access_mem; 
                disable_fetch <= any_access_mem;
--                if (PC(1) = '1') then
--                    hrdata_ctrl <= sel_NC; 
--                   else
--                    hrdata_ctrl <= sel_LDM_Rn;
--                end if;
                hrdata_ctrl <= sel_NC;
                gp_data_in_ctrl <= sel_PUSH; 
                haddr_ctrl <= sel_PC;                           -- Not used
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R0 =>  
                LDM_cur_target_reg <= REG_R0;   
                LDM_STM_capture_base <= true;
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of PUSH
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_SP_main_addr;
                gp_data_in_ctrl <= sel_SP_set;  
                if (PUSH_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R1 =>  
                LDM_cur_target_reg <= REG_R1;   
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of PUSH 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_SP_main_addr;
                gp_data_in_ctrl <= sel_SP_set;  
                if (PUSH_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;   
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R2 =>  
                LDM_cur_target_reg <= REG_R2;   
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of PUSH 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_SP_main_addr;
                gp_data_in_ctrl <= sel_SP_set;  
                 if (PUSH_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;   
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R3 =>            
                LDM_cur_target_reg <= REG_R3;  
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of PUSH
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_SP_main_addr;
                gp_data_in_ctrl <= sel_SP_set;  
                if (PUSH_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;   
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R4 =>  
                LDM_cur_target_reg <= REG_R4;   
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of STM 
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_SP_main_addr;
                gp_data_in_ctrl <= sel_SP_set;  
                 if (PUSH_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;    
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
          when s_DATA_REG_ACCESS_EXECUTE_PUSH_R5 =>  
                LDM_cur_target_reg <= REG_R5;   
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of PUSH
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_SP_main_addr;
                gp_data_in_ctrl <= sel_SP_set;  
                if (PUSH_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if; 
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R6 =>  
                LDM_cur_target_reg <= REG_R6;   
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of PUSH
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_SP_main_addr;
                gp_data_in_ctrl <= sel_SP_set;  
               if (PUSH_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_R7 =>  
                LDM_cur_target_reg <= REG_R7;  
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of PUSH
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_SP_main_addr;
                gp_data_in_ctrl <= sel_SP_set;  
                if (PUSH_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if; 
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_REG_ACCESS_EXECUTE_PUSH_LR =>  
                LDM_cur_target_reg <= REG_LR;  
                LDM_STM_capture_base <= true; 
                if (STM_PUSH_counter_diff = 1) then         -- two states before the end of PUSH
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                haddr_ctrl <= sel_SP_main_addr;
                gp_data_in_ctrl <= sel_SP_set;  
               if (PUSH_write_counter =  B"00000") then
                    -- let the first memory write acces of STM to update hrdata_progrm_value
                    if (PC(1) = '0') then
                        -- STM is located in position A: 
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                    else
                        -- STM is located in position B:
                        if (pos_A_is_multi_cycle = true) then 
                            hrdata_ctrl <= sel_LDM_DATA;          -- Do not update hrdata_program_value 
                        else
                            hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                        end if;    
                    end if;
                else
                    -- do not update hrdata_progrm_value
                    hrdata_ctrl <= sel_LDM_DATA;
                end if;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_POP =>
                LDM_STM_capture_base <= true; 
                if (LDM_counter_value = 1) then
                    -- it means the POP instruction has only 1 register in its register_list
                    -- therefor we have to finish the STM in next cycle.
                    refetch_i <= false;
                    if (PC_execute(1) = '1') then
                        disable_fetch <= false; 
                    else
                        disable_fetch <= any_access_mem; 
                    end if;
                else
                    refetch_i <= true;
                    disable_fetch <= true;
                end if;
                if (PC(1) = '0') then
                        -- STM is located in position A: 
                    hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value   
                else
                    -- STM is located in position B:
                    if (pos_A_is_multi_cycle = true) then 
                        hrdata_ctrl <= sel_NC;          -- Do not update hrdata_program_value 
                    else
                        hrdata_ctrl <= sel_LDM_Rn;      -- Update hrdata_program_value       
                    end if;    
                end if;
                gp_data_in_ctrl <= sel_POP; 
                haddr_ctrl <= sel_SP_main_addr_plus_4;
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false; 
                LDM_cur_target_reg <= REG_NONE;
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;    
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R0 =>  
                LDM_cur_target_reg <= REG_R0;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of POP is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                if (LDM_counter = 1) then
                    haddr_ctrl <= sel_PC;
                else
                    haddr_ctrl <= sel_SP_main_addr_plus_4;
                end if;    
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R1 =>  
                LDM_cur_target_reg <= REG_R1;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of POP is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                   else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                if (LDM_counter = 1) then
                    haddr_ctrl <= sel_PC;
                else
                    haddr_ctrl <= sel_SP_main_addr_plus_4;
                end if;    
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R2 =>  
                LDM_cur_target_reg <= REG_R2;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of POP is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                 elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                if (LDM_counter = 1) then
                    haddr_ctrl <= sel_PC;
                else
                    haddr_ctrl <= sel_SP_main_addr_plus_4;
                end if;    
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <=  sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R3 =>            
                LDM_cur_target_reg <= REG_R3;  
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of POP is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                if (LDM_counter = 1) then
                    haddr_ctrl <= sel_PC;
                else
                    haddr_ctrl <= sel_SP_main_addr_plus_4;
                end if;    
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R4 =>  
                LDM_cur_target_reg <= REG_R4;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of POP is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if;  
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                if (LDM_counter = 1) then
                    haddr_ctrl <= sel_PC;
                else
                    haddr_ctrl <= sel_SP_main_addr_plus_4;
                end if;    
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R5 =>  
                LDM_cur_target_reg <= REG_R5;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of POP is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                 end if;
                if (LDM_counter = 1) then
                    haddr_ctrl <= sel_PC;
                else
                    haddr_ctrl <= sel_SP_main_addr_plus_4;
                end if;    
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R6 =>  
                LDM_cur_target_reg <= REG_R6;   
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of POP is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                if (LDM_counter = 1) then
                    haddr_ctrl <= sel_PC;
                else
                    haddr_ctrl <= sel_SP_main_addr_plus_4;
                end if;    
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_DATA_MEM_ACCESS_EXECUTE_POP_R7 =>  
                LDM_cur_target_reg <= REG_R7;  
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of POP is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                end if;
                if (LDM_counter = 1) then
                    haddr_ctrl <= sel_PC;
                else
                    haddr_ctrl <= sel_SP_main_addr_plus_4;
                end if;    
                gp_data_in_ctrl <= sel_LDM_DATA;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
             when s_DATA_MEM_ACCESS_EXECUTE_POP_PC =>  
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                if (LDM_counter = 1) then         -- one state before the end of POP is over
                    refetch_i <= any_access_mem; 
                    disable_fetch <= any_access_mem; 
                    haddr_ctrl <= sel_LDM;
                elsif (LDM_counter = 2) then
                    refetch_i <= false;    
                    if (PC(1) = '1') then
                        disable_fetch <= false;
                    else
                        disable_fetch <= any_access_mem;
                    end if; 
                    haddr_ctrl <= sel_LDM;
                else
                    refetch_i <= true; 
                    disable_fetch <= true; 
                    haddr_ctrl <= sel_LDM;
                end if;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                hrdata_ctrl <= sel_LDM_DATA;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;     
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_BRANCH_PC_UPDATED =>     
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= false;                              
                disable_fetch <= false; 
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                hrdata_ctrl <= sel_ALU_RESULT;  
                haddr_ctrl <= sel_BRANCH;
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;     
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_BRANCH_UNCOND_PC_UPDATED =>     
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= false;                              
                disable_fetch <= false; 
                -- haddr_ctrl <= sel_PC;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                hrdata_ctrl <= sel_ALU_RESULT;  
                haddr_ctrl <= sel_BRANCH;
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_BRANCH_BL_UNCOND_PC_UPDATED =>     
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= false;                              
                disable_fetch <= false; 
                haddr_ctrl <= sel_BRANCH_BL;
                gp_data_in_ctrl <= sel_LR_DATA_BL;  
                hrdata_ctrl <= sel_NC;  
                disable_executor <= false; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_BX_PC_UPDATED =>     
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= false;                              
                disable_fetch <= false; 
                -- haddr_ctrl <= sel_PC;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                hrdata_ctrl <= sel_ALU_RESULT;  
                haddr_ctrl <= sel_BX_Rm;
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;                            
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_BRANCH_Phase1 =>    
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= false;                      
                disable_fetch <= false;
                --haddr_ctrl <= sel_PC_plus_4;
                haddr_ctrl <= sel_PC;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                hrdata_ctrl <= sel_ALU_RESULT;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_BRANCH_Phase2 =>    
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= any_access_mem; 
                disable_fetch <= any_access_mem;
                haddr_ctrl <= sel_hardd_NC;
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;            
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
--            when s_BL =>                            
--                refetch_i <= false; 
--                gp_data_in_ctrl <= sel_LR_DATA_BL;  
--                hrdata_ctrl <= sel_NC; 
--                disable_fetch <= false; 
--                disable_executor <= false; 
--                haddr_ctrl <= sel_PC;
--                gp_addrA_executor_ctrl <= false;
--                LDM_STM_capture_base <= false; 
--                LDM_cur_target_reg <= REG_NONE;
--                HWRITE <= '0'; 
--                VT_ctrl <= VT_NONE;
--                SDC_push_read_address <= SDC_read_R0;
--                inst32_tempor <= false;
            when s_BLX_PC_UPDATED =>                            
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_LR_DATA_BLX;  
                hrdata_ctrl <= sel_NC; 
                disable_fetch <= false; 
                disable_executor <= false; 
                haddr_ctrl <= sel_BLX_Rm;
                gp_addrA_executor_ctrl <= false;
                LDM_STM_capture_base <= false; 
                LDM_cur_target_reg <= REG_NONE;
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_BLX_Phase1 =>    
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= false;                      
                disable_fetch <= false;
                --haddr_ctrl <= sel_PC_plus_4;
                haddr_ctrl <= sel_PC;
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                hrdata_ctrl <= sel_ALU_RESULT;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_BLX_Phase2 =>    
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= any_access_mem; 
                disable_fetch <= any_access_mem;
                haddr_ctrl <= sel_hardd_NC;
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;   
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_SVC_PUSH_R0 =>
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= true; 
                disable_fetch <= true;
                haddr_ctrl <= sel_SP_main_addr_SVC;
                gp_data_in_ctrl <= sel_gp_data_in_NC; 
                hrdata_ctrl <= sel_SVC;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;       
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_SVC_PUSH_R1 =>
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= true; 
                disable_fetch <= true;
                haddr_ctrl <= sel_SP_main_addr_SVC;
                gp_data_in_ctrl <= sel_gp_data_in_NC; 
                hrdata_ctrl <= sel_SVC;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;       
                SDC_push_read_address <= SDC_read_R1;
                inst32_tempor <= false;
            when s_SVC_PUSH_R2 =>
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= true; 
                disable_fetch <= true;
                haddr_ctrl <= sel_SP_main_addr_SVC;
                gp_data_in_ctrl <= sel_gp_data_in_NC; 
                hrdata_ctrl <= sel_SVC;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;       
                SDC_push_read_address <= SDC_read_R2;
                inst32_tempor <= false;
            when s_SVC_PUSH_R3 =>
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= true; 
                disable_fetch <= true;
                haddr_ctrl <= sel_SP_main_addr_SVC;
                gp_data_in_ctrl <= sel_gp_data_in_NC; 
                hrdata_ctrl <= sel_SVC;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;       
                SDC_push_read_address <= SDC_read_R3;
                inst32_tempor <= false;
            when s_SVC_PUSH_R12 =>
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= true; 
                disable_fetch <= true;
                haddr_ctrl <= sel_SP_main_addr_SVC;
                gp_data_in_ctrl <= sel_gp_data_in_NC; 
                hrdata_ctrl <= sel_SVC;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;       
                SDC_push_read_address <= SDC_read_R12;
                inst32_tempor <= false;
            when s_SVC_PUSH_R14 =>
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= true; 
                disable_fetch <= true;
                haddr_ctrl <= sel_SP_main_addr_SVC;
                gp_data_in_ctrl <= sel_gp_data_in_NC; 
                hrdata_ctrl <= sel_SVC;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;       
                SDC_push_read_address <= SDC_read_R14;
                inst32_tempor <= false;
             when s_SVC_PUSH_RETURN_ADDR =>
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= true; 
                disable_fetch <= true;
                haddr_ctrl <= sel_SP_main_addr_SVC;
                gp_data_in_ctrl <= sel_gp_data_in_NC; 
                hrdata_ctrl <= sel_SVC;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;       
                SDC_push_read_address <= SDC_read_retuen_addr;
                inst32_tempor <= false;
            when s_SVC_PUSH_xPSR =>
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= true; 
                disable_fetch <= true;
                haddr_ctrl <= sel_SP_main_addr_SVC;
                gp_data_in_ctrl <= sel_gp_data_in_NC; 
                hrdata_ctrl <= sel_SVC;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '1'; 
                VT_ctrl <= VT_NONE;       
                SDC_push_read_address <= SDC_read_xPSR;  
                inst32_tempor <= false;            
            when s_SVC_FETCH_NEW_PC =>    
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= true; 
                disable_fetch <= true;
                haddr_ctrl <= sel_VECTOR_TABLE;
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_SVC;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_SVCall;    
                SDC_push_read_address <= SDC_read_R0; 
                inst32_tempor <= false;
            when s_SVC_PC_UPDATED =>    
                LDM_cur_target_reg <= REG_PC;  
                LDM_STM_capture_base <= false; 
                refetch_i <= true; 
                disable_fetch <= true;
                haddr_ctrl <= sel_SVC_mem_content;
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_SVC;  
                disable_executor <= true; 
                gp_addrA_executor_ctrl <= false;  
                HWRITE <= '0'; 
                VT_ctrl <= VT_SVCall;    
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_INST32_DETECTED =>
--               refetch_i <= false; 
--                gp_data_in_ctrl <= sel_gp_data_in_NC; 
--                if (PC(1) = '0') then
--                    -- LDR is located in position A: 
--                    hrdata_ctrl <= sel_ALU_RESULT;      -- Update hrdata_program_value   
--                else
--                    -- LDR is located in position B:
--                    if (pos_A_is_multi_cycle = true) then 
--                        hrdata_ctrl <= sel_NC;          -- Do not update hrdata_program_value
--                    else
--                        hrdata_ctrl <= sel_ALU_RESULT;      -- Update hrdata_program_value       
--                    end if;    
--                end if;
--                disable_executor <= true; 
--                if (PC(1) = '1') then
--                    disable_fetch <= false;
--                else
--                    disable_fetch <= any_access_mem;
--                end if;
--                haddr_ctrl <= sel_PC;
--                gp_addrA_executor_ctrl <= false; 
--                LDM_cur_target_reg <= REG_NONE;
--                LDM_STM_capture_base <= false; 
--                HWRITE <= '0'; 
--                VT_ctrl <= VT_NONE;
--                SDC_push_read_address <= SDC_read_R0;
--                inst32_tempor <= false;
                refetch_i <= any_access_mem; 
                gp_data_in_ctrl <= sel_ALU_RESULT; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_executor <= false; 
                haddr_ctrl <= sel_PC;
                disable_fetch <= any_access_mem;
                LDM_cur_target_reg <= REG_NONE;
                gp_addrA_executor_ctrl <= false; 
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
            when s_MRS =>
--                refetch_i <= any_access_mem; 
--                gp_data_in_ctrl <= sel_special_reg;  
--                hrdata_ctrl <= sel_ALU_RESULT; 
--                disable_fetch <= any_access_mem; 
--                disable_executor <= false; 
--                haddr_ctrl <= sel_PC;
--                gp_addrA_executor_ctrl <= false;
--                LDM_STM_capture_base <= false; 
--                LDM_cur_target_reg <= REG_NONE;
--                HWRITE <= '0'; 
--                VT_ctrl <= VT_NONE;
--                SDC_push_read_address <= SDC_read_R0;
--                inst32_tempor <= false;
                refetch_i <= any_access_mem; 
                gp_data_in_ctrl <= sel_special_reg; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_executor <= false; 
                haddr_ctrl <= sel_PC;
                disable_fetch <= any_access_mem;
                LDM_cur_target_reg <= REG_NONE;
                gp_addrA_executor_ctrl <= false; 
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_MSR =>
--                refetch_i <= any_access_mem; 
--                gp_data_in_ctrl <= sel_Rn;  
--                hrdata_ctrl <= sel_ALU_RESULT; 
--                disable_fetch <= any_access_mem; 
--                disable_executor <= true; 
--                haddr_ctrl <= sel_PC;
--                gp_addrA_executor_ctrl <= false;
--                LDM_STM_capture_base <= false; 
--                LDM_cur_target_reg <= REG_NONE;
--                HWRITE <= '0'; 
--                VT_ctrl <= VT_NONE;
--                SDC_push_read_address <= SDC_read_R0;
--                inst32_tempor <= false;
                refetch_i <= any_access_mem; 
                gp_data_in_ctrl <= sel_Rn; 
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                disable_fetch <= any_access_mem;
                LDM_cur_target_reg <= REG_NONE;
                gp_addrA_executor_ctrl <= false; 
                LDM_STM_capture_base <= false; 
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
           when s_ISB | s_DMB | s_DSB =>        
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                hrdata_ctrl <= sel_ALU_RESULT; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= false;
                LDM_STM_capture_base <= false; 
                LDM_cur_target_reg <= REG_NONE;
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;   
                 
                
                
               
                
          
        
            when others => 
                refetch_i <= false; 
                gp_data_in_ctrl <= sel_gp_data_in_NC;  
                hrdata_ctrl <= sel_NC; 
                disable_fetch <= false; 
                disable_executor <= true; 
                haddr_ctrl <= sel_PC;
                gp_addrA_executor_ctrl <= false;
                LDM_STM_capture_base <= false; 
                LDM_cur_target_reg <= REG_NONE;
                HWRITE <= '0'; 
                VT_ctrl <= VT_NONE;
                SDC_push_read_address <= SDC_read_R0;
                inst32_tempor <= false;
        end case;
    end process;       
 end Behavioral;
