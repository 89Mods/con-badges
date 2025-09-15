import cocotb
import random
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, FallingEdge, RisingEdge

@cocotb.test()
async def test_system(dut):
	dut._log.info("Start")
	dut.porb.value = 0
	clock = Clock(dut.clk, 8, units="ns")
	cocotb.start_soon(clock.start())
	await Timer(76, units="ns")
	dut.porb.value = 1
	await Timer(3000, units="us")
