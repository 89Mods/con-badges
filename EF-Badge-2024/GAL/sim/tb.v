module tb(
	input clk
);

`ifdef TRACE_ON
initial begin
	$dumpfile("tb.vcd");
	$dumpvars();
end
`endif

integer test_step = 0;

reg [9:0] test_inputs;
always @(*) begin
	case(test_step)
		default: test_inputs = 10'b1000101111;
		//RAM Read
		6: test_inputs = 10'b1010000000;
		7: test_inputs = 10'b1010100000;
		//RAM Write
		//6: test_inputs = 10'b1000010000;
		//7: test_inputs = 10'b1000110000;
		//RAM Write
		8: test_inputs = 10'b1000010000;
		9: test_inputs = 10'b1000110000;
		//ROM Read
		10: test_inputs = 10'b1001001100;
		11: test_inputs = 10'b1001101100;
		12: test_inputs = 10'b1001101100;
		//ROM Read (cont.)
		13: test_inputs = 10'b1001000011;
		14: test_inputs = 10'b1001100011;
		15: test_inputs = 10'b1001100011;
		//CPLD Write
		16: test_inputs = 10'b0110010000;
		17: test_inputs = 10'b0110110000;
		18: test_inputs = 10'b0110110000;
		//CPLD Read
		19: test_inputs = 10'b0110000000;
		20: test_inputs = 10'b0110100000;
		21: test_inputs = 10'b0110100000;
		
		//ATA Read
		25: test_inputs = 10'b0100000000;
		26: test_inputs = 10'b0100100000;
		27: test_inputs = 10'b0100100000;
		
		//ATA Write
		29: test_inputs = 10'b0000010000;
		30: test_inputs = 10'b0000110000;
		31: test_inputs = 10'b0000110000;
		
		//ROM Read followed by ATA Write followed by ROM Read
		40: test_inputs = 10'b1001001100;
		41: test_inputs = 10'b1001101100;
		42: test_inputs = 10'b1001101100;
		43: test_inputs = 10'b1001000011;
		44: test_inputs = 10'b1001100011;
		45: test_inputs = 10'b1001100011;
		
		46: test_inputs = 10'b0100010000;
		47: test_inputs = 10'b0100110000;
		48: test_inputs = 10'b0100110000;
		49: test_inputs = 10'b0100110000;
		
		50: test_inputs = 10'b1001001100;
		51: test_inputs = 10'b1001101100;
		52: test_inputs = 10'b1001101100;
		53: test_inputs = 10'b1001000011;
		54: test_inputs = 10'b1001100011;
		55: test_inputs = 10'b1001100011;
	endcase
end

reg clkdiv = 0;
always @(posedge clk) begin
	clkdiv <= !clkdiv;
	if(clkdiv) test_step <= test_step + 1;
end

gal gal(
	.clk(clk),
	.BE0b(test_inputs[0]),
	.BE1b(test_inputs[1]),
	.BE2b(test_inputs[2]),
	.BE3b(test_inputs[3]),
	.WR(test_inputs[4]),
	.ADS(test_inputs[5]),
	.A31(test_inputs[6]),
	.A13(test_inputs[7]),
	.A10(test_inputs[8]),
	.RESET(1'b0),
	.MIO(test_inputs[9]),

	.READYb(),
	.STATE0(),
	.ATAOEb(),
	.ATACS0b(),
	.CPLDCSb(),
	.A1(),
	.ROMCSb(),
	.STATE1(),
	.RAMCEb(),
	.WEb()
);

endmodule
