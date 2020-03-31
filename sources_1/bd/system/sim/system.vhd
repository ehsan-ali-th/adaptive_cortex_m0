--Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2018.3 (lin64) Build 2405991 Thu Dec  6 23:36:41 MST 2018
--Date        : Tue Mar 31 09:33:16 2020
--Host        : esi-OMEN-by-HP-Laptop-15-dc0xxx running 64-bit Ubuntu 19.04
--Command     : generate_target system.bd
--Design      : system
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity system is
  port (
    LED0 : out STD_LOGIC;
    LED1 : out STD_LOGIC;
    clk_300mhz_clk_n : in STD_LOGIC;
    clk_300mhz_clk_p : in STD_LOGIC;
    reset : in STD_LOGIC
  );
  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of system : entity is "system,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=system,x_ipVersion=1.00.a,x_ipLanguage=VHDL,numBlks=8,numReposBlks=8,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=1,numPkgbdBlks=0,bdsource=USER,da_board_cnt=6,synth_mode=OOC_per_IP}";
  attribute HW_HANDOFF : string;
  attribute HW_HANDOFF of system : entity is "system.hwdef";
end system;

architecture STRUCTURE of system is
  component system_blk_mem_gen_0_2 is
  port (
    clka : in STD_LOGIC;
    ena : in STD_LOGIC;
    wea : in STD_LOGIC_VECTOR ( 0 to 0 );
    addra : in STD_LOGIC_VECTOR ( 14 downto 0 );
    dina : in STD_LOGIC_VECTOR ( 31 downto 0 );
    douta : out STD_LOGIC_VECTOR ( 31 downto 0 )
  );
  end component system_blk_mem_gen_0_2;
  component system_clk_wiz_0_1 is
  port (
    clk_in1_p : in STD_LOGIC;
    clk_in1_n : in STD_LOGIC;
    reset : in STD_LOGIC;
    CLK : out STD_LOGIC;
    locked : out STD_LOGIC
  );
  end component system_clk_wiz_0_1;
  component system_xlslice_0_0 is
  port (
    Din : in STD_LOGIC_VECTOR ( 1 downto 0 );
    Dout : out STD_LOGIC_VECTOR ( 0 to 0 )
  );
  end component system_xlslice_0_0;
  component system_xlslice_1_0 is
  port (
    Din : in STD_LOGIC_VECTOR ( 31 downto 0 );
    Dout : out STD_LOGIC_VECTOR ( 14 downto 0 )
  );
  end component system_xlslice_1_0;
  component system_xlconstant_0_0 is
  port (
    dout : out STD_LOGIC_VECTOR ( 0 to 0 )
  );
  end component system_xlconstant_0_0;
  component system_xlconstant_0_1 is
  port (
    dout : out STD_LOGIC_VECTOR ( 0 to 0 )
  );
  end component system_xlconstant_0_1;
  component system_xlconstant_0_2 is
  port (
    dout : out STD_LOGIC_VECTOR ( 15 downto 0 )
  );
  end component system_xlconstant_0_2;
  component system_cortex_m0_core_0_0 is
  port (
    HCLK : in STD_LOGIC;
    HRESETn : in STD_LOGIC;
    HRDATA : in STD_LOGIC_VECTOR ( 31 downto 0 );
    HREADY : in STD_LOGIC;
    HRESP : in STD_LOGIC;
    NMI : in STD_LOGIC;
    IRQ : in STD_LOGIC_VECTOR ( 15 downto 0 );
    RXEV : in STD_LOGIC;
    HADDR : out STD_LOGIC_VECTOR ( 31 downto 0 );
    HBURST : out STD_LOGIC_VECTOR ( 2 downto 0 );
    HMASTLOCK : out STD_LOGIC;
    HPROT : out STD_LOGIC_VECTOR ( 3 downto 0 );
    HSIZE : out STD_LOGIC_VECTOR ( 2 downto 0 );
    HTRANS : out STD_LOGIC_VECTOR ( 1 downto 0 );
    HWDATA : out STD_LOGIC_VECTOR ( 31 downto 0 );
    HWRITE : out STD_LOGIC;
    LOCKUP : out STD_LOGIC;
    SLEEPING : out STD_LOGIC;
    SYSTESETREQ : out STD_LOGIC;
    TXEV : out STD_LOGIC
  );
  end component system_cortex_m0_core_0_0;
  signal BRAM_32KB_0_douta : STD_LOGIC_VECTOR ( 31 downto 0 );
  signal clk_300mhz_1_CLK_N : STD_LOGIC;
  signal clk_300mhz_1_CLK_P : STD_LOGIC;
  signal clk_wiz_0_CLK : STD_LOGIC;
  signal clk_wiz_0_locked : STD_LOGIC;
  signal constant_0_16bit_dout : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal constant_0_dout : STD_LOGIC_VECTOR ( 0 to 0 );
  signal cortex_m0_core_0_HADDR : STD_LOGIC_VECTOR ( 31 downto 0 );
  signal cortex_m0_core_0_HTRANS : STD_LOGIC_VECTOR ( 1 downto 0 );
  signal cortex_m0_core_0_HWDATA : STD_LOGIC_VECTOR ( 31 downto 0 );
  signal cortex_m0_core_0_HWRITE : STD_LOGIC;
  signal cortex_m0_core_0_LOCKUP : STD_LOGIC;
  signal cortex_m0_core_0_SLEEPING : STD_LOGIC;
  signal reset_1 : STD_LOGIC;
  signal xlconstant_0_dout : STD_LOGIC_VECTOR ( 0 to 0 );
  signal xlslice_0_Dout : STD_LOGIC_VECTOR ( 0 to 0 );
  signal xlslice_1_Dout : STD_LOGIC_VECTOR ( 14 downto 0 );
  signal NLW_cortex_m0_core_0_HMASTLOCK_UNCONNECTED : STD_LOGIC;
  signal NLW_cortex_m0_core_0_SYSTESETREQ_UNCONNECTED : STD_LOGIC;
  signal NLW_cortex_m0_core_0_TXEV_UNCONNECTED : STD_LOGIC;
  signal NLW_cortex_m0_core_0_HBURST_UNCONNECTED : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal NLW_cortex_m0_core_0_HPROT_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_cortex_m0_core_0_HSIZE_UNCONNECTED : STD_LOGIC_VECTOR ( 2 downto 0 );
  attribute X_INTERFACE_INFO : string;
  attribute X_INTERFACE_INFO of LED0 : signal is "xilinx.com:signal:data:1.0 DATA.LED0 DATA";
  attribute X_INTERFACE_PARAMETER : string;
  attribute X_INTERFACE_PARAMETER of LED0 : signal is "XIL_INTERFACENAME DATA.LED0, LAYERED_METADATA undef";
  attribute X_INTERFACE_INFO of LED1 : signal is "xilinx.com:signal:data:1.0 DATA.LED1 DATA";
  attribute X_INTERFACE_PARAMETER of LED1 : signal is "XIL_INTERFACENAME DATA.LED1, LAYERED_METADATA undef";
  attribute X_INTERFACE_INFO of clk_300mhz_clk_n : signal is "xilinx.com:interface:diff_clock:1.0 clk_300mhz CLK_N";
  attribute X_INTERFACE_PARAMETER of clk_300mhz_clk_n : signal is "XIL_INTERFACENAME clk_300mhz, CAN_DEBUG false, FREQ_HZ 300000000";
  attribute X_INTERFACE_INFO of clk_300mhz_clk_p : signal is "xilinx.com:interface:diff_clock:1.0 clk_300mhz CLK_P";
  attribute X_INTERFACE_INFO of reset : signal is "xilinx.com:signal:reset:1.0 RST.RESET RST";
  attribute X_INTERFACE_PARAMETER of reset : signal is "XIL_INTERFACENAME RST.RESET, INSERT_VIP 0, POLARITY ACTIVE_HIGH";
begin
  LED0 <= cortex_m0_core_0_LOCKUP;
  LED1 <= cortex_m0_core_0_SLEEPING;
  clk_300mhz_1_CLK_N <= clk_300mhz_clk_n;
  clk_300mhz_1_CLK_P <= clk_300mhz_clk_p;
  reset_1 <= reset;
BRAM_32KB_0: component system_blk_mem_gen_0_2
     port map (
      addra(14 downto 0) => xlslice_1_Dout(14 downto 0),
      clka => clk_wiz_0_CLK,
      dina(31 downto 0) => cortex_m0_core_0_HWDATA(31 downto 0),
      douta(31 downto 0) => BRAM_32KB_0_douta(31 downto 0),
      ena => xlslice_0_Dout(0),
      wea(0) => cortex_m0_core_0_HWRITE
    );
clk_wiz_0: component system_clk_wiz_0_1
     port map (
      CLK => clk_wiz_0_CLK,
      clk_in1_n => clk_300mhz_1_CLK_N,
      clk_in1_p => clk_300mhz_1_CLK_P,
      locked => clk_wiz_0_locked,
      reset => reset_1
    );
constant_0: component system_xlconstant_0_1
     port map (
      dout(0) => constant_0_dout(0)
    );
constant_0_16bit: component system_xlconstant_0_2
     port map (
      dout(15 downto 0) => constant_0_16bit_dout(15 downto 0)
    );
constant_1: component system_xlconstant_0_0
     port map (
      dout(0) => xlconstant_0_dout(0)
    );
cortex_m0_core_0: component system_cortex_m0_core_0_0
     port map (
      HADDR(31 downto 0) => cortex_m0_core_0_HADDR(31 downto 0),
      HBURST(2 downto 0) => NLW_cortex_m0_core_0_HBURST_UNCONNECTED(2 downto 0),
      HCLK => clk_wiz_0_CLK,
      HMASTLOCK => NLW_cortex_m0_core_0_HMASTLOCK_UNCONNECTED,
      HPROT(3 downto 0) => NLW_cortex_m0_core_0_HPROT_UNCONNECTED(3 downto 0),
      HRDATA(31 downto 0) => BRAM_32KB_0_douta(31 downto 0),
      HREADY => xlconstant_0_dout(0),
      HRESETn => clk_wiz_0_locked,
      HRESP => constant_0_dout(0),
      HSIZE(2 downto 0) => NLW_cortex_m0_core_0_HSIZE_UNCONNECTED(2 downto 0),
      HTRANS(1 downto 0) => cortex_m0_core_0_HTRANS(1 downto 0),
      HWDATA(31 downto 0) => cortex_m0_core_0_HWDATA(31 downto 0),
      HWRITE => cortex_m0_core_0_HWRITE,
      IRQ(15 downto 0) => constant_0_16bit_dout(15 downto 0),
      LOCKUP => cortex_m0_core_0_LOCKUP,
      NMI => constant_0_dout(0),
      RXEV => constant_0_dout(0),
      SLEEPING => cortex_m0_core_0_SLEEPING,
      SYSTESETREQ => NLW_cortex_m0_core_0_SYSTESETREQ_UNCONNECTED,
      TXEV => NLW_cortex_m0_core_0_TXEV_UNCONNECTED
    );
xlslice_0: component system_xlslice_0_0
     port map (
      Din(1 downto 0) => cortex_m0_core_0_HTRANS(1 downto 0),
      Dout(0) => xlslice_0_Dout(0)
    );
xlslice_1: component system_xlslice_1_0
     port map (
      Din(31 downto 0) => cortex_m0_core_0_HADDR(31 downto 0),
      Dout(14 downto 0) => xlslice_1_Dout(14 downto 0)
    );
end STRUCTURE;
