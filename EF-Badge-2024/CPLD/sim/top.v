`define DIR_TO_CPLD 0
`define DIR_TO_CPU 1
`define UART

module top(
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
wire timer_exp = timer == 20000000;
assign CPU_int = inten && (uart_has_byte || timer_exp);

`ifdef UART
wire b0 = uart_has_byte;
wire b1 = uart_busy;
`else
wire b0 = 1'b0;
wire b1 = 1'b0;
`endif
assign bdir = reading ? `DIR_TO_CPU : `DIR_TO_CPLD;
assign data = reading ? (addr[0] ? {16'h0, uart_dout} : {vram_ptr, copying, NES_data, b1, b0}) : 24'hzzzzzz;

`ifdef UART
wire uart_busy;
wire uart_has_byte;
wire [7:0] uart_dout;
uart uart(
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
`else
wire [7:0] uart_dout = 8'hFF;
assign UTX = 1'b1;
`endif

reg [2:0] ads_latency;
reg ads_edge;
reg [23:0] vram_wval = 0;
reg [19:0] vram_ptr = 0;
assign VRAM_addr = vram_ptr;
reg [3:0] vram_write = 0;
wire [1:0] vram_write_step = vram_write[3:2];
reg [1:0] lcd_cmd = 0;
wire writing = ads_edge && !ads_latency[2] && WR;
wire reading = !MIO && !WR && !ads_edge && (addr == 6 || addr == 7);
reg copying = 0;
reg [1:0] copy_step = 0;
reg inten = 0;
reg [24:0] timer = 0;

//TODO: check if 4'hz instead of 4'h0 uses less LUs
assign VRAM_dat = vram_write ? (
	vram_ptr[0] ? {4'h0, vram_wval[11:0]} : {4'h0, vram_wval[23:12]}) : (lcd_cmd ? vram_wval[15:0] : 16'hzzzz);
assign VRAM_UBb = 1'b0;
assign VRAM_LBb = 1'b0;

assign VRAM_WEb = copying || (lcd_cmd ? vram_wval[23] : (vram_write_step == 0 || vram_write[1:0] != 2));

assign VRAM_CSb = !(copying || vram_write_step);
assign VRAM_OEb = !((VRAM_WEb && !VRAM_CSb && !copying) || lcd_cmd == 2 || copying) || vram_write;
assign DISP_CSb = !(lcd_cmd || (copying && copy_step == 2));

always @(posedge clk) begin
	ads_latency <= ads_latency[2] != MIO ? {ads_latency[1:0], MIO} : {3{ads_latency[2]}};
	ads_edge <= ads_latency[2];
	if(!timer_exp) timer <= timer + 1;
	if(writing) begin
		if(addr == 0) begin
			if(!data[4]) begin
				NES_clk <= data[0];
				NES_latch <= data[1];
				inten <= data[2] ? data[3] : inten;
			end
			if(data[4]) timer <= 0;
		end
		if(addr == 1 && !copying) begin
			vram_ptr <= {data[18:0], 1'b0};
		end
		if(addr == 3) begin
			copying <= 1;
			vram_ptr <= 0;
			vram_write <= 0;
			lcd_cmd <= 0;
			copy_step <= 0;
		end
		if(addr == 4 && !copying) begin
			lcd_cmd <= 3;
			vram_wval <= data;
		end
		if(addr == 5 && !copying) begin
			vram_wval <= data;
			vram_write <= 11;
		end
	end
	
	if(vram_write) begin
		vram_write <= vram_write - 1;
		if(vram_write == 9 || vram_write == 3) begin
			vram_ptr <= vram_ptr + 1;
		end
	end
	if(lcd_cmd) lcd_cmd <= lcd_cmd - 1;
		
	if(copying) begin
		copy_step <= copy_step + 1;
		if(copy_step == 3) begin
			vram_ptr <= vram_ptr + 1;
			if(vram_ptr == 768000-1) begin
				copying <= 0;
			end
		end
	end
end

endmodule

module uart(
	input [7:0] din,
	output reg [7:0] dout = 0,
	
	output reg TX = 1,
	input RX,
	
	input start,
	output reg busy = 0,
	output reg has_byte = 0,
	input clr_hb,
	
	input clk
);

reg [9:0] data_buff;
reg [9:0] div_counter;
reg [3:0] counter;

reg receiving;
reg [7:0] receive_buff;
reg [3:0] receive_counter;
reg [9:0] receive_div_counter;

always @(posedge clk) begin
	if(clr_hb) has_byte <= 0;
	if(start) begin
		counter <= 4'b1010;
		div_counter <= 0;
		data_buff <= {1'b1, din, 1'b0};
	end
	if(counter != 0) begin
		busy <= 1;
		div_counter <= div_counter + 1;
		if(div_counter == 693) begin
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
		if(receive_div_counter == 693) begin
			receive_div_counter <= 0;
			receive_counter <= receive_counter - 1;
			if(receive_counter != 0) receive_buff <= {RX, receive_buff[7:1]};
			else begin
				receiving <= 0;
				dout <= receive_buff;
				has_byte <= 1;
			end
		end
	end
end

endmodule
