-- (c) Copyright 1995-2020 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- DO NOT MODIFY THIS FILE.

-- IP VLNV: xilinx.com:module_ref:bus_matrix:1.0
-- IP Revision: 1

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY system_bus_matrix_0_0 IS
  PORT (
    clk : IN STD_LOGIC;
    reset : IN STD_LOGIC;
    cortex_m0_HADDR : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    cortex_m0_HWDATA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    cortex_m0_HWRITE : IN STD_LOGIC;
    cortex_m0_HRDATA : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    code_bram_DOUTA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    code_bram_ADDRA : OUT STD_LOGIC_VECTOR(14 DOWNTO 0);
    code_bram_DINA : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    code_bram_ENA : OUT STD_LOGIC;
    code_bram_WEA : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    data_bram_DOUTA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    data_bram_ADDRA : OUT STD_LOGIC_VECTOR(14 DOWNTO 0);
    data_bram_DINA : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    data_bram_ENA : OUT STD_LOGIC;
    data_bram_WEA : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
  );
END system_bus_matrix_0_0;

ARCHITECTURE system_bus_matrix_0_0_arch OF system_bus_matrix_0_0 IS
  ATTRIBUTE DowngradeIPIdentifiedWarnings : STRING;
  ATTRIBUTE DowngradeIPIdentifiedWarnings OF system_bus_matrix_0_0_arch: ARCHITECTURE IS "yes";
  COMPONENT bus_matrix IS
    PORT (
      clk : IN STD_LOGIC;
      reset : IN STD_LOGIC;
      cortex_m0_HADDR : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      cortex_m0_HWDATA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      cortex_m0_HWRITE : IN STD_LOGIC;
      cortex_m0_HRDATA : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      code_bram_DOUTA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      code_bram_ADDRA : OUT STD_LOGIC_VECTOR(14 DOWNTO 0);
      code_bram_DINA : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      code_bram_ENA : OUT STD_LOGIC;
      code_bram_WEA : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      data_bram_DOUTA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      data_bram_ADDRA : OUT STD_LOGIC_VECTOR(14 DOWNTO 0);
      data_bram_DINA : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
      data_bram_ENA : OUT STD_LOGIC;
      data_bram_WEA : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
  END COMPONENT bus_matrix;
  ATTRIBUTE IP_DEFINITION_SOURCE : STRING;
  ATTRIBUTE IP_DEFINITION_SOURCE OF system_bus_matrix_0_0_arch: ARCHITECTURE IS "module_ref";
  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER OF reset: SIGNAL IS "XIL_INTERFACENAME reset, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF reset: SIGNAL IS "xilinx.com:signal:reset:1.0 reset RST";
  ATTRIBUTE X_INTERFACE_PARAMETER OF clk: SIGNAL IS "XIL_INTERFACENAME clk, ASSOCIATED_RESET reset, FREQ_HZ 50000000, PHASE 0.0, CLK_DOMAIN system_clk_wiz_0_1_CLK, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF clk: SIGNAL IS "xilinx.com:signal:clock:1.0 clk CLK";
BEGIN
  U0 : bus_matrix
    PORT MAP (
      clk => clk,
      reset => reset,
      cortex_m0_HADDR => cortex_m0_HADDR,
      cortex_m0_HWDATA => cortex_m0_HWDATA,
      cortex_m0_HWRITE => cortex_m0_HWRITE,
      cortex_m0_HRDATA => cortex_m0_HRDATA,
      code_bram_DOUTA => code_bram_DOUTA,
      code_bram_ADDRA => code_bram_ADDRA,
      code_bram_DINA => code_bram_DINA,
      code_bram_ENA => code_bram_ENA,
      code_bram_WEA => code_bram_WEA,
      data_bram_DOUTA => data_bram_DOUTA,
      data_bram_ADDRA => data_bram_ADDRA,
      data_bram_DINA => data_bram_DINA,
      data_bram_ENA => data_bram_ENA,
      data_bram_WEA => data_bram_WEA
    );
END system_bus_matrix_0_0_arch;
