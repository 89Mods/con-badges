SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/VLIW/execution_unit.v $(PWD)/VLIW/icache.v $(PWD)/VLIW/mul.v $(PWD)/VLIW/spi.v $(PWD)/VLIW/top_vliw.v $(PWD)/VLIW/uart.v $(PWD)/VLIW/vliw_top.v $(PWD)/../FPGA_SRC/VLIWBadgeCtrl.v $(PWD)/board.v $(PWD)/fastram.v $(PWD)/../FPGA_SRC/clkdiv.v $(PWD)/../FPGA_SRC/uart.v $(PWD)/../FPGA_SRC/psg.v $(PWD)/IS61WV102416.v $(PWD)/AS6C6416.v

TOPLEVEL = board

MODULE = test

COMPILE_ARGS += -DBENCH

include $(shell cocotb-config --makefiles)/Makefile.sim
