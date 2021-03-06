----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/24/2020 10:15:07 PM
-- Design Name: 
-- Module Name: decoder - Behavioral
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

entity decoder is
    Port ( 
        clk : in std_logic;
        reset : in std_logic;
        instruction : in std_logic_vector (15 downto 0);
        inst32_detected_in_prev_inst : in boolean;
        inst32_detected : out boolean;
        destination_is_PC : out boolean;
        gp_WR_addr : out std_logic_vector (3 downto 0);
        gp_addrA : out std_logic_vector (3 downto 0);
        gp_addrB : out std_logic_vector (3 downto 0);
        gp_addrC : out std_logic_vector (3 downto 0);
        imm8 : out std_logic_vector (7 downto 0);
        LR_PC : out std_logic;
        execution_cmd : out executor_cmds_t;
        access_mem : out boolean;
        use_base_register : out boolean;
        mem_load_size : out mem_op_size_t;
        mem_load_sign_ext : out boolean;
        LDM_STM_access_mem : out boolean;
        access_mem_mode : out access_mem_mode_t;
        cond : out std_logic_vector (3 downto 0);
        prev_inst: out std_logic_vector (15 downto 0);
        is_ALU_instruction: out boolean
    );
end decoder;

architecture Behavioral of decoder is
    signal is_shift_class_instruction : std_logic;               -- 0 : is not shift class, 1: is shift class. 
    
--    signal inst32_detected : boolean;
    alias opcode: STD_LOGIC_VECTOR (5 downto 0) is instruction (15 downto 10);               -- bits (15 downto 10)

begin

--     instruction_size_p: process(instruction) begin
--       -- false = 16-bit (2 bytes), true = 32-bit (4 bytes) 
--        case instruction(15 downto 11) is
--            --when B"11101" =>   instruction_size <= true;
--            when B"11110" =>   instruction_size <= true;
--            --when B"11111" =>   instruction_size <= true;
--            when others => instruction_size <= false;
--        end case;
--    end process;

    prev_inst_p: process(clk, reset) begin
        if (reset = '1') then
            prev_inst <= x"0000";
        else
             if (rising_edge(clk)) then
                prev_inst <= instruction;
             end if;
        end if;   
    end process;

   inst32_detected_p: process(instruction (15 downto 11)) begin
--        if (inst32_detected_in_prev_inst = true) then
--             inst32_detected <= false;
--        else
            if std_match(instruction(15 downto 11), "11110") then
                inst32_detected <= true;        
            else
                inst32_detected <= false;
            end if;
--        end if;
    end process;
    
    decode_shift_op_p: process (instruction, prev_inst, inst32_detected, inst32_detected_in_prev_inst) begin
        if (inst32_detected_in_prev_inst = true) then
            if std_match(instruction(14 downto 12), "1-1") then
                -- BL
                gp_WR_addr <= B"1110";                                      -- Link register    = r14
                gp_addrA <= '0' & instruction (10 downto 8);                -- imm11 (10 downto 8) = <label>                   
                gp_addrB <= B"00" & instruction (13) & instruction (11);    -- J1, J2
                gp_addrC <=  B"0000";                                       -- Will not be used '0' 
                imm8 <= instruction (7 downto 0);                           -- imm11 (7 downto 0) = <label>
                execution_cmd <= BL;
                destination_is_PC <= true;  
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= WORD;
                mem_load_sign_ext <= false;   
                LDM_STM_access_mem <= false;     
                access_mem_mode <= MEM_ACCESS_READ;
                LR_PC <= '0';         
                cond <=  B"1111";  
            elsif  std_match(prev_inst(10 downto 4), "011111-") then
                -- MRS <Rd>,<spec_reg>
                gp_WR_addr <= instruction (11 downto 8);                    -- Rd                  
                gp_addrA <= B"0000";                                        -- Will not be used '0'            
                gp_addrB <= B"0000";                                        -- Will not be used '0' 
                gp_addrC <= B"0000";                                        -- Will not be used '0' 
                imm8 <= instruction (7 downto 0);                           -- SYSm
                execution_cmd <= MRS;
                destination_is_PC <= false;  
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= WORD;
                mem_load_sign_ext <= false;   
                LDM_STM_access_mem <= false;     
                access_mem_mode <= MEM_ACCESS_READ;
                LR_PC <= '0';         
                cond <=  B"1111";  
            elsif  std_match(prev_inst(10 downto 4), "011100-") then
                -- MSR <spec_reg>,<Rn>
                gp_WR_addr <= B"0000";                                      -- Will not be used '0'                  
                gp_addrA <= B"0000";                                        -- Will not be used '0'                  
                gp_addrB <= B"0000";                                        -- Will not be used '0' 
                gp_addrC <= B"0000";                                        -- Will not be used '0' 
                imm8 <= instruction (7 downto 0);                           -- SYSm
                execution_cmd <= MSR;
                destination_is_PC <= false;  
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= WORD;
                mem_load_sign_ext <= false;   
                LDM_STM_access_mem <= false;     
                access_mem_mode <= MEM_ACCESS_READ;
                LR_PC <= '0';         
                cond <=  B"1111";  
           
            elsif  std_match(prev_inst(10 downto 4), "0111011") and std_match(instruction(7 downto 4), "0100") then
                -- DSB
                gp_WR_addr <= B"0000";                                      -- Will not be used '0'                  
                gp_addrA <= B"0000";                                        -- Will not be used '0'         
                gp_addrB <= B"0000";                                        -- Will not be used '0' 
                gp_addrC <= B"0000";                                        -- Will not be used '0' 
                imm8 <= B"0000" & instruction (3 downto 0);                           -- option
                execution_cmd <= DSB;
                destination_is_PC <= false;  
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= WORD;
                mem_load_sign_ext <= false;   
                LDM_STM_access_mem <= false;     
                access_mem_mode <= MEM_ACCESS_READ;
                LR_PC <= '0';         
                cond <=  B"1111"; 
            elsif  std_match(prev_inst(10 downto 4), "0111011") and std_match(instruction(7 downto 4), "0101") then
                -- DMB
                gp_WR_addr <= B"0000";                                      -- Will not be used '0'                  
                gp_addrA <= B"0000";                                        -- Will not be used '0'         
                gp_addrB <= B"0000";                                        -- Will not be used '0' 
                gp_addrC <= B"0000";                                        -- Will not be used '0' 
                imm8 <= B"0000" & instruction (3 downto 0);                           -- option
                execution_cmd <= DMB;
                destination_is_PC <= false;  
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= WORD;
                mem_load_sign_ext <= false;   
                LDM_STM_access_mem <= false;     
                access_mem_mode <= MEM_ACCESS_READ;
                LR_PC <= '0';         
                cond <=  B"1111"; 
            elsif  std_match(prev_inst(10 downto 4), "0111011") and std_match(instruction(7 downto 4), "0110") then
                -- ISB
                gp_WR_addr <= B"0000";                                      -- Will not be used '0'                  
                gp_addrA <= B"0000";                                        -- Will not be used '0'         
                gp_addrB <= B"0000";                                        -- Will not be used '0' 
                gp_addrC <= B"0000";                                        -- Will not be used '0' 
                imm8 <= B"0000" & instruction (3 downto 0);                           -- option
                execution_cmd <= ISB;
                destination_is_PC <= false;  
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= WORD;
                mem_load_sign_ext <= false;   
                LDM_STM_access_mem <= false;     
                access_mem_mode <= MEM_ACCESS_READ;
                LR_PC <= '0';         
                cond <=  B"1111";
--            else    
--                report "Unknown 32-bit instruction. Exception must be raised." severity error;                
            end if;       
        else
            if (inst32_detected = false) then
                ----------------------------------------------------------------------------------- -- MOVS Rd, #<imm8>
                if std_match(opcode, "00100-") then                                                 
                    gp_WR_addr <= '0' & instruction (10 downto 8); -- Rd 
                    gp_addrA <= B"0000";
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);
                    execution_cmd <= MOVS_imm8;
                    destination_is_PC <= false;
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- ADR Rd, #<imm8>
                elsif std_match(opcode, "10100-") then                                                 
                    gp_WR_addr <= '0' & instruction (10 downto 8); -- Rd 
                    gp_addrA <= B"0000";
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);
                    execution_cmd <= ADR;
                    destination_is_PC <= false;
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- MOVS <Rd>,<Rm> 
                elsif (std_match(opcode, "000000") and instruction(9 downto 6) = "0000") then         
                    gp_WR_addr <= '0' & instruction (2 downto 0); -- Rd 
                    gp_addrA <= '0' & instruction (5 downto 3); -- Rm
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= (others => '0');
                    execution_cmd <= MOVS;
                    destination_is_PC <= false;
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- MOV <Rd>,<Rm>
                elsif (std_match(opcode, "010001") and instruction(9 downto 8) = "10") then         
                    gp_WR_addr <= instruction(7) & instruction (2 downto 0);    -- Rd
                    gp_addrA <= instruction (6 downto 3);                       -- Rn
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= (others => '0');
                    execution_cmd <= MOV;
                    if ((instruction(7) & instruction (2 downto 0)) = B"1111" ) then    -- check if destination is PC ?
                        destination_is_PC <= true;
                    else
                        destination_is_PC <= false;
                    end if;
                    use_base_register <= false;   
                    access_mem <= false;    
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,#<imm3>   
                elsif (std_match(opcode, "000111") and instruction(9) = '0') then                   
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                    gp_addrA <= '0' & instruction (5 downto 3);             -- Rn 
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"00000" & instruction (8 downto 6);            -- imm3
                    execution_cmd <= ADDS_imm3;
                    destination_is_PC <= false;
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,<Rm>   
                elsif (std_match(opcode, "000110") and instruction(9) = '0') then                   
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                    gp_addrA <= '0' & instruction (8 downto 6);             -- Rm
                    gp_addrB <= '0' & instruction (5 downto 3);             -- Rn
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= ADDS;
                    destination_is_PC <= false;
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- ADD <Rdn>,<Rm> - ADD PC,<Rm>   
                elsif (std_match(opcode, "010001") and instruction(9 downto 8) = B"00") then        
                    gp_WR_addr <= instruction(7) & instruction (2 downto 0);    -- Rdn
                    gp_addrA <= instruction(7) & instruction (2 downto 0);      -- Rdn
                    gp_addrB <= instruction (6 downto 3);                       -- Rm 
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    if ((instruction(7) & instruction (2 downto 0)) = B"1111" ) then    -- check if destination is PC ?
                        execution_cmd <= ADD_PC;
                        destination_is_PC <= true;
                    else
                        execution_cmd <= ADD;
                        destination_is_PC <= false;
                    end if;
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- ADDS <Rdn>,#<imm8>   
                elsif (std_match(opcode, "00110-")) then                                            
                    gp_WR_addr <= '0' & instruction (10 downto 8);          -- Rdn
                    gp_addrA <= '0' & instruction (10 downto 8);            -- Rdn
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                       -- imm8
                    execution_cmd <= ADDS_imm8;
                    destination_is_PC <= false;
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- ADCS <Rdn>,<Rm>   
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0101") then      
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdn
                    gp_addrA <= '0' & instruction (2 downto 0);             -- Rdn
                    gp_addrB <= '0' & instruction (5 downto 3);             -- Rm 
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= ADCS;
                    destination_is_PC <= false;
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- ADD <Rd>,SP,#<imm8>  
                elsif (std_match(opcode, "10101-")) then                   
                    gp_WR_addr <= '0' & instruction (10 downto 8);          -- Rd
                    gp_addrA <= B"0000";                    
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                       -- imm8
                    execution_cmd <= ADD_SP_imm8;
                    destination_is_PC <= false;
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- ADD SP,SP,#<imm7>  
                elsif (std_match(opcode, "101100") and instruction(9 downto 7) = B"000") then                   
                    gp_WR_addr <=  B"1101";                                  -- SP
                    gp_addrA <= B"0000";                    
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= '0' & instruction (6 downto 0);                 -- imm7
                    execution_cmd <= ADD_SP_SP_imm7;
                    destination_is_PC <= false;
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";    
                ----------------------------------------------------------------------------------- -- SUBS <Rd>,<Rn>,<Rm>   
                elsif (std_match(opcode, "000110") and instruction(9) = '1') then                   
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                    gp_addrA <= '0' & instruction (5 downto 3);             -- Rn
                    gp_addrB <= '0' & instruction (8 downto 6);             -- Rm
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= SUBS;
                    destination_is_PC <= false;    
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- SUBS <Rd>,<Rn>,#<imm3>   
                elsif (std_match(opcode, "000111") and instruction(9) = '1') then                   
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                    gp_addrA <= '0' & instruction (5 downto 3);             -- Rn 
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"00000" & instruction (8 downto 6);            -- imm3
                    execution_cmd <= SUBS_imm3;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- SUBS <Rdn>,#<imm8> 
                elsif (std_match(opcode, "00111-")) then                                              
                    gp_WR_addr <= '0' & instruction (10 downto 8);          -- Rdn
                    gp_addrA <= '0' & instruction (10 downto 8);            -- Rdn
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                       -- imm8
                    execution_cmd <= SUBS_imm8;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- SBCS <Rdn>,<Rm>   
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0110") then        
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdn
                    gp_addrA <= '0' & instruction (2 downto 0);             -- Rdn
                    gp_addrB <= '0' & instruction (5 downto 3);             -- Rm 
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= SBCS;
                    destination_is_PC <= false;
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
               ----------------------------------------------------------------------------------- -- RSBS <Rd>,<Rn>,#0   
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1001") then        
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                    gp_addrA <= '0' & instruction (5 downto 3);             -- Rn
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= RSBS;
                    destination_is_PC <= false;   
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- --SUB SP,SP,#<imm7> 
                elsif (std_match(opcode, "101100") and instruction(9 downto 7) = B"001") then                   
                    gp_WR_addr <= B"1101";                                  -- SP
                    gp_addrA <= B"0000";                    
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= '0' & instruction (6 downto 0);                 -- imm7
                    execution_cmd <= SUB_SP_imm7;
                    destination_is_PC <= false;
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
               ----------------------------------------------------------------------------------- -- MULS <Rdm>,<Rn>,<Rdm>    
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1101") then        
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdm
                    gp_addrA <= '0' & instruction (2 downto 0);             -- Rdm
                    gp_addrB <= '0' & instruction (5 downto 3);             -- Rn
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= MULS;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
               ----------------------------------------------------------------------------------- -- CMP <Rn>,<Rm>   T1  
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1010") then        
                    gp_addrA <= '0' & instruction (2 downto 0);             -- Rn
                    gp_addrB <= '0' & instruction (5 downto 3);             -- Rm
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= CMP;
                    destination_is_PC <= false;    
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- CMP <Rn>,<Rm>   T2  
                elsif (std_match(opcode, "010001") and instruction(9 downto 8) = B"01") then        
                    gp_addrA <= instruction(7) & instruction (2 downto 0);  -- Rn
                    gp_addrB <= instruction (6 downto 3);                   -- Rm
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= CMP;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- CMN <Rn>,<Rm>     
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1011") then        
                    gp_addrA <= '0' & instruction (2 downto 0);             -- Rn
                    gp_addrB <= '0' & instruction (5 downto 3);             -- Rm
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= CMN;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- CMP <Rn>,#<imm8>     
                elsif (std_match(opcode, "00101-")) then        
                    gp_addrA <= '0' & instruction (10 downto 8);             -- Rn
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                        -- imm8
                    execution_cmd <= CMP_imm8;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- ANDS <Rdn>,<Rm>    
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0000") then       
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (2 downto 0);              -- Rn
                    gp_addrB <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= ANDS;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- EORS <Rdn>,<Rm>  
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0001") then       
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (2 downto 0);              -- Rn
                    gp_addrB <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= EORS;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- ORRS <Rdn>,<Rm>  
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1100") then       
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (2 downto 0);              -- Rn
                    gp_addrB <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= ORRS;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- BICS <Rdn>,<Rm>  
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1110") then       
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (2 downto 0);              -- Rn
                    gp_addrB <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= BICS;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- MVNS <Rd>,<Rm>  
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1111") then       
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= MVNS;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- TST <Rn>,<Rm>  
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1000") then       
                    gp_addrA <= '0' & instruction (2 downto 0);              -- Rn
                    gp_addrB <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= TST;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LSLS <Rd>,<Rm>,#<imm5>
                elsif (std_match(opcode, "00000-")) then  
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                    gp_addrA <= '0' & instruction (5 downto 3);             -- Rm
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"000" & instruction (10 downto 6);            -- imm5
                    execution_cmd <= LSLS_imm5;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LSLS <Rdn>,<Rm>
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0010") then  
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdn
                    gp_addrA <= '0' & instruction (2 downto 0);             -- Rdn
                    gp_addrB <=  '0' & instruction (5 downto 3);            -- Rm
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= LSLS;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LSRS <Rd>,<Rm>,#<imm5>
                elsif (std_match(opcode, "00001-")) then  
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                    gp_addrA <= '0' & instruction (5 downto 3);             -- Rm
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"000" & instruction (10 downto 6);            -- imm5
                    execution_cmd <= LSRS_imm5;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LSRS <Rdn>,<Rm>
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0011") then  
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdn
                    gp_addrA <= '0' & instruction (2 downto 0);             -- Rdn
                    gp_addrB <=  '0' & instruction (5 downto 3);            -- Rm
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= LSRS;
                    destination_is_PC <= false;       
                    access_mem <= false;  
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
             ----------------------------------------------------------------------------------- -- ASRS <Rd>,<Rm>,#<imm5>
                elsif (std_match(opcode, "00010-")) then  
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                    gp_addrA <= '0' & instruction (5 downto 3);             -- Rm
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"000" & instruction (10 downto 6);             -- imm5
                    execution_cmd <= ASRS_imm5;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
            ----------------------------------------------------------------------------------- -- ASRS <Rdn>,<Rm>
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0100") then  
                    gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdn
                    gp_addrA <= '0' & instruction (2 downto 0);             -- Rdn
                    gp_addrB <=  '0' & instruction (5 downto 3);            -- Rm
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= ASRS;
                    destination_is_PC <= false;       
                    access_mem <= false;      
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- RORS <Rdn>,<Rm>
                elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0111") then       
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (2 downto 0);              -- Rn
                    gp_addrB <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= RORS;
                    destination_is_PC <= false;       
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= NOT_DEF;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_NONE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LDR <Rt>,[<Rn>{,#<imm5>}]
                elsif (std_match(opcode, "01101-") ) then       
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt (target)
                    gp_addrA <=  '0' & instruction (5 downto 3);             -- Rn (base)
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= B"000" & instruction (10 downto 6);              -- imm5 (index)
                    execution_cmd <= LDR_imm5;
                    destination_is_PC <= false;    
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LDR <Rt>,[SP{,#<imm8>}]
                elsif (std_match(opcode, "10011-") ) then       
                    gp_WR_addr <= '0' & instruction (10 downto 8);            -- Rt (target)
                    gp_addrA <= B"1101";                                      -- SP (base)
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                     -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                         -- imm8 (index)
                    execution_cmd <= LDR_SP_imm8;
                    destination_is_PC <= false;    
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';
                    cond <= B"1111";                ----------------------------------------------------------------------------------- -- LDRH <Rt>,[<Rn>{,#<imm5>}]
                elsif (std_match(opcode, "10001-") ) then      
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt    
                    gp_addrA <=  '0' & instruction (5 downto 3);             -- Rn
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= B"000" & instruction (10 downto 6);              -- imm5
                    execution_cmd <= LDRH_imm5;
                    destination_is_PC <= false;    
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= HALF_WORD;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LDRB <Rt>,[<Rn>{,#<imm5>}]
                elsif (std_match(opcode, "01111-")) then  
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt     
                    gp_addrA <=  '0' & instruction (5 downto 3);             -- Rn
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= B"000" & instruction (10 downto 6);              -- imm5
                    execution_cmd <= LDRB_imm5;
                    destination_is_PC <= false;    
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= BYTE;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LDR <Rt>,[<Rn>,<Rm>]
                elsif (std_match(opcode, "010110") and instruction(9) = '0') then       
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rn
                    gp_addrB <= '0' & instruction (8 downto 6);              -- Rm
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= LDR;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LDRH <Rt>,[<Rn>,<Rm>]
                elsif (std_match(opcode, "010110") and instruction(9) = '1') then       
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rn
                    gp_addrB <= '0' & instruction (8 downto 6);              -- Rm
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= LDRH;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= HALF_WORD;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';
                ----------------------------------------------------------------------------------- -- LDRSH <Rt>,[<Rn>,<Rm>]
                elsif (std_match(opcode, "010111") and instruction(9) = '1') then       
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rn
                    gp_addrB <= '0' & instruction (8 downto 6);              -- Rm
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= LDRSH;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= HALF_WORD;
                    mem_load_sign_ext <= true;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LDRB <Rt>,[<Rn>,<Rm>]
                elsif (std_match(opcode, "010111") and instruction(9) = '0')  then       
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rn
                    gp_addrB <= '0' & instruction (8 downto 6);              -- Rm
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= LDRB;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= BYTE;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LDRSB <Rt>,[<Rn>,<Rm>]
                elsif (std_match(opcode, "010101") and instruction(9) = '1')  then       
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rn
                    gp_addrB <= '0' & instruction (8 downto 6);              -- Rm
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= LDRSB;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= BYTE;
                    mem_load_sign_ext <= true;  
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LDR <Rt>,<label> 
                elsif (std_match(opcode, "01001-") ) then       
                    gp_WR_addr <= '0' & instruction (10 downto 8);           -- Rt
                    gp_addrA <= B"0000";
                    gp_addrB <= B"0000";
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                        -- imm8 <label>
                    execution_cmd <= LDR_label;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- LDM <Rn>!,<registers>
                elsif (std_match(opcode, "11001-"))  then       
                    gp_WR_addr <= B"0000";
                    gp_addrA <= '0' & instruction (10 downto 8);             -- Rn        
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                        -- imm8 = <registers>
                    execution_cmd <= LDM;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= true; 
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';
                    cond <= B"1111";
                ---------------------------------------------------------------------------------- -- STR <Rt>, [<Rn>{,#<imm5>}]
                elsif (std_match(opcode, "01100-") ) then       
                    gp_WR_addr <= B"0000";                                  -- Will not be used '0' 
                    gp_addrA <= '0' & instruction (5 downto 3);             -- Rn (base)
                    gp_addrB <= '0' & instruction (2 downto 0);             -- Rt (target)
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"000" & instruction (10 downto 6);             -- imm5 (index)
                    execution_cmd <= STR_imm5;
                    destination_is_PC <= false;    
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_WRITE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ---------------------------------------------------------------------------------- -- STRH <Rt>,[<Rn>{,#<imm5>}]
                elsif (std_match(opcode, "10000-") ) then      
                    gp_WR_addr <= B"0000";                                   -- Will not be used '0' 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rn (base)
                    gp_addrB <= '0' & instruction (2 downto 0);              -- Rt (target)
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= B"000" & instruction (10 downto 6);              -- imm5 (index)
                    execution_cmd <= STRH_imm5;
                    destination_is_PC <= false;    
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= HALF_WORD;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_WRITE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ---------------------------------------------------------------------------------- -- STRB <Rt>,[<Rn>{,#<imm5>}]
                elsif (std_match(opcode, "01110-")) then  
                    gp_WR_addr <= B"0000";                                   -- Will not be used '0' 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rn (base)
                    gp_addrB <= '0' & instruction (2 downto 0);              -- Rt (target)
                    gp_addrC <=  B"0000";                                    -- Will not be used '0' 
                    imm8 <= B"000" & instruction (10 downto 6);              -- imm5 (index)
                    execution_cmd <= STRB_imm5;
                    destination_is_PC <= false;    
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= BYTE;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false;   
                    access_mem_mode <= MEM_ACCESS_WRITE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ---------------------------------------------------------------------------------- -- STR <Rt>,[<Rn>,<Rm>]
                elsif (std_match(opcode, "010100") and instruction(9) = '0') then       
                    gp_WR_addr <= B"0000";                                   -- Will not be used '0' 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rn (base)
                    gp_addrB <= '0' & instruction (2 downto 0);              -- Rt
                    gp_addrC <= '0' & instruction (8 downto 6);              -- Rm (index) 
                    imm8 <= B"0000_0000";
                    execution_cmd <= STR;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_WRITE;
                    LR_PC <= '0';
                    cond <= B"1111";
              ----------------------------------------------------------------------------------- -- STRH <Rt>,[<Rn>,<Rm>]
                elsif (std_match(opcode, "010100") and instruction(9) = '1') then       
                    gp_WR_addr <= B"0000";                                   -- Will not be used '0' 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rn (base)
                    gp_addrB <= '0' & instruction (2 downto 0);              -- Rt
                    gp_addrC <= '0' & instruction (8 downto 6);              -- Rm (index) 
                    imm8 <= B"0000_0000";
                    execution_cmd <= STRH;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= HALF_WORD;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_WRITE;
                    LR_PC <= '0';
                    cond <= B"1111";
               ----------------------------------------------------------------------------------- -- STRB <Rt>,[<Rn>,<Rm>]
                elsif (std_match(opcode, "010101") and instruction(9) = '0')  then       
                    gp_WR_addr <= B"0000";                                   -- Will not be used '0' 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rn (base)
                    gp_addrB <= '0' & instruction (2 downto 0);              -- Rt
                    gp_addrC <= '0' & instruction (8 downto 6);              -- Rm (index) 
                    imm8 <= B"0000_0000";
                    execution_cmd <= STRB;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= BYTE;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false; 
                    access_mem_mode <= MEM_ACCESS_WRITE;
                    LR_PC <= '0';
                    cond <= B"1111";
                 ----------------------------------------------------------------------------------- -- STR <Rt>,[SP,#<imm8>]    
                elsif (std_match(opcode, "10010-") ) then       
                    gp_WR_addr <= B"0000";                                   -- Will not be used '0' 
                    gp_addrA   <= B"0000";                                   -- inferred: SP (base)
                    gp_addrB   <= '0' & instruction (10 downto 8);           -- Rt (target)
                    gp_addrC   <= B"0000";                                   -- Will not be used '0' 
                    imm8       <= instruction (7 downto 0);        -- imm5 (index)
                    execution_cmd <= STR_SP_imm8;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_WRITE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- STM <Rn>!,<registers>
                elsif (std_match(opcode, "11000-"))  then       
                    gp_WR_addr <= B"0000";
                    gp_addrA <= '0' & instruction (10 downto 8);            -- Rn        
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                       -- imm8 = <registers>
                    execution_cmd <= STM;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= true;     
                    access_mem_mode <= MEM_ACCESS_WRITE;
                    LR_PC <= '0';
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- PUSH <registers>
                elsif (std_match(opcode, "101101") and instruction(9) = '0')  then       
                    gp_WR_addr <= B"0000";
                    gp_addrA <= B"0000" ;                     
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                       -- imm8 = <registers>
                    execution_cmd <= PUSH;
                    destination_is_PC <= false;   
                    access_mem <= true;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_WRITE;
                    LR_PC <= instruction (8);
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- POP <registers>
                elsif (std_match(opcode, "101111") and instruction(9) = '0')  then       
                    gp_WR_addr <= B"0000";
                    gp_addrA <= B"0000" ;                     
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                       -- imm8 = <registers>
                    execution_cmd <= POP;
                    if (instruction (8) = '1') then
                        destination_is_PC <= true;  
                    else
                        destination_is_PC <= false; 
                    end if;     
                    access_mem <= true;    
                    use_base_register <= true;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= true;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= instruction (8);  
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- SVC #<imm8>
                elsif (std_match(opcode, "110111") and instruction(9 downto 8) = B"11")  then       
                    gp_WR_addr <= B"0000";
                    gp_addrA <=  B"0000";                                   -- Will not be used '0'              
                    gp_addrB <= B"0000";                                    -- Read register R0  
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                       -- imm8 
                    execution_cmd <= SVC;
                    destination_is_PC <= true;  
                    access_mem <= false;    
                    use_base_register <= true;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111";          
                ----------------------------------------------------------------------------------- -- B <label>    T1 (Conditional)
                elsif (std_match(opcode, "1101--"))  then       
                    gp_WR_addr <= B"0000";
                    gp_addrA <= B"0000" ;                     
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                       -- imm8 = <label>
                    execution_cmd <= BRANCH;
                    destination_is_PC <= true;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= instruction (11 downto 8);                      -- condition
                ----------------------------------------------------------------------------------- -- B <label>    T2 (Unconditional)
                elsif (std_match(opcode, "11100-"))  then       
                    gp_WR_addr <= B"0000";
                    gp_addrA <= '0' & instruction (10 downto 8);            -- imm11 (10 downto 8) = <label>                   
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= instruction (7 downto 0);                       -- imm11 (7 downto 0) = <label>
                    execution_cmd <= BRANCH_imm11;
                    destination_is_PC <= true;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111";      
                ----------------------------------------------------------------------------------- -- BL <label> HI
--                elsif (std_match(opcode, "11110-"))  then       
--                    gp_WR_addr <= B"1110";                                  -- Link register    = r14
--                    gp_addrA <= '0' & instruction (10 downto 8);            -- BL_S & imm10 (10 downto 8) = <label>                   
--                    gp_addrB <= B"0000";   
--                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
--                    imm8 <= instruction (7 downto 0);                       -- imm10 (7 downto 0) = <label>
--                    execution_cmd <= BL;
--                    destination_is_PC <= true;  
--                    access_mem <= false;    
--                    use_base_register <= false;   
--                    mem_load_size <= WORD;
--                    mem_load_sign_ext <= false;   
--                    LDM_STM_access_mem <= false;     
--                    access_mem_mode <= MEM_ACCESS_READ;
--                    LR_PC <= '0';         
--                    cond <=  B"1111";    
                ----------------------------------------------------------------------------------- -- BX Rm 
                elsif (std_match(opcode, "010001") and instruction(9 downto 7) = B"110")  then       
                    gp_WR_addr <= B"0000";
                    gp_addrA <= instruction (6 downto 3);                   -- Rm               
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= BX;
                    destination_is_PC <= true;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111";   
                ----------------------------------------------------------------------------------- -- BLX Rm
                elsif (std_match(opcode, "010001") and instruction(9 downto 7) = B"111")  then       
                    gp_WR_addr <= B"0000";
                    gp_addrA <= instruction (6 downto 3);                   -- Rm               
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= BLX;
                    destination_is_PC <= true;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111";     
                ----------------------------------------------------------------------------------- -- SXTH <Rd>,<Rm>
                elsif (std_match(opcode, "101100") and instruction(9 downto 6) = B"1000")  then    
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= SXTH;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111"; 
                ----------------------------------------------------------------------------------- -- SXTB <Rd>,<Rm>
                elsif (std_match(opcode, "101100") and instruction(9 downto 6) = B"1001")  then    
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= SXTB;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111"; 
                ----------------------------------------------------------------------------------- -- UXTH <Rd>,<Rm> 
                elsif (std_match(opcode, "101100") and instruction(9 downto 6) = B"1010")  then    
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= UXTH;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111"; 
                ----------------------------------------------------------------------------------- -- UXTB <Rd>,<Rm> 
                elsif (std_match(opcode, "101100") and instruction(9 downto 6) = B"1011")  then    
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= UXTB;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111";     
                ----------------------------------------------------------------------------------- -- REV <Rd>,<Rm> 
                elsif (std_match(opcode, "101110") and instruction(9 downto 6) = B"1000")  then    
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= REV;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111";  
                ----------------------------------------------------------------------------------- -- REV16 <Rd>,<Rm> 
                elsif (std_match(opcode, "101110") and instruction(9 downto 6) = B"1001")  then    
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= REV16;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- REVSH <Rd>,<Rm>
                elsif (std_match(opcode, "101110") and instruction(9 downto 6) = B"1011")  then    
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= REVSH;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- CPS<effect> i
                elsif (std_match(opcode, "101101") and instruction(9 downto 5) = B"10011" and 
                        instruction(3 downto 0) = B"0010")  then    
                    gp_WR_addr <= B"0000";
                    gp_addrA <= B"0000";
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_000" & instruction(4);                   -- im
                    execution_cmd <= CPS;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111";
                ----------------------------------------------------------------------------------- -- NOP
                elsif (std_match(opcode, "101111") and instruction(9 downto 0) = B"1100000000")  then    
                    gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                    gp_addrA <= '0' & instruction (5 downto 3);              -- Rm
                    gp_addrB <= B"0000";   
                    gp_addrC <=  B"0000";                                   -- Will not be used '0' 
                    imm8 <= B"0000_0000";
                    execution_cmd <= NOP;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111";
                        
              
                else
                    null;    
                end if;   
            else  -- 32-bit instruction opcode is detected. (HI part)
                ---------------------------------------------------------------------------------- -- INST 32 hi
                if (std_match(opcode, "11110-") )  then    
                    gp_WR_addr <= B"0000";                                  -- Will not be used
                    gp_addrA <= B"0000";                                    -- Will not be used
                    gp_addrB <= B"0000";                                    -- Will not be used        
                    gp_addrC <= B"0000";                                    -- Will not be used 
                    imm8 <= B"0000_0000";                                   -- Will not be used 
                    execution_cmd <= EVAL_32_INSTR;
                    destination_is_PC <= false;  
                    access_mem <= false;    
                    use_base_register <= false;   
                    mem_load_size <= WORD;
                    mem_load_sign_ext <= false;   
                    LDM_STM_access_mem <= false;     
                    access_mem_mode <= MEM_ACCESS_READ;
                    LR_PC <= '0';         
                    cond <= B"1111";    
                 else
                    null;
                 end if;            
            end if;         
        end if;         
    end process;

    is_ALU_instruction_p: process (execution_cmd) begin
        if (execution_cmd = ADDS_imm3 or
            execution_cmd =  ADDS or
            execution_cmd = ADD or
            execution_cmd = ADD_PC or
            execution_cmd = ADDS_imm8 or
            execution_cmd = ADCS or
            execution_cmd = ADD_SP_imm8 or
            execution_cmd = ADD_SP_SP_imm7 or
            execution_cmd = SUBS_imm3 or
            execution_cmd = SUBS or
            execution_cmd = SUBS_imm8 or
            execution_cmd = SBCS or
            execution_cmd = SUB_SP_imm7 or
            execution_cmd = RSBS or
            execution_cmd = MULS or
            execution_cmd = CMP or
            execution_cmd = CMN  or
            execution_cmd = CMP_imm8 or
            execution_cmd = ANDS or
            execution_cmd = EORS or
            execution_cmd = ORRS or
            execution_cmd = BICS or
            execution_cmd = MVNS or
            execution_cmd = TST or
            execution_cmd = RORS or
            execution_cmd = LSLS_imm5 or
            execution_cmd = LSLS or
            execution_cmd = LSRS_imm5 or
            execution_cmd = LSRS  or
            execution_cmd = ASRS_imm5 or
            execution_cmd = ASRS or
            execution_cmd = SXTH or
            execution_cmd = SXTB or
            execution_cmd = UXTH or
            execution_cmd = UXTB or
            execution_cmd = REV or
            execution_cmd = REV16 or
            execution_cmd = REVSH
        ) then
            is_ALU_instruction <= true;
        else
            is_ALU_instruction <= false;
        end if;   
    end process;

    -- base = Align(PC,4);
    -- address = if add then (base + imm32) else (base - imm32);
    -- R[t] = MemU[address,4];
   
    
    -- offset_addr = if add then (R[n] + imm32) else (R[n] - imm32);
    -- address = if index then offset_addr else R[n];
    -- R[t] = MemU[address,4]; 

end Behavioral;
