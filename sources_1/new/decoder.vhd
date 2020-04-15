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
        run : in std_logic; 
        instruction : in STD_LOGIC_VECTOR (15 downto 0);
        destination_is_PC : out std_logic;
        thumb : out std_logic;                               -- indicates wether the decoded instruction is 16-bit thumb = 0 or 32-bit = 1
        gp_WR_addr : out STD_LOGIC_VECTOR (3 downto 0);
        gp_addrA: out STD_LOGIC_VECTOR (3 downto 0);
        gp_addrB: out STD_LOGIC_VECTOR (3 downto 0);
        imm8: out STD_LOGIC_VECTOR (7 downto 0);
        execution_cmd: out executor_cmds_t
        --execution_cmd: out STD_LOGIC_VECTOR (4 downto 0)
    );
end decoder;

architecture Behavioral of decoder is
    signal is_shift_class_instruction: std_logic;               -- 0 : is not shift class, 1: is shift class. 
   -- signal inst_under_decode: STD_LOGIC_VECTOR (15 downto 0);
    alias opcode: STD_LOGIC_VECTOR (5 downto 0) is instruction (15 downto 10);               -- bits (15 downto 10)
  
  -- aliases
    -- [      inst A 1st half    ] [     inst A 2nd half     ] [    inst B 1st half    ]   [ inst B 2nd half ] 
    -- [31 30 29 28 - 27 26 25 24] [23 22 21 20 - 19 18 17 16] [15 14 13 12 - 11 10 9 8] - [7 6 5 4 - 3 2 1 0]
    --alias inst_1st_half : STD_LOGIC_VECTOR(7 downto 0) is instruction (15 downto 8);
   -- alias inst_2nd_half : STD_LOGIC_VECTOR(7 downto 0) is instruction (7 downto 0);
        
begin
    
    inst_under_decode_p: process(instruction) begin
       -- inst_under_decode <= inst_2nd_half & inst_1st_half;
        case instruction(15 downto 11) is
            when B"11101" =>   thumb <= '1';
            when B"11110" =>   thumb <= '1';
            when B"11111" =>   thumb <= '1';
            when others => thumb <= '0';
        end case;
    end process;
    
--    decode_op_p: process (opcode) begin
--        if std_match(opcode, "00----") then -- Shift (immediate), add, subtract, move, and compare
--           is_shift_class_instruction <= '1'; report "Instruction 00xxxx detected. (Shift Class) opcode = " & conv_to_string(opcode) severity note;
--        else   
--            is_shift_class_instruction <= '0'; report "Instruction is not implemented: opcode = " & conv_to_string(opcode) severity warning;
--        end if;   
--    end process;
    
    decode_shift_op_p: process (run, instruction) begin
        if (run = '1') then 
            ----------------------------------------------------------------------------------- -- MOVS Rd, #<imm8>
            if std_match(opcode, "00100-") then                                                 
               gp_WR_addr <= '0' & instruction (10 downto 8); -- Rd 
               gp_addrA <= B"0000";
               gp_addrB <= B"0000";
               imm8 <= instruction (7 downto 0);
               execution_cmd <= MOVS_imm8;
               destination_is_PC <= '0';
            ----------------------------------------------------------------------------------- -- MOVS <Rd>,<Rm> 
            elsif (std_match(opcode, "000000") and instruction(9 downto 6) = "0000") then         
                gp_WR_addr <= '0' & instruction (2 downto 0); -- Rd 
                gp_addrA <= '0' & instruction (5 downto 3); -- Rm
                gp_addrB <= B"0000";
                imm8 <= (others => '0');
                execution_cmd <= MOVS;
                destination_is_PC <= '0';
            ----------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,#<imm3>
            elsif (std_match(opcode, "010001") and instruction(9 downto 8) = "10") then         
                gp_WR_addr <= instruction(7) & instruction (2 downto 0);    -- Rd
                gp_addrA <= instruction (6 downto 3);                       -- Rn
                gp_addrB <= B"0000";
                imm8 <= (others => '0');
                execution_cmd <= MOV;
                if ((instruction(7) & instruction (2 downto 0)) = B"1111" ) then    -- check if destination is PC ?
                    destination_is_PC <= '1';
                else
                    destination_is_PC <= '0';
                end if;
            ----------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,#<imm3>   
            elsif (std_match(opcode, "000111") and instruction(9) = '0') then                   
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (5 downto 3);             -- Rn 
                gp_addrB <= B"0000";
                imm8 <= B"00000" & instruction (8 downto 6);            -- imm3
                execution_cmd <= ADDS_imm3;
                destination_is_PC <= '0';
            ----------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,<Rm>   
            elsif (std_match(opcode, "000110") and instruction(9) = '0') then                   
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (8 downto 6);             -- Rm
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rn
                execution_cmd <= ADDS;
                destination_is_PC <= '0';
            ----------------------------------------------------------------------------------- -- ADD <Rdn>,<Rm> - ADD PC,<Rm>   
            elsif (std_match(opcode, "010001") and instruction(9 downto 8) = B"00") then        
                gp_WR_addr <= instruction(7) & instruction (2 downto 0);    -- Rdn
                gp_addrA <= instruction(7) & instruction (2 downto 0);      -- Rdn
                gp_addrB <= instruction (6 downto 3);                       -- Rm 
                if ((instruction(7) & instruction (2 downto 0)) = B"1111" ) then    -- check if destination is PC ?
                    execution_cmd <= ADD_PC;
                    destination_is_PC <= '1';
                else
                    execution_cmd <= ADD;
                    destination_is_PC <= '0';
                end if;
            ----------------------------------------------------------------------------------- -- ADDS <Rdn>,#<imm8>   
            elsif (std_match(opcode, "00110-")) then                                            
                gp_WR_addr <= '0' & instruction (10 downto 8);          -- Rdn
                gp_addrA <= '0' & instruction (10 downto 8);            -- Rdn
                imm8 <= instruction (7 downto 0);                       -- imm8
                execution_cmd <= ADDS_imm8;
                destination_is_PC <= '0';
            ----------------------------------------------------------------------------------- -- ADCS <Rdn>,<Rm>   
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0101") then      
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdn
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rdn
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rm 
                execution_cmd <= ADCS;
                destination_is_PC <= '0';
            ----------------------------------------------------------------------------------- -- SUBS <Rd>,<Rn>,<Rm>   
            elsif (std_match(opcode, "000110") and instruction(9) = '1') then                   
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (8 downto 6);             -- Rm
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rn
                execution_cmd <= SUBS;
                destination_is_PC <= '0';    
            ----------------------------------------------------------------------------------- -- SUBS <Rd>,<Rn>,#<imm3>   
            elsif (std_match(opcode, "000111") and instruction(9) = '1') then                   
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (5 downto 3);             -- Rn 
                gp_addrB <= B"0000";
                imm8 <= B"00000" & instruction (8 downto 6);            -- imm3
                execution_cmd <= SUBS_imm3;
                destination_is_PC <= '0';  
            ----------------------------------------------------------------------------------- -- SUBS <Rdn>,#<imm8> 
            elsif (std_match(opcode, "00111-")) then                                              
                gp_WR_addr <= '0' & instruction (10 downto 8);          -- Rdn
                gp_addrA <= '0' & instruction (10 downto 8);            -- Rdn
                imm8 <= instruction (7 downto 0);                       -- imm8
                execution_cmd <= SUBS_imm8;
                destination_is_PC <= '0';  
            ----------------------------------------------------------------------------------- -- SBCS <Rdn>,<Rm>   
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"0110") then        
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdn
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rdn
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rm 
                execution_cmd <= SBCS;
                destination_is_PC <= '0';
            ----------------------------------------------------------------------------------- -- RSBS <Rd>,<Rn>,#0   
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1001") then        
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rd
                gp_addrA <= '0' & instruction (5 downto 3);             -- Rn
                execution_cmd <= RSBS;
                destination_is_PC <= '0';   
            ----------------------------------------------------------------------------------- -- MULS <Rdm>,<Rn>,<Rdm>    
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1101") then        
                gp_WR_addr <= '0' & instruction (2 downto 0);           -- Rdm
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rdm
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rn
                execution_cmd <= MULS;
                destination_is_PC <= '0';  
            ----------------------------------------------------------------------------------- -- CMP <Rn>,<Rm>   T1  
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1010") then        
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rn
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rm
                execution_cmd <= CMP;
                destination_is_PC <= '0';    
            ----------------------------------------------------------------------------------- -- CMP <Rn>,<Rm>   T2  
            elsif (std_match(opcode, "010001") and instruction(9 downto 8) = B"01") then        
                gp_addrA <= instruction(7) & instruction (2 downto 0);  -- Rn
                gp_addrB <= instruction (6 downto 3);                   -- Rm
                execution_cmd <= CMP;
                destination_is_PC <= '0';       
            ----------------------------------------------------------------------------------- -- CMN <Rn>,<Rm>     
            elsif (std_match(opcode, "010000") and instruction(9 downto 6) = B"1011") then        
                gp_addrA <= '0' & instruction (2 downto 0);             -- Rn
                gp_addrB <= '0' & instruction (5 downto 3);             -- Rm
                execution_cmd <= CMN;
                destination_is_PC <= '0';       
            -----------------------------------------------------------------------------------    
            else   
               gp_WR_addr <= (others => '0');
               gp_addrA <= (others => '0');
               gp_addrB <= (others => '0');
               imm8 <= (others => '0');
              execution_cmd <= NOT_DEF;
               destination_is_PC <= '0';
            end if;   
        else 
            gp_WR_addr <= (others => '0');
            gp_addrA <= (others => '0');
            gp_addrB <= (others => '0');
            imm8 <= (others => '0');
            execution_cmd <= NOT_DEF;
            destination_is_PC <= '0';
        end if;    
end process;

end Behavioral;
