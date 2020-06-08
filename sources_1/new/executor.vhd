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
    signal mem_access: boolean;
 
begin

    executor_mul: mul_32x32_r32  port map ( 
            operand_A => operand_A,
            operand_B =>  operand_B,
            result => mul_result
        );
        
    gp_data_in_p: process  (imm8_z_ext, mux_ctrl, operand_A, operand_B, alu_result) begin
        case mux_ctrl is
            when B"00" =>   result_final <= imm8_z_ext;
            when B"10" =>   result_final <= operand_A;
            when B"01" =>   result_final <= operand_B;
            when B"11" =>   result_final <= alu_result;
            when others =>  result_final <= (others => '0');
        end case;
    end process;
    
    cmd_out <= command;
    
    alu_temp_32 <= alu_temp(32);
    
    -- This process  flushes the pipeline if PC gets updated.
    WE_p: process  (WE_val, gp_data_in_ctrl, access_mem, disable_executor) begin
        if (gp_data_in_ctrl = sel_HRDATA_VALUE_SIZED or 
            gp_data_in_ctrl = sel_LDM_DATA or 
            gp_data_in_ctrl = sel_LDM_Rn or 
            gp_data_in_ctrl = sel_STM_total_bytes_wrote) then
            WE <= '1';
        elsif (access_mem = true or disable_executor = true) then
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
                overflow_status <= (others => '0');
                mem_access <= false;
            ------------------------------------------------------------ -- MOVS <Rd>,<Rm>    
            when MOVS =>                    
                WE_val <= '1'; 
                mux_ctrl <= B"10";          -- A bus of register bank
                update_PC <= '0';
                set_flags <= true;
                overflow_status <= (others => '0');
                mem_access <= false;
            ------------------------------------------------------------ -- MOV <Rd>,<Rm> | MOV PC, Rm       
            when MOV =>                                                 
                WE_val <= '1'; 
                mux_ctrl <= B"10";          -- A bus of register bank
                -- if destination_is_PC = 1 it means d == 15 (destination is PC) then set_flags is always FALSE
                if (destination_is_PC = true) then set_flags <= false; else set_flags <= true; end if;
                overflow_status <= (others => '0');
                if (destination_is_PC = true) then update_PC <= '1'; else update_PC <= '0'; end if;
                mem_access <= false;
            ------------------------------------------------------------ -- ADDS <Rd>,<Rn>,#<imm3>      
            ------------------------------------------------------------ -- ADDS <Rdn>,#<imm8>    
            ------------------------------------------------------------ -- SUBS <Rd>,<Rn>,#<imm3>  
            ------------------------------------------------------------ -- SUBS <Rdn>,#<imm8>
            ------------------------------------------------------------ -- RSBS <Rd>,<Rn>,#0 
            when ADDS_imm3 | ADDS_imm8 | SUBS_imm3 | SUBS_imm8 | RSBS =>                                        
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= operand_A(31) & imm8_z_ext(31) & alu_result(31);
                update_PC <= '0';
                mem_access <= false;
            ------------------------------------------------------------ -- ADDS <Rd>,<Rn>,<Rm>       
            ------------------------------------------------------------ -- ADD <Rdn>,<Rm>   
            ------------------------------------------------------------ -- ADCS <Rdn>,<Rm> 
            ------------------------------------------------------------ -- SUBS <Rd>,<Rn>,<Rm>
            ------------------------------------------------------------ -- SBCS <Rdn>,<Rm>    
            when ADDS | ADD | ADCS | SUBS | SBCS => 
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= operand_A(31) & operand_B(31) & alu_result(31);
                update_PC <= '0';
                mem_access <= false;   
            ------------------------------------------------------------ --  ADD PC,<Rm>
            when ADD_PC =>    
                WE_val <= '0'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= false;
                overflow_status <= (others => '0');
                update_PC <= '1';
                mem_access <= false;
            ------------------------------------------------------------ -- MULS <Rdm>,<Rn>,<Rdm>     
            ------------------------------------------------------------ -- ANDS <Rdn>,<Rm>     
            ------------------------------------------------------------ -- EORS <Rdn>,<Rm>     
            ------------------------------------------------------------ -- ORRS <Rdn>,<Rm>     
            ------------------------------------------------------------ -- BICS <Rdn>,<Rm>     
            ------------------------------------------------------------ -- MVNS <Rd>,<Rm>     
            ------------------------------------------------------------ -- LSLS <Rd>,<Rm>,#<imm5> 
            ------------------------------------------------------------ -- LSLS <Rdn>,<Rm>
            ------------------------------------------------------------ -- LSRS <Rd>,<Rm>,#<imm5>
            ------------------------------------------------------------ -- LSRS <Rdn>,<Rm>
            ------------------------------------------------------------ -- ASRS <Rd>,<Rm>,#<imm5>
            ------------------------------------------------------------ -- ASRS <Rdn>,<Rm>
            ------------------------------------------------------------ -- RORS <Rdn>,<Rm>    
            when MULS | 
                 ANDS | EORS | ORRS | BICS | MVNS | 
                 LSLS_imm5 | LSLS | LSRS_imm5 | LSRS | ASRS_imm5| ASRS | RORS =>                                               
                WE_val <= '1'; 
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= (others => '0');
                update_PC <= '0'; 
                mem_access <= false;
            ------------------------------------------------------------ -- CMP <Rn>,<Rm>     T1, T2  
            ------------------------------------------------------------ -- CMN <Rn>,<Rm>    
            ------------------------------------------------------------ -- CMP <Rn>,#<imm8>     
            ------------------------------------------------------------ -- TST <Rn>,<Rm>     
            when CMP | CMN | CMP_imm8 | TST =>                                               
                WE_val <= '0';              -- Do not write back the result
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= true;
                overflow_status <= (others => '0');
                update_PC <= '0'; 
                mem_access <= false;
                
            ---------------------------------------------------------- --   LDR <Rt>, [<Rn>{,#<imm5>}]
            ---------------------------------------------------------- --   LDRH <Rt>,[<Rn>{,#<imm5>}]
            ---------------------------------------------------------- --   LDRB <Rt>,[<Rn>{,#<imm5>}]
            ---------------------------------------------------------- --   LDR <Rt>,[<Rn>,<Rm>]
            ---------------------------------------------------------- --   LDRH <Rt>,[<Rn>,<Rm>]
            ---------------------------------------------------------- --   LDRSH <Rt>,[<Rn>,<Rm>]
            ---------------------------------------------------------- --   LDRB <Rt>,[<Rn>,<Rm>]
            ---------------------------------------------------------- --   LDRSB <Rt>,[<Rn>,<Rm>]
            ---------------------------------------------------------- --   LDR <Rt>,<label>
            ---------------------------------------------------------- --   LDM <Rn>!,<registers>
            when LDR | LDR_imm5 | LDRH_imm5 | LDRB_imm5 | LDRH | LDRSH | LDRB | 
                  LDRSB | LDR_label | LDM  =>                                               
                WE_val <= '1';              
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= false;
                update_PC <= '0'; 
                mem_access <= true;
            
            ---------------------------------------------------------- --  STR <Rt>, [<Rn>{,#<imm5>}]
            ---------------------------------------------------------- --  STRH <Rt>,[<Rn>{,#<imm5>}]
            ---------------------------------------------------------- --  STRB <Rt>,[<Rn>{,#<imm5>}]
            ---------------------------------------------------------- --  STR <Rt>,[<Rn>,<Rm>]
            ---------------------------------------------------------- --  STRH <Rt>,[<Rn>,<Rm>]
            ---------------------------------------------------------- --  STRB <Rt>,[<Rn>,<Rm>]
            ---------------------------------------------------------- --  STR <Rt>,[SP,#<imm8>]
            ---------------------------------------------------------- --  STM <Rn>!,<registers>
            when STR_imm5 | STRH_imm5 | STRB_imm5 | STR | STRH | STRB | STR_SP_imm8 | STM  =>                                               
                WE_val <= '1';              
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= false;
                overflow_status <= (others => '0');
                update_PC <= '0'; 
                mem_access <= true;
            
            -------------------------------------------------------------------------------------- --  PUSH <registers>
            -------------------------------------------------------------------------------------- --  POP <registers>
            when PUSH | POP =>
                WE_val <= '0';              
                mux_ctrl <= B"11";          -- alu_result
                set_flags <= false;
                overflow_status <= (others => '0');
                update_PC <= '0'; 
                mem_access <= true;                     

            -------------------------------------------------------------------------------------- --  B <label>    T1
            -------------------------------------------------------------------------------------- --  B <label>    T2
            -------------------------------------------------------------------------------------- --  BX Rm 
            when BRANCH | BRANCH_imm11 | BX =>
                WE_val <= '0';              
                mux_ctrl <= B"00";          -- alu_result
                set_flags <= false;
                overflow_status <= (others => '0');
                update_PC <= '0'; 
                mem_access <= true;   
            -------------------------------------------------------------------------------------- --  BL <label>        
            when BL =>
                WE_val <= '1';              -- Write to LR register             
                mux_ctrl <= B"00";          -- alu_result
                set_flags <= false;
                overflow_status <= (others => '0');
                update_PC <= '0'; 
                mem_access <= true;             
                
                
            when NOP =>
                WE_val <= '0';              
                mux_ctrl <= B"00";          -- alu_result
                set_flags <= false;
                overflow_status <= (others => '0');
                update_PC <= '0'; 
                mem_access <= false;    
            ------------------------------------------------------------ -- All undefined instructions        
            when others  => 
                WE_val <= '0'; 
                mux_ctrl <= B"00";
                set_flags <= false;
                overflow_status <= (others => '0');
                update_PC <= '0';
                mem_access <= false;
       end case;  
     end process;
     
    alu_p: process  (command, operand_A, operand_B, imm8_z_ext, mul_result, current_flags) 
    begin
    
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
                alu_temp <= (unsigned ("0" & operand_A) +                        
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
            -------------------------------------------------------------------------------------- -- CMN <Rn>,<Rm>
            when CMN =>             
                 -- Add operand A with B but discard the result
                 -- AddWithCarry(R[n], shifted, '0');
                 alu_temp <= unsigned ("0" & operand_A) + unsigned("0" & operand_B);                                       
            -------------------------------------------------------------------------------------- -- CMP <Rn>,#<imm8>
            when CMP_imm8 =>             
                 -- Add operand A with imm8 but discard the result
                 -- AddWithCarry(R[n], shifted, '0');
                 alu_temp <= unsigned ("0" & operand_A) + unsigned(not("0" & imm8_z_ext)) + 1;                                       
            -------------------------------------------------------------------------------------- -- ANDS <Rdn>,<Rm>
            when ANDS =>             
                -- (shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C);
                -- result = R[n] AND shifted;
                -- carry out = carry in
                alu_temp(31 downto 0) <= unsigned (operand_A) and unsigned(operand_B); 
                alu_temp(32) <= to_std_logic(current_flags.C);                                    
            -------------------------------------------------------------------------------------- -- EORS <Rdn>,<Rm>
            when EORS =>             
                --(shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C);
                -- result = R[n] EOR shifted;
                -- carry out = carry in
                alu_temp(31 downto 0) <= unsigned (operand_A) xor unsigned(operand_B); 
                alu_temp(32) <= to_std_logic(current_flags.C);                                    
            -------------------------------------------------------------------------------------- -- ORRS <Rdn>,<Rm>
            when ORRS =>             
                -- (shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C);
                -- result = R[n] OR shifted;
                -- carry out = carry in
                alu_temp(31 downto 0) <= unsigned (operand_A) or unsigned(operand_B); 
                alu_temp(32) <= to_std_logic(current_flags.C);                                    
            -------------------------------------------------------------------------------------- -- BICS <Rdn>,<Rm>
            when BICS =>             
                -- (shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C);
                -- result = R[n] AND NOT(shifted);
                -- carry out = carry in
                alu_temp(31 downto 0) <= unsigned (operand_A) and unsigned(not (operand_B)); 
                alu_temp(32) <= to_std_logic(current_flags.C);                                    
            -------------------------------------------------------------------------------------- -- MVNS <Rd>,<Rm>
            when MVNS =>             
                -- (shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C);
                -- result = NOT(shifted);
                -- R[d] = result;
                -- carry out = carry in
                alu_temp(31 downto 0) <= unsigned (not (operand_A)); 
                alu_temp(32) <= to_std_logic(current_flags.C);                                    
            -------------------------------------------------------------------------------------- -- TST <Rn>,<Rm>
            when TST =>             
                -- (shifted, carry) = Shift_C(R[m], shift_t, shift_n, APSR.C);
                -- result = R[n] AND shifted;
                -- carry out = carry in
                alu_temp(31 downto 0) <= unsigned (operand_A) and unsigned(operand_B); 
                alu_temp(32) <= to_std_logic(current_flags.C);                               
            -------------------------------------------------------------------------------------- --  LSLS <Rd>,<Rm>,#<imm5>
            when LSLS_imm5 =>             
                -- (result, carry) = Shift_C(R[m], SRType_LSL, shift_n, APSR.C);
                -- R[d] = result;
                alu_temp (31 downto 0) <= shift_left (unsigned (operand_A),  to_integer (unsigned (imm8_z_ext (4 downto 0)))); 
                -- The C flag is unaffected if the shift value is 0. Otherwise, the C flag is updated to the last bit shifted out.
                if ( unsigned( imm8_z_ext (4 downto 0)) = B"00000") then 
                    -- C will not be changed
                else
                    alu_temp (32) <= alu_temp (31);                                    
                end if;    
            -------------------------------------------------------------------------------------- --  LSLS <Rdn>,<Rm>
            when LSLS =>             
                -- shift_n = UInt(R[m]<7:0>);
                -- (result, carry) = Shift_C(R[n], SRType_LSL, shift_n, APSR.C);
                -- R[d] = result;
                alu_temp (31 downto 0) <= shift_left (unsigned (operand_A),  to_integer (unsigned (operand_B (4 downto 0)))); 
                -- The C flag is unaffected if the shift value is 0. Otherwise, the C flag is updated to the last bit shifted out.
                if ( unsigned( operand_B (4 downto 0)) = B"00000") then 
                    -- C will not be changed
                else
                    alu_temp (32) <= alu_temp (31);                                    
                end if;    
            -------------------------------------------------------------------------------------- --  LSRS <Rd>,<Rm>,#<imm5>
            when LSRS_imm5 =>             
                -- (result, carry) = Shift_C(R[m], SRType_LSR, shift_n, APSR.C);
                -- R[d] = result;
                alu_temp (31 downto 0) <= shift_right (unsigned (operand_A),  to_integer (unsigned (imm8_z_ext (4 downto 0)))); 
                -- The C flag is unaffected if the shift value is 0. Otherwise, the C flag is updated to the last bit shifted out.
                if ( unsigned( imm8_z_ext (4 downto 0)) = B"00000") then 
                    -- C will not be changed
                else
                    alu_temp (32) <= alu_temp (31);                                    
                end if;    
            -------------------------------------------------------------------------------------- --  LSRS <Rdn>,<Rm>
            when LSRS =>             
                -- shift_n = UInt(R[m]<7:0>);
                -- (result, carry) = Shift_C(R[n], SRType_LSL, shift_n, APSR.C);
                -- R[d] = result;
                alu_temp (31 downto 0) <= shift_right (unsigned (operand_A),  to_integer (unsigned (operand_B (4 downto 0)))); 
                -- The C flag is unaffected if the shift value is 0. Otherwise, the C flag is updated to the last bit shifted out.
                if ( unsigned( operand_B (4 downto 0)) = B"00000") then 
                    -- C will not be changed
                else
                    alu_temp (32) <= alu_temp (31);                                    
                end if;  
             -------------------------------------------------------------------------------------- --  ASRS <Rd>,<Rm>,#<imm5>
            when ASRS_imm5 =>             
                -- (result, carry) = Shift_C(R[m], SRType_LSR, shift_n, APSR.C);
                -- R[d] = result;
                alu_temp (31 downto 0) <= unsigned ( 
                    shift_right (signed (operand_A),  to_integer (unsigned (imm8_z_ext (4 downto 0))))
                    ); 
                -- The C flag is unaffected if the shift value is 0. Otherwise, the C flag is updated to the last bit shifted out.
                if ( unsigned( imm8_z_ext (4 downto 0)) = B"00000") then 
                    -- C will not be changed
                else
                    alu_temp (32) <= alu_temp (31);                                    
                end if;    
            -------------------------------------------------------------------------------------- --  ASRS <Rdn>,<Rm>
            when ASRS =>             
                -- shift_n = UInt(R[m]<7:0>);
                -- (result, carry) = Shift_C(R[n], SRType_LSL, shift_n, APSR.C);
                -- R[d] = result;
                alu_temp (31 downto 0) <=  unsigned ( 
                    shift_right (signed (operand_A),  to_integer (unsigned (operand_B (4 downto 0))))
                    ); 
                -- The C flag is unaffected if the shift value is 0. Otherwise, the C flag is updated to the last bit shifted out.
                if ( unsigned( operand_B (4 downto 0)) = B"00000") then 
                    -- C will not be changed
                else
                    alu_temp (32) <= alu_temp (31);                                    
                end if;           
            -------------------------------------------------------------------------------------- --  RORS <Rdn>,<Rm>
            when RORS =>             
                -- shift_n = UInt(R[m]<7:0>);
                -- (result, carry) = Shift_C(R[n], SRType_ROR, shift_n, APSR.C);
                -- R[d] = result;
                alu_temp (31 downto 0) <= shift_right (unsigned (operand_A),  to_integer (unsigned (operand_B (4 downto 0)))); 
                -- The C flag is unaffected if the shift value is 0. Otherwise, the C flag is updated to the last bit shifted out.
                if ( unsigned( operand_B (4 downto 0)) = B"00000") then 
                    -- C will not be changed
                else
                    alu_temp (32) <= alu_temp (31);                                    
                end if;    
            
           
            -------------------------------------------------------------------------------------- --  LDR <Rt>, [<Rn>{,#<imm5>}]
            -------------------------------------------------------------------------------------- --  LDRH <Rt>,[<Rn>{,#<imm5>}]
            -------------------------------------------------------------------------------------- --  LDRB <Rt>,[<Rn>{,#<imm5>}]
            -------------------------------------------------------------------------------------- --  LDR <Rt>,[<Rn>,<Rm>]
            -------------------------------------------------------------------------------------- --  LDRH <Rt>,[<Rn>,<Rm>]
            -------------------------------------------------------------------------------------- --  LDRSH <Rt>,[<Rn>,<Rm>]
            -------------------------------------------------------------------------------------- --  LDRB <Rt>,[<Rn>,<Rm>]
            -------------------------------------------------------------------------------------- --  LDRSB <Rt>,[<Rn>,<Rm>]
            -------------------------------------------------------------------------------------- --  LDR <Rt>,<label>
            -------------------------------------------------------------------------------------- --  LDM <Rn>!,<registers>
            when  LDR | LDR_imm5 | LDRH_imm5 | LDRB_imm5 | LDRH | LDRSH | LDRB | 
                  LDRSB | LDR_label | LDM  =>             
                alu_temp <= (others => '0');            -- just set the result to 0 but it will not be used
            
            -------------------------------------------------------------------------------------- --  STR <Rt>, [<Rn>{,#<imm5>}]
            -------------------------------------------------------------------------------------- --  STRH <Rt>,[<Rn>{,#<imm5>}]       
            -------------------------------------------------------------------------------------- --  STRB <Rt>,[<Rn>{,#<imm5>}]       
            -------------------------------------------------------------------------------------- --  STR <Rt>,[<Rn>,<Rm>]             
            -------------------------------------------------------------------------------------- --  STRH <Rt>,[<Rn>,<Rm>]            
            -------------------------------------------------------------------------------------- --  STRB <Rt>,[<Rn>,<Rm>]            
            -------------------------------------------------------------------------------------- --  STR <Rt>,[SP,#<imm8>]            
            -------------------------------------------------------------------------------------- --  STM <Rn>!,<registers>            
            when STR_imm5 | STRH_imm5 | STRB_imm5 | STR | STRH | STRB | STR_SP_imm8 | STM =>
                 alu_temp <= (others => '0');            -- just set the result to 0 but it will not be used   
            
            -------------------------------------------------------------------------------------- --  PUSH <registers>
            -------------------------------------------------------------------------------------- --  POP <registers>
            when PUSH | POP =>
                 alu_temp <= (others => '0');            -- just set the result to 0 but it will not be used                       

            -------------------------------------------------------------------------------------- --  B <label>    T1
            -------------------------------------------------------------------------------------- --  B <label>    T2
            -------------------------------------------------------------------------------------- --  BL <label>  
            -------------------------------------------------------------------------------------- --  BX Rm  
            when BRANCH | BRANCH_imm11 | BL | BX =>
                 alu_temp <= (others => '0');            -- just set the result to 0 but it will not be used                       

             
            -------------------------------------------------------------------------------------- -- others indefined instructions
            when NOP =>
                alu_temp <= (others => '0');   
            when others  =>
                alu_temp <= (others => '0');    
        end case;       
     end process;

     alu_result <= std_logic_vector(alu_temp(31 downto 0));
     result <= result_final;

end Behavioral;
