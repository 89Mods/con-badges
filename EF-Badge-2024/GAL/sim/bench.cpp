#include "Vtb.h"
#include "verilated.h"
#include <iostream>

static Vtb top;

double sc_time_stamp() { return 0; }

void halfclk() {
	top.clk = !top.clk;
	Verilated::timeInc(5);
	top.eval();
}

int main(int argc, char** argv, char** env) {
#ifdef TRACE_ON
	std::cout << "Warning: tracing is ON!" << std::endl;
	Verilated::traceEverOn(true);
#endif
	top.clk = 0;
	Verilated::timeInc(1);
	top.eval();
	Verilated::timeInc(1);
	top.eval();
	Verilated::timeInc(1);
	top.eval();

	for(int i = 0; i < 230; i++) {
		halfclk();
	}
	
	top.final();
	return 0;
}
