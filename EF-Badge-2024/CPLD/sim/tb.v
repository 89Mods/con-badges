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

reg [23:0] test_data;
reg ADS;
reg MIO;
reg WR;
reg [2:0] addr;

always @(*) begin
	case(test_step>>1)
		default: begin
			ADS = 1;
			MIO = 1;
			WR = 0;
			addr = 0;
			test_data = 0;
		end
		4: begin
			ADS = 0;
			MIO = 0;
			WR = 1;
			addr = 5;
			test_data = 'hF7A329;
		end
		5: begin
			ADS = 1;
			MIO = 0;
			WR = 1;
			addr = 5;
			test_data = 'hF7A329;
		end
		6: begin
			ADS = 1;
			MIO = 0;
			WR = 1;
			addr = 5;
			test_data = 'hF7A329;
		end
		
		10: begin
			ADS = 0;
			MIO = 0;
			WR = 1;
			addr = 5;
			test_data = 'hF7A329;
		end
		11: begin
			ADS = 1;
			MIO = 0;
			WR = 1;
			addr = 5;
			test_data = 'hF7A329;
		end
		12: begin
			ADS = 1;
			MIO = 0;
			WR = 1;
			addr = 5;
			test_data = 'hF7A329;
		end
		
		15: begin
			ADS = 0;
			MIO = 0;
			WR = 1;
			addr = 5;
			test_data = 'h0000ff;
		end
		16: begin
			ADS = 1;
			MIO = 0;
			WR = 1;
			addr = 5;
			test_data = 'h0000ff;
		end
		17: begin
			ADS = 1;
			MIO = 0;
			WR = 1;
			addr = 5;
			test_data = 'h0000ff;
		end
		
		19: begin
			ADS = 0;
			MIO = 0;
			WR = 1;
			addr = 3;
			test_data = 'h0000ff;
		end
		20: begin
			ADS = 1;
			MIO = 0;
			WR = 1;
			addr = 3;
			test_data = 'h0000ff;
		end
		21: begin
			ADS = 1;
			MIO = 0;
			WR = 1;
			addr = 3;
			test_data = 'h0000ff;
		end
	endcase
end

reg clkdiv = 0;
always @(posedge clk) begin
	clkdiv <= !clkdiv;
	if(clkdiv) test_step <= test_step + 1;
end

wire [15:0] VRAM_dat;
wire [23:0] data = WR ? test_data : 24'hzzzzzz;
top top(
	.clk(clk),
	.bdir(),
	.UTX(),
	.URX(1'b1),
	.VRAM_CSb(),
	.VRAM_UBb(),
	.VRAM_LBb(),
	.VRAM_OEb(),
	.VRAM_WEb(),
	.VRAM_addr(),
	.VRAM_dat(VRAM_dat),
	.DISP_CSb(),
	.CPU_int(),
	.NES_clk(),
	.NES_latch(),
	.NES_data(1'b0),
	
	.ADS(ADS),
	.MIO(MIO),
	.WR(WR),
	.addr(addr),
	.data(data)
);

endmodule
