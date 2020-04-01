
################################################################
# This is a generated script based on design: system
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2018.3
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_msg_id "BD_TCL-109" "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source system_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# cortex_m0_core

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xczu7ev-ffvc1156-2-e
   set_property BOARD_PART xilinx.com:zcu104:part0:1.1 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name system

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_msg_id "BD_TCL-001" "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_msg_id "BD_TCL-002" "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_msg_id "BD_TCL-003" "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_msg_id "BD_TCL-004" "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_msg_id "BD_TCL-005" "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_msg_id "BD_TCL-114" "ERROR" $errMsg}
   return $nRet
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set clk_300mhz [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 clk_300mhz ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {300000000} \
   ] $clk_300mhz

  # Create ports
  set LED0 [ create_bd_port -dir O -type data LED0 ]
  set LED1 [ create_bd_port -dir O -type data LED1 ]
  set reset [ create_bd_port -dir I -type rst reset ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_HIGH} \
 ] $reset

  # Create instance: BRAM_32KB_0, and set properties
  set BRAM_32KB_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 BRAM_32KB_0 ]
  set_property -dict [ list \
   CONFIG.Byte_Size {9} \
   CONFIG.Coe_File {../../../../program.coe} \
   CONFIG.EN_SAFETY_CKT {false} \
   CONFIG.Enable_32bit_Address {false} \
   CONFIG.Fill_Remaining_Memory_Locations {true} \
   CONFIG.Load_Init_File {true} \
   CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
   CONFIG.Use_Byte_Write_Enable {false} \
   CONFIG.Use_RSTA_Pin {false} \
   CONFIG.Write_Depth_A {32768} \
   CONFIG.use_bram_block {Stand_Alone} \
 ] $BRAM_32KB_0

  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [ list \
   CONFIG.CLKIN1_JITTER_PS {33.330000000000005} \
   CONFIG.CLKOUT1_JITTER {116.415} \
   CONFIG.CLKOUT1_PHASE_ERROR {77.836} \
   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.000} \
   CONFIG.CLK_IN1_BOARD_INTERFACE {clk_300mhz} \
   CONFIG.CLK_IN2_BOARD_INTERFACE {Custom} \
   CONFIG.CLK_OUT1_PORT {CLK} \
   CONFIG.MMCM_CLKFBOUT_MULT_F {4.000} \
   CONFIG.MMCM_CLKIN1_PERIOD {3.333} \
   CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
   CONFIG.MMCM_CLKOUT0_DIVIDE_F {24.000} \
   CONFIG.MMCM_DIVCLK_DIVIDE {1} \
   CONFIG.PRIM_SOURCE {Differential_clock_capable_pin} \
   CONFIG.RESET_BOARD_INTERFACE {reset} \
   CONFIG.USE_BOARD_FLOW {true} \
 ] $clk_wiz_0

  # Create instance: constant_0, and set properties
  set constant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 constant_0 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
 ] $constant_0

  # Create instance: constant_0_16bit, and set properties
  set constant_0_16bit [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 constant_0_16bit ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
   CONFIG.CONST_WIDTH {16} \
 ] $constant_0_16bit

  # Create instance: constant_1, and set properties
  set constant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 constant_1 ]

  # Create instance: cortex_m0_core_0, and set properties
  set block_name cortex_m0_core
  set block_cell_name cortex_m0_core_0
  if { [catch {set cortex_m0_core_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_msg_id "BD_TCL-105" "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $cortex_m0_core_0 eq "" } {
     catch {common::send_msg_id "BD_TCL-106" "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property -dict [ list \
   CONFIG.S_PROGRAM_MEMORY_ENDIAN {true} \
 ] $cortex_m0_core_0

  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
  set_property -dict [ list \
   CONFIG.DIN_FROM {1} \
   CONFIG.DIN_TO {1} \
   CONFIG.DIN_WIDTH {2} \
   CONFIG.DOUT_WIDTH {1} \
 ] $xlslice_0

  # Create instance: xlslice_1, and set properties
  set xlslice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1 ]
  set_property -dict [ list \
   CONFIG.DIN_FROM {16} \
   CONFIG.DIN_TO {2} \
   CONFIG.DOUT_WIDTH {15} \
 ] $xlslice_1

  # Create interface connections
  connect_bd_intf_net -intf_net clk_300mhz_1 [get_bd_intf_ports clk_300mhz] [get_bd_intf_pins clk_wiz_0/CLK_IN1_D]

  # Create port connections
  connect_bd_net -net BRAM_32KB_0_douta [get_bd_pins BRAM_32KB_0/douta] [get_bd_pins cortex_m0_core_0/HRDATA]
  connect_bd_net -net clk_wiz_0_CLK [get_bd_pins BRAM_32KB_0/clka] [get_bd_pins clk_wiz_0/CLK] [get_bd_pins cortex_m0_core_0/HCLK]
  connect_bd_net -net clk_wiz_0_locked [get_bd_pins clk_wiz_0/locked] [get_bd_pins cortex_m0_core_0/HRESETn]
  connect_bd_net -net constant_0_16bit_dout [get_bd_pins constant_0_16bit/dout] [get_bd_pins cortex_m0_core_0/IRQ]
  connect_bd_net -net constant_0_dout [get_bd_pins constant_0/dout] [get_bd_pins cortex_m0_core_0/HRESP] [get_bd_pins cortex_m0_core_0/NMI] [get_bd_pins cortex_m0_core_0/RXEV]
  connect_bd_net -net cortex_m0_core_0_HADDR [get_bd_pins cortex_m0_core_0/HADDR] [get_bd_pins xlslice_1/Din]
  connect_bd_net -net cortex_m0_core_0_HTRANS [get_bd_pins cortex_m0_core_0/HTRANS] [get_bd_pins xlslice_0/Din]
  connect_bd_net -net cortex_m0_core_0_HWDATA [get_bd_pins BRAM_32KB_0/dina] [get_bd_pins cortex_m0_core_0/HWDATA]
  connect_bd_net -net cortex_m0_core_0_HWRITE [get_bd_pins BRAM_32KB_0/wea] [get_bd_pins cortex_m0_core_0/HWRITE]
  connect_bd_net -net cortex_m0_core_0_LOCKUP [get_bd_ports LED0] [get_bd_pins cortex_m0_core_0/LOCKUP]
  connect_bd_net -net cortex_m0_core_0_SLEEPING [get_bd_ports LED1] [get_bd_pins cortex_m0_core_0/SLEEPING]
  connect_bd_net -net reset_1 [get_bd_ports reset] [get_bd_pins clk_wiz_0/reset]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins constant_1/dout] [get_bd_pins cortex_m0_core_0/HREADY]
  connect_bd_net -net xlslice_0_Dout [get_bd_pins BRAM_32KB_0/ena] [get_bd_pins xlslice_0/Dout]
  connect_bd_net -net xlslice_1_Dout [get_bd_pins BRAM_32KB_0/addra] [get_bd_pins xlslice_1/Dout]

  # Create address segments


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


