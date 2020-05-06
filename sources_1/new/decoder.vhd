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
        instruction : in std_logic_vector (15 downto 0);
        instruction_size : out boolean;
        destination_is_PC : out boolean;
        gp_WR_addr : out std_logic_vector (3 downto 0);
        gp_addrA : out std_logic_vector (3 downto 0);
        gp_addrB : out std_logic_vector (3 downto 0);
        imm8 : out std_logic_vector (7 downto 0);
        execution_cmd : out executor_cmds_t;
        access_mem : out boolean;
        use_base_register : out boolean;
        mem_load_size : out mem_op_size_t;
        mem_load_sign_ext : out boolean;
        LDM_access_mem : out boolean
    );
end decoder;

architecture Behavioral of decoder is
    signal is_shift_class_instruction: std_logic;               -- 0 : is not shift class, 1: is shift class. 
    alias opcode: STD_LOGIC_VECTOR (5 downto 0) is instruction (15 downto 10);               -- bits (15 downto 10)
    


begin

     instruction_size_p: process(instruction) begin
       -- false = 16-bit (2 bytes), true = 32-bit (4 bytes) 
        case instruction(15 downto 11) is
            when B"11101" =>   instruction_size <= true;
            when B"11110" =>   instruction_size <= true;
            when B"11111" =>   instruction_size <= true;
            when others => instruction_size <= false;
        end case;
    end process;
    
    decode_shift_op_p: process (instruction) begin
            ----------------------------------------------------------------------------------- -- MOVS Rd, #<imm8>
            if std_match(opcode, "00100-") then                                                 
               gp_WR_addr <= '0' & instruction (10 downto 8); -- Rd 
               gp_addrA <= B"0000";
               gp_addrB <= B"0000";
               imm8 <= instruction (7 downto 0);
               execution_cmd <= MOVS_imm8;
               destination_is_PC <= false;
               access_mem <= false;    
               use_base_register <= false;   
               mem_load_size <= NOT_DEF;
               mem_load_sign_ext <= false;
               LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- MOVS <Rd>,<Rm> 
            elsif (std_match(opcode, "000000") and instruction(9 downto 6) = "0000") then         
                gp_WR_addr <= '0' & instruction (2 downto 0); -- Rd 
                gp_addrA <= '0' & instruction (5 downto 3); -- Rm
                gp_addrB <= B"0000";
                imm8 <= (others => '0');
                execution_cmd <= MOVS;
                destination_is_PC <= false;
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,#<imm3>
            elsif (std_match(opcode, "010001") and instruction(9 downto 8) = "10") then         
                gp_WR_addr <= instruction(7) & instruction (2 downto 0);    -- Rd
                gp_addrA <= instruction (6 downto 3);                       -- Rn
                gp_addrB <= B"0000";
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
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,#<imm3>   
            elsif (std_match(opcode, "000111") and instruction(9) = '0') then                   
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (5 downto 3);             -- Rn 
                gp_addrB <= B"0000";
                imm8 <= B"00000" & instruction (8 downto 6);            -- imm3
                execution_cmd <= ADDS_imm3;
                destination_is_PC <= false;
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,<Rm>   
            elsif (std_match(opcode, "000110") and instruction(9) = '0') then                   
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (8 downto 6);             -- Rm
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rn
                execution_cmd <= ADDS;
                destination_is_PC <= false;
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- ADD <Rdn>,<Rm> - ADD PC,<Rm>   
            elsif (std_match(opcode, "010001") and instruction(9 downto 8) = B"00") then        
                gp_WR_addr <= instruction(7) & instruction (2 downto 0);    -- Rdn
                gp_addrA <= instruction(7) & instruction (2 downto 0);      -- Rdn
                gp_addrB <= instruction (6 downto 3);                       -- Rm 
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
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- ADDS <Rdn>,#<imm8>   
            elsif (std_match(opcode, "00110-")) then                                            
                gp_WR_addr <= '0' & instruction (10 downto 8);          -- Rdn
                gp_addrA <= '0' & instruction (10 downto 8);            -- Rdn
                gp_addrB <= B"0000";
                imm8 <= instruction (7 downto 0);                       -- imm8
                execution_cmd <= ADDS_imm8;
                destination_is_PC <= false;
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- ADCS <Rdn>,<Rm>   
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0101") then      
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdn
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rdn
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rm 
                execution_cmd <= ADCS;
                destination_is_PC <= false;
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- SUBS <Rd>,<Rn>,<Rm>   
            elsif (std_match(opcode, "000110") and instruction(9) = '1') then                   
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (8 downto 6);             -- Rm
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rn
                execution_cmd <= SUBS;
                destination_is_PC <= false;    
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- SUBS <Rd>,<Rn>,#<imm3>   
            elsif (std_match(opcode, "000111") and instruction(9) = '1') then                   
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (5 downto 3);             -- Rn 
                gp_addrB <= B"0000";
                imm8 <= B"00000" & instruction (8 downto 6);            -- imm3
                execution_cmd <= SUBS_imm3;
                destination_is_PC <= false;  
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- SUBS <Rdn>,#<imm8> 
            elsif (std_match(opcode, "00111-")) then                                              
                gp_WR_addr <= '0' & instruction (10 downto 8);          -- Rdn
                gp_addrA <= '0' & instruction (10 downto 8);            -- Rdn
                gp_addrB <= B"0000";
                imm8 <= instruction (7 downto 0);                       -- imm8
                execution_cmd <= SUBS_imm8;
                destination_is_PC <= false;  
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- SBCS <Rdn>,<Rm>   
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0110") then        
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdn
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rdn
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rm 
                execution_cmd <= SBCS;
                destination_is_PC <= false;
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- RSBS <Rd>,<Rn>,#0   
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1001") then        
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (5 downto 3);             -- Rn
                gp_addrB <= B"0000";
                execution_cmd <= RSBS;
                destination_is_PC <= false;   
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- MULS <Rdm>,<Rn>,<Rdm>    
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1101") then        
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdm
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rdm
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rn
                execution_cmd <= MULS;
                destination_is_PC <= false;  
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- CMP <Rn>,<Rm>   T1  
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1010") then        
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rn
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rm
                execution_cmd <= CMP;
                destination_is_PC <= false;    
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- CMP <Rn>,<Rm>   T2  
            elsif (std_match(opcode, "010001") and instruction(9 downto 8) = B"01") then        
                gp_addrA <= instruction(7) & instruction (2 downto 0);  -- Rn
                gp_addrB <= instruction (6 downto 3);                   -- Rm
                execution_cmd <= CMP;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- CMN <Rn>,<Rm>     
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1011") then        
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rn
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rm
                execution_cmd <= CMN;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- CMP <Rn>,#<imm8>     
            elsif (std_match(opcode, "00101-")) then        
                gp_addrA <= '0' & instruction (10 downto 8);             -- Rn
                gp_addrB <= B"0000";
                imm8 <= instruction (7 downto 0);                        -- imm8
                execution_cmd <= CMP_imm8;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- ANDS <Rdn>,<Rm>    
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0000") then       
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                gp_addrA <= '0' & instruction (2 downto 0);              -- Rn
                gp_addrB <= '0' & instruction (5 downto 3);              -- Rm
                execution_cmd <= ANDS;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- EORS <Rdn>,<Rm>  
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0001") then       
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                gp_addrA <= '0' & instruction (2 downto 0);              -- Rn
                gp_addrB <= '0' & instruction (5 downto 3);              -- Rm
                execution_cmd <= EORS;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- ORRS <Rdn>,<Rm>  
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1100") then       
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                gp_addrA <= '0' & instruction (2 downto 0);              -- Rn
                gp_addrB <= '0' & instruction (5 downto 3);              -- Rm
                execution_cmd <= ORRS;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- BICS <Rdn>,<Rm>  
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1110") then       
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                gp_addrA <= '0' & instruction (2 downto 0);              -- Rn
                gp_addrB <= '0' & instruction (5 downto 3);              -- Rm
                execution_cmd <= BICS;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- MVNS <Rd>,<Rm>  
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1111") then       
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                gp_addrA <= '0' & instruction (5 downto 3);              -- Rm
                gp_addrB <= B"0000";
                execution_cmd <= MVNS;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- TST <Rn>,<Rm>  
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1000") then       
                gp_addrA <= '0' & instruction (2 downto 0);              -- Rn
                gp_addrB <= '0' & instruction (5 downto 3);              -- Rm
                execution_cmd <= TST;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- LSLS <Rd>,<Rm>,#<imm5>
            elsif (std_match(opcode, "00000-")) then  
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (5 downto 3);             -- Rm
                gp_addrB <= B"0000";
                imm8 <= B"000" & instruction (10 downto 6);            -- imm5
                execution_cmd <= LSLS_imm5;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- LSLS <Rdn>,<Rm>
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0010") then  
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdn
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rdn
                gp_addrB <=  '0' & instruction (5 downto 3);            -- Rm
                execution_cmd <= LSLS;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- LSRS <Rd>,<Rm>,#<imm5>
            elsif (std_match(opcode, "00001-")) then  
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (5 downto 3);             -- Rm
                gp_addrB <= B"0000";
                imm8 <= B"000" & instruction (10 downto 6);            -- imm5
                execution_cmd <= LSRS_imm5;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- LSRS <Rdn>,<Rm>
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0011") then  
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdn
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rdn
                gp_addrB <=  '0' & instruction (5 downto 3);            -- Rm
                execution_cmd <= LSRS;
                destination_is_PC <= false;       
                access_mem <= false;  
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
         ----------------------------------------------------------------------------------- -- ASRS <Rd>,<Rm>,#<imm5>
            elsif (std_match(opcode, "00010-")) then  
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (5 downto 3);             -- Rm
                gp_addrB <= B"0000";
                imm8 <= B"000" & instruction (10 downto 6);            -- imm5
                execution_cmd <= ASRS_imm5;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
        ----------------------------------------------------------------------------------- -- ASRS <Rdn>,<Rm>
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0100") then  
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdn
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rdn
                gp_addrB <=  '0' & instruction (5 downto 3);            -- Rm
                execution_cmd <= ASRS;
                destination_is_PC <= false;       
                access_mem <= false;      
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
        ----------------------------------------------------------------------------------- -- RORS <Rdn>,<Rm>
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0111") then       
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rd 
                gp_addrA <= '0' & instruction (2 downto 0);              -- Rn
                gp_addrB <= '0' & instruction (5 downto 3);              -- Rm
                execution_cmd <= RORS;
                destination_is_PC <= false;       
                access_mem <= false;    
                use_base_register <= false;   
                mem_load_size <= NOT_DEF;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- LDR <Rt>, [<Rn>{,#<imm5>}]
            elsif (std_match(opcode, "01101-") ) then       
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt
                gp_addrA <=  '0' & instruction (5 downto 3);             -- Rn
                gp_addrB <= B"0000";
                imm8 <= B"000" & instruction (10 downto 6);              -- imm5
                execution_cmd <= LDR_imm5;
                destination_is_PC <= false;    
                access_mem <= true;    
                use_base_register <= true;   
                mem_load_size <= WORD;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- LDRH <Rt>,[<Rn>{,#<imm5>}]
            elsif (std_match(opcode, "10001-") ) then      
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt    
                gp_addrA <=  '0' & instruction (5 downto 3);             -- Rn
                gp_addrB <= B"0000";
                imm8 <= B"000" & instruction (10 downto 6);              -- imm5
                execution_cmd <= LDRH_imm5;
                destination_is_PC <= false;    
                access_mem <= true;    
                use_base_register <= true;   
                mem_load_size <= HALF_WORD;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- LDRB <Rt>,[<Rn>{,#<imm5>}]
            elsif (std_match(opcode, "01111-")) then  
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt     
                gp_addrA <=  '0' & instruction (5 downto 3);             -- Rn
                gp_addrB <= B"0000";
                imm8 <= B"000" & instruction (10 downto 6);              -- imm5
                execution_cmd <= LDRB_imm5;
                destination_is_PC <= false;    
                access_mem <= true;    
                use_base_register <= true;   
                mem_load_size <= BYTE;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- LDR <Rt>,<label>
            elsif (std_match(opcode, "01001-") ) then       
                gp_WR_addr <= '0' & instruction (10 downto 8);           -- Rt
                gp_addrA <= B"0000";
                gp_addrB <= B"0000";
                imm8 <= instruction (7 downto 0);                        -- imm8 <label>
                execution_cmd <= LDR_label;
                destination_is_PC <= false;   
                access_mem <= true;    
                use_base_register <= false;   
                mem_load_size <= WORD;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
          ----------------------------------------------------------------------------------- -- LDRH <Rt>,[<Rn>,<Rm>]
            elsif (std_match(opcode, "010110") and instruction(9) = '1') then       
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt
                gp_addrA <= '0' & instruction (5 downto 3);              -- Rn
                gp_addrB <= '0' & instruction (8 downto 6);              -- Rm
                execution_cmd <= LDRH;
                destination_is_PC <= false;   
                access_mem <= true;    
                use_base_register <= true;   
                mem_load_size <= HALF_WORD;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- LDRSH <Rt>,[<Rn>,<Rm>]
            elsif (std_match(opcode, "010111") and instruction(9) = '1') then       
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt
                gp_addrA <= '0' & instruction (5 downto 3);              -- Rn
                gp_addrB <= '0' & instruction (8 downto 6);              -- Rm
                   execution_cmd <= LDRSH;
                destination_is_PC <= false;   
                access_mem <= true;    
                use_base_register <= true;   
                mem_load_size <= HALF_WORD;
                mem_load_sign_ext <= true;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- LDRB <Rt>,[<Rn>,<Rm>]
            elsif (std_match(opcode, "010111") and instruction(9) = '0')  then       
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt
                gp_addrA <= '0' & instruction (5 downto 3);              -- Rn
                gp_addrB <= '0' & instruction (8 downto 6);              -- Rm
                execution_cmd <= LDRB;
                destination_is_PC <= false;   
                access_mem <= true;    
                use_base_register <= true;   
                mem_load_size <= BYTE;
                mem_load_sign_ext <= false;
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- LDRSB <Rt>,[<Rn>,<Rm>]
            elsif (std_match(opcode, "010101") and instruction(9) = '1')  then       
                gp_WR_addr <= '0' & instruction (2 downto 0);            -- Rt
                gp_addrA <= '0' & instruction (5 downto 3);              -- Rn
                gp_addrB <= '0' & instruction (8 downto 6);              -- Rm
                execution_cmd <= LDRSB;
                destination_is_PC <= false;   
                access_mem <= true;    
                use_base_register <= true;   
                mem_load_size <= BYTE;
                mem_load_sign_ext <= true;  
                LDM_access_mem <= false; 
            ----------------------------------------------------------------------------------- -- LDM <Rn>!,<registers>
            elsif (std_match(opcode, "11001-"))  then       
                gp_WR_addr <= B"0000";
                gp_addrA <= '0' & instruction (10 downto 8);             -- Rn        
                gp_addrB <= B"0000";   
                imm8 <= instruction (7 downto 0);                        -- imm8 = <registers>
                execution_cmd <= LDM;
                destination_is_PC <= false;   
                access_mem <= true;    
                use_base_register <= true;   
                mem_load_size <= WORD;
                mem_load_sign_ext <= false;   
                LDM_access_mem <= true; 
            else
                null;    
            end if;   
    end process;


    -- base = Align(PC,4);
    -- address = if add then (base + imm32) else (base - imm32);
    -- R[t] = MemU[address,4];
   
    
    -- offset_addr = if add then (R[n] + imm32) else (R[n] - imm32);
    -- address = if index then offset_addr else R[n];
    -- R[t] = MemU[address,4]; 

end Behavioral;
