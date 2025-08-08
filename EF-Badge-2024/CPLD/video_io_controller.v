`define DIR_TO_CPLD 0
`define DIR_TO_CPU 1

module video_io_controller(
	output bdir,
	output UTX,
	input URX,
	output VRAM_CSb,
	output VRAM_UBb,
	output VRAM_LBb,
	output VRAM_OEb, //doubles as DISP_WR
	output VRAM_WEb, //doubles as DISP_DC
	output [19:0] VRAM_addr,
	inout [15:0] VRAM_dat, //doubles as DISP_dat
	output DISP_CSb,
	output CPU_int,
	input ADS,
	input MIO,
	input WR,
	input clk,
	input [2:0] addr,
	output reg NES_clk = 0,
	output reg NES_latch = 0,
	input NES_data,
	inout [23:0] data
);

reg ads_edge = 1;

wire memory_act = ads_edge && !ADS && !MIO;
wire writing = memory_act && WR;
wire reading = memory_act && !WR;

wire uart_busy;
wire uart_has_byte;
wire [7:0] uart_dout;

reg [7:0] read_value;
always @(*) begin
	case(addr[0])
		0: read_value = {4'h0, copying, NES_data, uart_busy, uart_has_byte};
		1: read_value = uart_dout;
	endcase
end
assign bdir = !ADS && !MIO && !WR ? `DIR_TO_CPU : `DIR_TO_CPLD;
assign data = bdir == `DIR_TO_CPU ? {16'h0000, read_value} : 23'hzzzzzz;

reg [23:0] vram_wval;
reg [19:0] vram_ptr;
assign VRAM_addr = vram_ptr;
reg [1:0] vram_write;
reg lcd_cmd = 0;

assign VRAM_dat = vram_write == 2 ? (
	vram_ptr[0] ? {vram_wval[7:0], vram_wval[7:0]} : vram_wval[15:0]
) : (vram_write == 1 ? (
	vram_ptr[0] ? {vram_wval[23:16], vram_wval[23:16]} : vram_wval[23:7]
) : (lcd_cmd ? vram_wval[15:0] : 16'hzzzz));

assign VRAM_LBb = !((vram_write == 2 && !vram_ptr[0]) || vram_write == 1 || copying);
assign VRAM_UBb = !(vram_write == 2 || (vram_write == 1 && vram_ptr[0]) || copying);
assign VRAM_WEb = copying ? !clk : (lcd_cmd && clk ? 1'b0 : (vram_write == 0 || !clk));

assign VRAM_CSb = !(vram_write || copying);
assign VRAM_OEb = vram_write;
assign DISP_CSb = !(lcd_cmd || copying);

reg copying = 0;

always @(posedge clk) begin
	ads_edge <= ADS;
	if(ads_edge && !ADS) begin
		if(addr == 0) begin
			NES_clk = data[0];
			NES_latch = data[1];
		end
		if(addr == 0 && !copying) begin
			vram_ptr <= data[19:0];
		end
		if(addr == 3) begin
			copying <= 1;
			vram_ptr <= 0;
			vram_write <= 0;
			lcd_cmd <= 0;
		end
		if(addr == 4 && !copying) begin
			lcd_cmd <= 1;
			vram_wval <= data;
		end
		if(addr == 5 && !copying) begin
			vram_wval <= data;
			vram_write <= 2;
		end
	end
	
	if(vram_write) begin
		vram_write <= vram_write - 1;
		if(vram_write == 2 || !vram_ptr[0]) vram_ptr <= vram_ptr + 1;
	end
	if(lcd_cmd) lcd_cmd <= 0;
	
	if(copying) begin
		vram_ptr <= vram_ptr + 1;
		if(vram_ptr == 576000-1) begin
			copying <= 0;
		end
	end
end

uart uart(
	.divisor(434),
	.din(data[7:0]),
	.dout(uart_dout),
	.TX(UTX),
	.RX(URX),
	.start(writing && addr == 7),
	.busy(uart_busy),
	.has_byte(uart_has_byte),
	.clr_hb(reading && addr == 7),
	.clk(clk)
);

endmodule

module uart(
    input [15:0] divisor,
    input [7:0] din,

    output reg [7:0] dout,

    output reg TX = 1,
    input RX,

    input start,
    output reg busy,
    output reg has_byte,
    input clr_hb,

    input clk
);

reg [9:0] data_buff;
reg [15:0] div_counter;
reg [3:0] counter;

reg receiving;
reg [7:0] receive_buff;
reg [3:0] receive_counter;
reg [15:0] receive_div_counter;

always @(posedge clk) begin
	  if(clr_hb) begin
			has_byte <= 0;
	  end
	  if(start) begin
			counter <= 4'b1010;
			div_counter <= 0;
			data_buff <= {1'b1, din, 1'b0};
	  end
	  if(counter != 0) begin
			busy <= 1;
			div_counter <= div_counter + 1;
			if(div_counter == divisor) begin
				 div_counter <= 0;
				 counter <= counter - 1;
				 TX <= data_buff[0];
				 data_buff <= {1'b0, data_buff[9:1]};
			end
	  end else begin
			TX <= 1;
			busy <= 0;
	  end

	  if(!receiving && !RX) begin
			receiving <= 1;
			receive_counter <= 4'b1000;
			receive_buff <= 0;
			receive_div_counter <= 0;
	  end
	  if(receiving) begin
			receive_div_counter <= receive_div_counter + 1;
			if(receive_div_counter == divisor) begin
				 receive_div_counter <= 0;
				 receive_counter <= receive_counter - 1;
				 if(receive_counter == 0) begin
					  receiving <= 0;
					  dout <= receive_buff;
					  has_byte <= 1;
				 end else begin
					  receive_buff <= {RX, receive_buff[7:1]};
				 end
			end
	  end
end

endmodule
