----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/28/2020 03:06:58 PM
-- Design Name: 
-- Module Name: executor - Behavioral
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

entity executor is
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
         current_flags : in flag_t;
         cmd_out: out executor_cmds_t;
         set_flags : out boolean;
         PC_updated: out std_logic;
         result : out std_logic_vector(31 downto 0);
         alu_temp_32 : out std_logic;
         overflow_status : out std_logic_vector(2 downto 0);
         WE: out std_logic                                          -- Controls the WE pin of register bank. Used to flush the pipeline
     );
end executor;

architecture Behavioral of executor is

    component mul_32x32_r32 is
        Port ( 
            operand_A : in std_logic_vector(31 downto 0);	
            operand_B : in std_logic_vector(31 downto 0);	
            result : out std_logic_vector(31 downto 0)
        );
    end component;
        
    -- signals 
    signal mux_ctrl     :  std_logic_vector (1 downto 0);
    signal alu_result :  std_logic_vector (31 downto 0);
    signal alu_temp : unsigned (32 downto 0) := (others => '0');
    signal temp_overflow : std_logic_vector (2 downto 0);
    signal result_final :  std_logic_vector (31 downto 0);
    signal WE_val : std_logic;
    signal pipeline_is_invalid : std_logic;
    signal update_PC : std_logic;
    signal current_instruction_mem_location :  std_logic_vector (31 downto 0);
    signal mul_result:  std_logic_vector (31 downto 0);
 
begin

    executor_mul: mul_32x32_r32  port map ( 
            operand_A => operand_A,
            operand_B =>  operand_B,
            result => mul_result
        );
        
    PC_updated <= destination_is_PC;
        
    gp_data_in_p: process  (run, imm8_z_ext, mux_ctrl, operand_A, operand_B, alu_result) begin
        if (run = '1') then 
            case mux_ctrl is
                when B"00" =>   result_final <= imm8_z_ext;
                when B"10" =>   result_final <= operand_A;
                when B"01" =>   result_final <= operand_B;
                when B"11" =>   result_final <= alu_result;
                when others =>  result_final <= (others => '0');
            end case;
        else 
            result_final <= (others => '0');
        end if;    
    end process;
    
    cmd_out <= command;
    
    -- This process  flushes the pipeline if PC gets updated.
    WE_p: process  (WE_val, state) begin
        if (state = s_PC_UPDATED_INVALID or 
            state = s_EXEC_INSTA_INVALID or 
            state = s_EXEC_INSTB_INVALID or 
            state = s_PC_UNALIGNED) then
            WE <= '0';
        else
            WE <= WE_val;
        end if;    
    end process;
    
    execution_p: process  (command, destination_is_PC, operand_A(31), operand_B(31),  alu_result(31), imm8_z_ext(31)) begin
        case (command) is
            ------------------------------------------------------------ -- MOVS Rd, #(imm8)
            when MOVS_imm8 =>                                      
                WE_val <= '1'; 
                mux_ctrl <= B"00";          -- immediate value  
                update_PC <= '0';
                set_flags <= true;
            ------------------------------------------------------------ -- MOVS <Rd>,<Rm>    
            when MOVS =>                    
                WE_val <= '1'; 
                mux_ctrl <= B"10";          -- A bus of register bank
                update_PC <= '0';
                set_flags <= true;
            ------------------------------------------------------------ -- MOV <Rd>,<Rm> | MOV PC, Rm       
            when MOV =>                                                 
                WE_val <= '1'; 
                mux_ctrl <= B"10";          -- A bus of register bank
                -- if destination_is_PC = 1 it means d == 15 (destination is PC) then set_flags is always FALSE
                if (destination_is_PC = '1') then set_flags <= false; else set_flags <= true; end if;
                if (destination_is_PC = '1') then update_PC <= '1'; else update_PC <= '0'; end if;
            ------------------------------------------------------------ -- ADDS <Rd>,<Rn>,#<imm3>      
            when ADDS_imm3 =>                                        
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= operand_A(31) & imm8_z_ext(31) & alu_result(31);
                update_PC <= '0';
            ------------------------------------------------------------ -- ADDS <Rd>,<Rn>,<Rm>       
            when ADDS =>                                            
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= operand_A(31) & operand_B(31) & alu_result(31);
                update_PC <= '0';
            ------------------------------------------------------------ --  ADD <Rdn>,<Rm>    
            when ADD =>                                             
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= false;
                overflow_status <= operand_A(31) & operand_B(31) & alu_result(31);
                update_PC <= '0';
            ------------------------------------------------------------ --  ADD PC,<Rm>
            when ADD_PC =>    
                WE_val <= '0'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= false;
                update_PC <= '1';
            ------------------------------------------------------------ -- ADDS <Rdn>,#<imm8>    
            when ADDS_imm8 =>     
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= operand_A(31) & imm8_z_ext(31) & alu_result(31);
                update_PC <= '0';
            ------------------------------------------------------------ -- ADCS <Rdn>,<Rm>  
            when ADCS =>                                            
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= operand_A(31) & operand_B(31) & alu_result(31);
                update_PC <= '0';
            ------------------------------------------------------------ -- SUBS <Rd>,<Rn>,<Rm>
            when SUBS =>                                            
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= operand_A(31) & operand_B(31) & alu_result(31);
                update_PC <= '0';
            ------------------------------------------------------------ -- SUBS <Rd>,<Rn>,#<imm3>  
            when SUBS_imm3 =>                                       
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= operand_A(31) & imm8_z_ext(31) & alu_result(31);
                update_PC <= '0';   
            ------------------------------------------------------------ -- SUBS <Rdn>,#<imm8>
            when SUBS_imm8 =>                                      
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= operand_A(31) & imm8_z_ext(31) & alu_result(31);
                update_PC <= '0'; 
            ------------------------------------------------------------ -- SBCS <Rdn>,<Rm>    
            when SBCS =>                                            
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= operand_A(31) & operand_B(31) & alu_result(31);
                update_PC <= '0';
            ------------------------------------------------------------ -- RSBS <Rd>,<Rn>,#0 
            when RSBS =>                                               
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= operand_A(31) & imm8_z_ext(31) & alu_result(31);
                update_PC <= '0';    
            ------------------------------------------------------------ -- MULS <Rdm>,<Rn>,<Rdm>     
            when MULS =>                                               
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                update_PC <= '0'; 
            ------------------------------------------------------------ -- CMP <Rn>,<Rm>       
            when CMP =>                                               
                WE_val <= '0';              -- Do not write back the result
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                update_PC <= '0'; 
            ------------------------------------------------------------ -- All unefined instructions        
            when others  => 
                WE_val <= '0'; 
                mux_ctrl <= B"00";
                set_flags <= false;
                overflow_status <= (others => '0');
                update_PC <= '0';
       end case;  
     end process;
     
    alu_p: process  (command, state, operand_A, operand_B, current_instruction_mem_location, imm8_z_ext, mul_result, current_flags) begin
        case (command) is
            -------------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,#<imm3>
            when ADDS_imm3 =>  
                -- AddWithCarry(R[n], imm32, '0');     
                alu_temp <= unsigned ("0" & operand_A) + unsigned("0" & imm8_z_ext);                    
            -------------------------------------------------------------------------------------- -- ADDS <Rd>,<Rn>,<Rm>   
            when ADDS =>   
                -- AddWithCarry(R[n], shifted, '0');     
                alu_temp <= unsigned ("0" & operand_A) + unsigned("0" & operand_B);                     
            -------------------------------------------------------------------------------------- -- ADD <Rdn>,<Rm>  
            when ADD =>       
                -- AAddWithCarry(R[n], shifted, '0');      
                alu_temp <= unsigned ("0" & operand_A) + unsigned("0" & operand_B);                     
            -------------------------------------------------------------------------------------- -- ADD PC, <Rm> 
            when ADD_PC =>          
                -- AAddWithCarry(R[n], shifted, '0');
                alu_temp <= (unsigned ("0" & current_instruction_mem_location) +                        
                              unsigned("0" & operand_B) + 2)
                              and B"1_1111_1111_1111_1111_1111_1111_1111_1110"; 
            -------------------------------------------------------------------------------------- -- ADDS <Rdn>,#<imm8>                                                    
            when ADDS_imm8 =>   
                -- AddWithCarry(R[n], imm32, '0');      
                alu_temp <= unsigned ("0" & operand_A) + unsigned("0" & imm8_z_ext);                    
            -------------------------------------------------------------------------------------- -- ADCS <Rdn>,<Rm>                
            when ADCS =>      
                -- AddWithCarry(R[n], shifted, APSR.C);      
                alu_temp <= ((unsigned ("0" & operand_A) + unsigned("0" & operand_B)) + to_std_logic(current_flags.C)) ;         
            -------------------------------------------------------------------------------------- -- SUBS <Rd>,<Rn>,#<imm3>
            when SUBS_imm3 =>       
                -- AddWithCarry(R[n], NOT(imm32), '1');
                alu_temp <= unsigned ("0" & operand_A) + unsigned(not ("0" & imm8_z_ext)) + 1;          
            -------------------------------------------------------------------------------------- -- SUBS <Rd>,<Rn>,<Rm>
            when SUBS =>      
                -- AddWithCarry(R[n], NOT(shifted), '1');      
                alu_temp <= unsigned ("0" & operand_A) + unsigned(not ("0" & operand_B)) + 1;            
            -------------------------------------------------------------------------------------- -- SUBS <Rdn>,#<imm8>
            when SUBS_imm8 =>   
                -- AddWithCarry(R[n], NOT(imm32), '1');    
                alu_temp <= unsigned ("0" & operand_A) + unsigned(not("0" & imm8_z_ext)) + 1;              
            -------------------------------------------------------------------------------------- -- SBCS <Rdn>,<Rm>
            when SBCS =>    
                -- AddWithCarry(R[n], NOT(shifted), APSR.C);         
                alu_temp <=                                                                                    
                    ((unsigned ("0" & operand_A) + unsigned(not("0" & operand_B))) + not (to_std_logic(current_flags.C))) ;       
            -------------------------------------------------------------------------------------- -- RSBS <Rd>,<Rn>,#0
            when RSBS =>      
                -- AddWithCarry(NOT(R[n]), imm32, '1');        
                alu_temp <= unsigned (not('0' & operand_A)) + 1;                                                                     
            -------------------------------------------------------------------------------------- -- MULS <Rdm>,<Rn>,<Rdm>
            when MULS =>      
                -- result = operand1 * operand2;        
                alu_temp <= unsigned("0" & mul_result);                                                 
            -------------------------------------------------------------------------------------- -- CMP <Rn>,<Rm>
            when CMP =>             
                 -- subtract operand A from B but discard the result
                 -- AddWithCarry(R[n], NOT(shifted), '1');
                 alu_temp <= unsigned ("0" & operand_A) + unsigned(not("0" & operand_B)) + 1;                                       
            -------------------------------------------------------------------------------------- -- others indefined instructions
            when others  =>
                alu_temp <= (others => '0');
        end case;       
     end process;

     alu_result <= std_logic_vector(alu_temp(31 downto 0));
     result <= result_final;
     
    -- If core is at state s_EXEC_INSTA then the current memory address of the currect instruction is PC.
    --  but if the core is at state s_EXEC_INSTB then current memory address of the currect instruction is PC - 2
    -- The to PC instrution adds to current memory location which must be calculates based on the observations stated above.
    current_instruction_mem_location_p: process (state, operand_A) begin
        if (state = s_EXEC_INSTA) then
            current_instruction_mem_location <= operand_A;    -- OperanA will carry the PC if update_PC signal is activated
        else
            current_instruction_mem_location <= STD_LOGIC_VECTOR (unsigned (operand_A) + 2);
        end if;
    end process;
    
    
 


end Behavioral;
