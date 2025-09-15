`default_nettype none
`timescale 1ps / 1ps

module board(
	input clk,
	input porb
);

wire cpu_resetb;
wire [35:0] cpu_io;
wire M1 = cpu_io[1];
vliw_top cpu(
	.clk(xclk),
	.rstn(cpu_resetb),
	.io(cpu_io)
);

wire SCLK = cpu_io[27];
wire SDO = cpu_io[28];
wire SDI = cpu_io[29];
assign cpu_io[29] = cpu_io[30] ? 1'b1 : 1'b0;

wire LE_HI = cpu_io[19];
wire LE_LO = cpu_io[20];
reg [30:0] address_latch = 69;
wire [30:0] A = {LE_HI ? cpu_io[17:3] : address_latch[30:16], LE_LO ? cpu_io[18:3] : address_latch[15:0]};
always @(posedge clk) if(LE_LO) address_latch[15:0] <= cpu_io[18:3];
always @(posedge clk) if(LE_HI) address_latch[30:16] <= cpu_io[17:3];

wire [11:0] DISP_D;
wire [19:0] VRAM_A;
wire VRAM_CSb;
wire VRAM_OEb;
wire VRAM_WEb;

wire xclk;
VLIWBadgeCtrl fpga(
	.inclk(clk),
	.porb(porb),
	.caravel_resetb(),
	.cpu_resetb(cpu_resetb),
	.xclk(xclk),
	.LE_HI(LE_HI),
	.LE_LO(LE_LO),
	.OEb(cpu_io[22]),
	.WEb_LO(cpu_io[23]),
	.WEb_HI(cpu_io[24]),
	.CPU_INTERRUPT(cpu_io[31]),
	.AD(cpu_io[18:3]),
	.caravel_gpio(1'b0),
	
	.DISP_D(DISP_D),
	.VRAM_A(VRAM_A),
	.VRAM_CSb(VRAM_CSb),
	.VRAM_OEb(VRAM_OEb),
	.VRAM_WEb(VRAM_WEb),
	
	.TXD(),
	.RXD(1'b1)
);

tri0 [3:0] unused_Ds;
IS61WV102416 vram(
	.A(VRAM_A),
	.IO({unused_Ds, DISP_D}),
	.CEb(VRAM_CSb),
	.LBb(VRAM_CSb),
	.UBb(VRAM_CSb),
	.OEb(VRAM_OEb),
	.WEb(VRAM_WEb)
);

AS6C6416 ram(
	.A(A),
	.IO(cpu_io[18:3]),
	.CEb(A[23]),
	.CE2(1'b1),
	.LBb(cpu_io[23] && cpu_io[22]),
	.UBb(cpu_io[24] && cpu_io[22]),
	.OEb(cpu_io[22]),
	.WEb(cpu_io[23] && cpu_io[24])
);

initial begin
	$dumpfile("tb.vcd");
	$dumpvars();
end

endmodule
