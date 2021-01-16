----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/24/2020 04:40:02 PM
-- Design Name: 
-- Module Name: status_flags - Behavioral
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

entity status_flags is
    Port (
        clk : in std_logic;
        reset : in std_logic;
        result : in std_logic_vector(31 downto 0);
        C_in : in std_logic;
        overflow_status : in std_logic_vector(2 downto 0);      -- Concatenation of 3 bits: operand_A(31) & imm8_z_ext(31) & alu_result(31);
        cmd : in executor_cmds_t;
        set_flags : in boolean; 
        msr_flags : in boolean;
        Rn_content : in std_logic_vector(31 downto 28);                 -- MSR Rn carries new flag values that must be set
        flags_o : out flag_t;                                           -- current state of flags
        flags_o_value : out flag_t;                                     -- next state of flags
        xPSR : out std_logic_vector(31 downto 0)
    );
end status_flags;

architecture Behavioral of status_flags is
    signal status_flags_internal : bit_vector(31 downto 0) := (others=>'0');
    signal status_flags_internal_value : bit_vector(31 downto 0) := (others=>'0');
        
    alias N_value : bit is status_flags_internal_value(31);
    alias Z_value : bit is status_flags_internal_value(30);
    alias C_value : bit is status_flags_internal_value(29);
    alias V_value : bit is status_flags_internal_value(28);
    alias EN_value : bit_vector is status_flags_internal_value(5 downto 0);
    alias T_value : bit is status_flags_internal_value(24);

    alias N : bit is status_flags_internal(31);
    alias Z : bit is status_flags_internal(30);
    alias C : bit is status_flags_internal(29);
    alias V : bit is status_flags_internal(28);
    alias EN : bit_vector is status_flags_internal(5 downto 0);
    alias T : bit is status_flags_internal(24);
    
    constant zeros : std_logic_vector(result'range) := (others => '0');

begin

    flags_p : process (clk, reset) begin
        if (reset = '1') then
            status_flags_internal <= (others => '0');
        else
            if (rising_edge (clk)) then
                if set_flags then
--                    if (status_flags_internal_value(31) = '1') then -- Set carry only if it is set othwrwise leave its previous state
--                         status_flags_internal(31) <= status_flags_internal_value(31);
--                    end if;
----                    if (status_flags_internal_value(30) = '1') then -- Set carry only if it is set othwrwise leave its previous state
--                         status_flags_internal(30) <= status_flags_internal_value(30);
----                    end if;
--                    if (status_flags_internal_value(29) = '1') then -- Set carry only if it is set othwrwise leave its previous state
--                         status_flags_internal(29) <= status_flags_internal_value(29);
--                    end if;
--                    if (status_flags_internal_value(28) = '1') then -- Set carry only if it is set othwrwise leave its previous state
--                         status_flags_internal(28) <= status_flags_internal_value(28);
--                    end if;
--                    status_flags_internal(5 downto 0) <= status_flags_internal_value(5 downto 0);
--                    status_flags_internal(24) <= status_flags_internal_value(24);
                    status_flags_internal <= status_flags_internal_value;
                end if;                       
            end if;                       
        end if;
    end process;  
    
     cmd_p: process(reset, cmd, result, set_flags, overflow_status, C, V, msr_flags, Rn_content, C_in) begin
        if (reset = '1') then
            N_value <= '0';
            Z_value <= '0';
            C_value <= '0';
            V_value <= '0';
        else          
            if msr_flags then
                N_value <= to_bit (Rn_content (31));
                Z_value <= to_bit (Rn_content (30));
                C_value <= to_bit (Rn_content (29));
                V_value <= to_bit (Rn_content (28));
            else
                -- how to calculate overflow:
                -- There are two cases where the overflow flag would be turned on during a binary arithmetic operation:
                -- 1) The inputs both have sign bits that are off, while the result has a sign bit that is on.
                -- 2) The inputs both have sign bits that are on, while the result has a sign bit that is off.
                -- concat the three relevant sign-bits to one vector
                case (cmd) is
                    ------------------------------------------------------------ -- MOVS Rd, #(imm8)
                    when MOVS_imm8 =>                                       
                        -- APSR.N = result<31>;
                        -- APSR.Z = IsZeroBit(result);
                        -- APSR.C = carry;
                        -- // APSR.V unchanged
                        N_value <= to_bit (result(31));    
                        if (result = zeros) then Z_value <= '1'; else Z_value <= '0'; end if;
                        C_value <= C;
                        V_value <= V;
                    ------------------------------------------------------------ -- MOVS <Rd>,<Rm>  
                     when MOVS =>
                        -- APSR.N = result<31>;
                        -- APSR.Z = IsZeroBit(result);
                        -- // APSR.C unchanged
                        -- // APSR.V unchanged
                        N_value <= to_bit (result(31));  
                        if (result = zeros) then Z_value <= '1'; else Z_value <= '0'; end if;
                        C_value <= C;
                        V_value <= V;  
                    ------------------------------------------------------------ -- MOV <Rd>,<Rm> | MOV PC, Rm       
--                    when MOV =>
--                        -- APSR.N = result<31>;
--                        -- APSR.Z = IsZeroBit(result);
--                        -- // APSR.C unchanged
--                        -- // APSR.V unchanged
--                        N_value <= N_value;  
--                        Z_value <= Z_value;
--                        C_value <= C_value;
--                        V_value <= V_value;
                    ------------------------------------------------------------ -- ADDS <Rd>,<Rn>,#<imm3>      
                    ------------------------------------------------------------ -- ADDS <Rd>,<Rn>,<Rm>       
                    ------------------------------------------------------------- -- ADDS <Rdn>,#<imm8>   
                    ------------------------------------------------------------ -- ADCS <Rdn>,<Rm>  
                    when ADDS_imm3 | ADDS | ADDS_imm8 | ADCS =>    
                        -- APSR.N = result<31>;
                        -- APSR.Z = IsZeroBit(result);
                        -- APSR.C = carry;
                        -- APSR.V = overflow;
                        N_value <= to_bit (result(31)); 
                        if (result = zeros) then Z_value <= '1'; else Z_value <= '0'; end if;
                        C_value <= to_bit(C_in);
                        if ((overflow_status = B"001") or (overflow_status = B"110")) then V_value <= '1'; else V_value <= '0'; end if;
                    ------------------------------------------------------------ -- SUBS <Rd>,<Rn>,<Rm>
                    ------------------------------------------------------------ -- SUBS <Rd>,<Rn>,#<imm3>  
                    ------------------------------------------------------------ -- SBCS <Rdn>,<Rm>   
                    ------------------------------------------------------------ -- RSBS <Rd>,<Rn>,#0
                    ------------------------------------------------------------ -- CMP <Rn>,<Rm>
                    ------------------------------------------------------------ -- CMN <Rn>,<Rm>    
                    ------------------------------------------------------------ -- CMP <Rn>,#<imm8>     
                    when SUBS | SUBS_imm8 | SUBS_imm3 | SBCS | RSBS |
                          CMP | CMN | CMP_imm8 =>    
                        -- APSR.N = result<31>;
                        -- APSR.Z = IsZeroBit(result);
                        -- APSR.C = carry;
                        -- APSR.V = overflow;
                        N_value <= to_bit (result(31)); 
                        if (result = zeros) then Z_value <= '1'; else Z_value <= '0'; end if;
                        C_value <= to_bit(C_in);
                        if ((overflow_status = B"011") or
                            (overflow_status = B"100")) then V_value <= '1'; else V_value <= '0'; end if;    
--                        if ((overflow_status = B"001") or (overflow_status = B"110")) then V_value <= '1'; else V_value <= '0'; end if;
                    ------------------------------------------------------------ -- MULS <Rdm>,<Rn>,<Rdm>     
                    when MULS =>
                        -- APSR.N = result<31>;
                        -- APSR.Z = IsZeroBit(result<31:0>);
                        -- // APSR.C unchanged
                        -- // APSR.V unchanged
                        N_value <= to_bit (result(31)); 
                        if (result = zeros) then Z_value <= '1'; else Z_value <= '0'; end if;
                        C_value <= C;
                        V_value <= V;
                    ------------------------------------------------------------ -- ANDS <Rdn>,<Rm>    
                    ------------------------------------------------------------ -- EORS <Rdn>,<Rm>   
                    ------------------------------------------------------------ -- ORRS <Rdn>,<Rm>    
                    ------------------------------------------------------------ -- BICS <Rdn>,<Rm>    
                    ------------------------------------------------------------ -- MVNS <Rd>,<Rm>      
                    ------------------------------------------------------------ -- TST <Rn>,<Rm>   
                    ------------------------------------------------------------ -- RORS <Rdn>,<Rm> 
                    when ANDS | EORS | ORRS | BICS | MVNS | TST  =>
                        -- APSR.N = result<31>;
                        -- APSR.Z = IsZeroBit(result);
                        -- APSR.C = carry;
                        -- // APSR.V unchanged    
                        N_value <= to_bit (result(31)); 
                        if (result = zeros) then Z_value <= '1'; else Z_value <= '0'; end if;
                        -- C_value <= to_bit(C_in);  * BUG fixed: Carry does not change
                        -- V_value <= V;             * BUG fixed: V does not change   
                    when LSLS | LSLS_imm5 | LSRS | LSRS_imm5 | ASRS | ASRS_imm5 |
                         RORS => 
                        -- (result, carry) = Shift_C(R[m], SRType_LSR, shift_n, APSR.C);
                        --  R[d] = result;
                        --  if setflags then
                        -- APSR.N = result<31>;
                        -- APSR.Z = IsZeroBit(result);
                        -- APSR.C = carry;
                        -- // APSR.V unchanged    
                        N_value <= to_bit (result(31)); 
                        if (result = zeros) then Z_value <= '1'; else Z_value <= '0'; end if;
                        C_value <= to_bit(C_in);  
                        -- V_value <= V;             * BUG fixed: V does not change 
                        V_value <= V;               --  BUG fixed: V does not change 
                    when others =>  
                        null;
                 end case;
             end if;
         end if;
       end process cmd_p;

--    cmd_p: process(reset, cmd, result, set_flags, overflow_status, C) begin
--        if reset = '0' then 
--            if set_flags then
--                -- how to calculate overflow:
--                -- There are two cases where the overflow flag would be turned on during a binary arithmetic operation:
--                -- 1) The inputs both have sign bits that are off, while the result has a sign bit that is on.
--                -- 2) The inputs both have sign bits that are on, while the result has a sign bit that is off.
--                -- concat the three relevant sign-bits to one vector

--                case (cmd) is
--                    ------------------------------------------------------------ -- MOVS Rd, #(imm8)
--                    when MOVS_imm8 =>                                       
--                        -- APSR.N = result<31>;
--                        -- APSR.Z = IsZeroBit(result);
--                        -- APSR.C = carry;
--                        -- // APSR.V unchanged
--                        N <= to_bit (result(31));    
--                        if (to_integer(unsigned(result)) = 0) then Z <= '1'; else Z <= '0'; end if;
--                        C <= '0';
--                    ------------------------------------------------------------ -- MOVS <Rd>,<Rm>    
--                    ------------------------------------------------------------ -- MOV <Rd>,<Rm> | MOV PC, Rm       
--                    when MOVS | MOV =>
--                        -- APSR.N = result<31>;
--                        -- APSR.Z = IsZeroBit(result);
--                        -- // APSR.C unchanged
--                        -- // APSR.V unchanged
--                        N <= to_bit (result(31));  
--                        if (to_integer(unsigned(result)) = 0) then Z <= '1'; else Z <= '0'; end if;
--                    ------------------------------------------------------------ -- ADDS <Rd>,<Rn>,#<imm3>      
--                    ------------------------------------------------------------ -- ADDS <Rd>,<Rn>,<Rm>       
--                    ------------------------------------------------------------ -- ADDS <Rdn>,#<imm8>   
--                    ------------------------------------------------------------ -- ADCS <Rdn>,<Rm>  
--                    when ADDS_imm3 | ADDS | ADDS_imm8 | ADCS =>    
--                        -- APSR.N = result<31>;
--                        -- APSR.Z = IsZeroBit(result);
--                        -- APSR.C = carry;
--                        -- APSR.V = overflow;
--                        N <= to_bit (result(31)); 
--                        if (to_integer(unsigned(result)) = 0) then Z <= '1'; else Z <= '0'; end if;
--                        C <= to_bit(C_in);
--                        if ((overflow_status = B"001") or (overflow_status = B"110")) then V <= '1'; else V <= '0'; end if;
--                    ------------------------------------------------------------ -- SUBS <Rd>,<Rn>,<Rm>
--                    ------------------------------------------------------------ -- SUBS <Rd>,<Rn>,#<imm3>  
--                    ------------------------------------------------------------ -- SBCS <Rdn>,<Rm>   
--                    ------------------------------------------------------------ -- RSBS <Rd>,<Rn>,#0
--                    ------------------------------------------------------------ -- CMP <Rn>,<Rm>
--                    ------------------------------------------------------------ -- CMN <Rn>,<Rm>    
--                    ------------------------------------------------------------ -- CMP <Rn>,#<imm8>     
--                    when SUBS | SUBS_imm8 | SBCS | RSBS |
--                          CMP | CMN | CMP_imm8 =>    
--                        -- APSR.N = result<31>;
--                        -- APSR.Z = IsZeroBit(result);
--                        -- APSR.C = carry;
--                        -- APSR.V = overflow;
--                        N <= to_bit (result(31)); 
--                        if (to_integer(unsigned(result)) = 0) then Z <= '1'; else Z <= '0'; end if;
--                        C <= to_bit(C_in);
--                        if ((overflow_status = B"011") or
--                            (overflow_status = B"101") or 
--                            (overflow_status = B"100") or
--                            (overflow_status = B"010")) then V <= '1'; else V <= '0'; end if;    
--                    ------------------------------------------------------------ -- MULS <Rdm>,<Rn>,<Rdm>     
--                    when MULS =>
--                        -- APSR.N = result<31>;
--                        -- APSR.Z = IsZeroBit(result<31:0>);
--                        -- // APSR.C unchanged
--                        -- // APSR.V unchanged
--                        N <= to_bit (result(31)); 
--                        if (to_integer(unsigned(result)) = 0) then Z <= '1'; else Z <= '0'; end if;
--                    ------------------------------------------------------------ -- ANDS <Rdn>,<Rm>    
--                    ------------------------------------------------------------ -- EORS <Rdn>,<Rm>   
--                    ------------------------------------------------------------ -- ORRS <Rdn>,<Rm>    
--                    ------------------------------------------------------------ -- BICS <Rdn>,<Rm>    
--                    ------------------------------------------------------------ -- MVNS <Rd>,<Rm>      
--                    ------------------------------------------------------------ -- TST <Rn>,<Rm>   
--                    ------------------------------------------------------------ -- RORS <Rdn>,<Rm> 
--                    when ANDS | EORS | ORRS | BICS | MVNS | TST  =>
--                        -- APSR.N = result<31>;
--                        -- APSR.Z = IsZeroBit(result);
--                        -- APSR.C = carry;
--                        -- // APSR.V unchanged    
--                        N <= to_bit (result(31)); 
--                        if (to_integer(unsigned(result)) = 0) then Z <= '1'; else Z <= '0'; end if;
--                        C <= to_bit(C_in);
--                    when others =>  
--                        null;
--                 end case;
--              end if; -- set_flags
--         else
--            status_flags_internal <= (others => '0');
--         end if;      
        
--    end process cmd_p;

    flags_o.N <= N;
    flags_o.Z <= Z;
    flags_o.C <= C;
    flags_o.V <= V;
    flags_o.EN <= EN;
    flags_o.T <= T;
    
    flags_o_value.N <= N_value;
    flags_o_value.Z <= Z_value;
    flags_o_value.C <= C_value;
    flags_o_value.EN <= EN_value;
    flags_o_value.T <= T_value;

   
    
    -- convert bit_vector to std_logic_vector
    assign_status_flags_to_xPSR: process (status_flags_internal) begin
	    for I in 0 to 31 loop
			xPSR(I) <= to_std_logic(status_flags_internal (I));
    	end loop;
    end process;
    
end Behavioral;
