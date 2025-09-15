`default_nettype none

module VLIWBadgeCtrl(
	input inclk,
	input porb,
	output caravel_resetb,
	output reg cpu_resetb = 1'b0,
	output xclk,
	
	input LE_HI,
	input LE_LO,
	input OEb,
	input WEb_HI,
	input WEb_LO,
	output reg CPU_INTERRUPT = 0,
	inout [15:0] AD,
	input caravel_gpio,
	
	input RXD,
	output TXD,
	output reg LED_CKI = 0,
	output reg LED_SDI = 0,
	output DAC_clk,
	output DAC_leb,
	output DAC_dat,
	output DAC_csb,
	
	inout [11:0] DISP_D,
	output reg DISP_WRb = 1'b1,
	output reg DISP_RDb = 1'b1,
	output DISP_RESETb,
	output reg DISP_D_Cb = 0,
	output reg DISP_CSb = 1'b1,
	output reg [19:0] VRAM_A = 0,
	output reg VRAM_CSb = 1'b1,
	output reg VRAM_OEb = 1'b1,
	output reg VRAM_WEb = 1'b1,
	
	output ACT_LED,
	output reg SECOND_LED = 0
);

wire clk_0;

`ifdef BENCH
assign clk_0 = inclk;
`else
pll pll_inst(
	.inclk0(inclk),
	.c0(clk_0)
);
`endif

assign ACT_LED = disp_cpy_act || vram_access_step != 0 || disp_cmd_step != 0 || led_xfer_step != 0;

//TODO: clock stretch during SRAM writes
clkdiv #(.DIV(7)) clkdiv(
	.clk(clk_0),
	.en(disp_cpy_act == 0 && vram_access_step == 0 && disp_cmd_step == 0 && led_xfer_step == 0/* && clock_stretch == 0*/),
	.xclk(xclk)
);

reg [30:0] address_latch = 0;
reg memory_iface_ready = 0;

/*wire le_hi_edge;
wire le_lo_edge;
button_debouncer dA(
	.clk(clk_0),
	.btn(LE_HI),
	.debounced(),
	.pedge(le_hi_edge),
	.nedge()
);

button_debouncer dB(
	.clk(clk_0),
	.btn(LE_LO),
	.debounced(),
	.pedge(le_lo_edge),
	.nedge()
);*/

assign caravel_resetb = reset_timeout == 0;
reg [4:0] reset_timeout = 31;
always @(posedge clk_0) begin
	reset_timeout <= porb ? (reset_timeout == 0 ? 0 : reset_timeout - 1) : 15;
	memory_iface_ready <= porb && caravel_resetb ? !caravel_gpio : 1'b0;
	if(LE_HI) address_latch[30:16] <= AD_in_latch[14:0];
	if(LE_LO) address_latch[15:0] <= AD_in_latch;
	if(!porb) begin
		cpu_resetb <= 1'b0;
	end else begin
		if(caravel_gpio == 1'b0) cpu_resetb <= 1'b1;
	end
end

assign DISP_RESETb = memory_iface_ready;

reg [1:0] clock_stretch = 0;
reg [31:0] rng_lfsr = 1;
reg [27:0] led_lfsr = 1;
always @(posedge clk_0) begin
	if(!porb) begin
		led_lfsr <= 1;
		rng_lfsr <= 1;
		SECOND_LED <= 0;
	end else begin
		led_lfsr <= {led_lfsr[26:0], led_lfsr[27] ^ led_lfsr[26] ^ led_lfsr[23] ^ led_lfsr[21]};
		if(LE_HI || !WEb_HI || !WEb_LO) rng_lfsr <= {rng_lfsr[30:0], rng_lfsr[31] ^ rng_lfsr[29] ^ rng_lfsr[25] ^ rng_lfsr[24]};
		if(led_lfsr == 1) SECOND_LED <= !SECOND_LED;
		
		clock_stretch <= clock_stretch ? clock_stretch - 1 : 0;
		if(we_edge && !is_fpga) begin
			clock_stretch <= 1;
		end
	end
end

/*
 * Memory interfaces
 */

//Address decode
wire is_internal_io = address_latch[30:16] == 15'h7FFF;
wire is_fpga = address_latch[23] && !is_internal_io;
wire is_fastram = address_latch[22:0] < 4096 && memory_iface_ready && is_fpga;
wire is_mmio = address_latch[22:0] >= 4096 && address_latch[22:0] < 8192 && memory_iface_ready && is_fpga;
wire is_vram = address_latch[22] && memory_iface_ready && is_fpga;

assign AD = OEb || !is_fpga ? 16'hzzzz : (is_fastram ? fastram_read : (is_vram ? vram_rval : (is_mmio ? mmio_rval : 16'hFFFF)));

reg [15:0] AD_in_latch;
always @(posedge clk_0) AD_in_latch <= AD;

reg web_hi_del;
reg web_lo_del;
always @(posedge clk_0) begin
	web_hi_del <= WEb_HI;
	web_lo_del <= WEb_LO;
end
wire web_stable = (web_hi_del == WEb_HI) && (web_lo_del == WEb_LO);
wire we_cond = !(WEb_HI && WEb_LO) && web_stable;
reg we_del = 1'b1;
always @(posedge clk_0) we_del <= we_cond;
wire we_edge = we_cond && !we_del;

reg [3:0] oeb_del = 3'b111;
always @(posedge clk_0) oeb_del <= {oeb_del[1:0], OEb};
wire oe_edge = oeb_del[2] && oeb_del[1:0] == 0;

wire [15:0] fastram_read;
fastram fastram(
	.address(address_latch[11:0]),
	.clock(clk_0),
	.data(AD_in_latch),
	.wren(we_edge && is_fastram),
	.q(fastram_read),
	.byteena(we_cond ? {!WEb_HI, !WEb_LO} : 2'b11)
);

/*
 * MMIO Reads
 */

reg uart_irupt_enabled = 0;
reg [31:0] led_colorbuff = 0;
reg [6:0] led_xfer_step = 0;
reg [2:0] led_xfer_div = 0;

wire [7:0] uart_dout;
wire uart_busy;
wire uart_has_byte;
reg [15:0] mmio_rval;
always @(*) begin
	if(address_latch[7] == 0) mmio_rval = {8'h00, sid_rval};
	else begin
		case(address_latch[7:0])
			default: mmio_rval = 16'hFFFF;
			8'h80: mmio_rval = {8'h00, uart_dout};
			8'h81: mmio_rval = {10'h00, tmr0_interrupt_enabled, tmr0_flag, uart_irupt_enabled, led_xfer_step != 0, uart_has_byte, uart_busy};
			8'h82: mmio_rval = rng_lfsr[15:0];
			8'h83: mmio_rval = rng_lfsr[31:16];
			8'h85: mmio_rval = {8'h00, tmr0_pre};
			8'h86: mmio_rval = tcapt[15:0];
			8'h87: mmio_rval = tcapt[31:16];
			8'h88: mmio_rval = tmr0_top[15:0];
			8'h89: mmio_rval = tmr0_top[31:16];
		endcase
	end
end

/*
 * Timers
 */

reg [31:0] tmr0;
reg [31:0] tcapt;
reg [7:0] tmr0_pre;
reg [7:0] tmr0_pre_counter;
reg [31:0] tmr0_top;
reg tmr0_flag = 0;
reg tmr0_interrupt_enabled = 0;
 
always @(posedge clk_0) begin
	if(!porb) begin
		tmr0  <= 0;
		tcapt <= 0;
		tmr0_pre <= 8'h80;
		tmr0_pre_counter <= 0;
		tmr0_top <= 32'h00800000;
		tmr0_flag <= 0;
	end else begin
		tmr0_pre_counter <= tmr0_pre_counter + 1;
		if(tmr0_pre_counter >= tmr0_pre) begin
			tmr0_pre_counter <= 0;
			tmr0 <= tmr0 + 1;
			if(tmr0 >= tmr0_top) begin
				tmr0 <= 0;
				tmr0_flag <= 1;
			end
		end
		if(is_mmio && we_edge) begin
			if(address_latch[7:0] == 8'h84) begin
				tcapt <= tmr0;
			end
			if(address_latch[7:0] == 8'h85) begin
				tmr0_pre <= AD_in_latch[7:0];
			end
			if(address_latch[7:0] == 8'h86 || address_latch[7:0] == 8'h88) begin
				tcapt[15:0] <= AD_in_latch;
			end
			if(address_latch[7:0] == 8'h87) begin
				tmr0 <= {AD_in_latch, tcapt[15:0]};
			end
			if(address_latch[7:0] == 8'h89) begin
				tmr0_top <= {AD_in_latch, tcapt[15:0]};
			end
			if(address_latch[7:0] == 8'h81) begin
				if(AD_in_latch[4]) tmr0_flag <= 0;
			end
		end
	end
end
 
/*
 * Addressable LED Interface & interrupt gen
 */

always @(posedge clk_0) begin
	if(!porb) begin
		uart_irupt_enabled <= 0;
		tmr0_interrupt_enabled <= 0;
		CPU_INTERRUPT      <= 0;
		LED_CKI            <= 0;
		LED_SDI            <= 0;
	end else begin
		if(is_mmio && we_edge) begin
			if(address_latch[7:0] == 8'h81) begin
				uart_irupt_enabled <= AD_in_latch[3];
				tmr0_interrupt_enabled <= AD_in_latch[5];
			end
			if(address_latch[7:0] == 8'h90) led_colorbuff[15:0] <= AD_in_latch;
			if(address_latch[7:0] == 8'h91) begin
				led_colorbuff[31:16] <= AD_in_latch;
				led_xfer_step <= 7'h41;
				led_xfer_div <= 0;
			end
		end
		CPU_INTERRUPT <= (uart_irupt_enabled && uart_has_byte) || (tmr0_interrupt_enabled && tmr0_flag);
	end
	
	if(led_xfer_step != 0) begin
		led_xfer_div <= led_xfer_div + 1;
		if(led_xfer_div == 0) begin
			led_xfer_step <= led_xfer_step - 1;
			if(!led_xfer_step[0]) begin
				LED_CKI <= 1;
			end else begin
				LED_CKI <= 0;
				LED_SDI <= led_colorbuff[31];
				led_colorbuff <= {led_colorbuff[30:0], 1'bx};
			end
		end
	end
end

/*
 * LCD Display Interface
 */

`define DISP_ADDRCOUNT 767999

reg disp_clkdiv = 0;
reg [2:0] disp_cmd_step = 0;
reg [1:0] disp_dat_step = 0;
reg [11:0] disp_d_obuff = 0;
reg [31:0] vram_color_buff = 0;
reg [23:0] vram_rcol = 0;
reg [3:0] vram_access_step = 0;
reg vram_access_type = 0;

wire [8:0] mul_factor = vram_color_buff[31:24] + 1;
wire [8:0] inv_mul_factor = 9'h100 - mul_factor;

wire [15:0] buff_blue_scaled = vram_color_buff[7:0] * mul_factor;
wire [15:0] vram_blue_scaled = vram_rcol[7:0] * inv_mul_factor;
wire [16:0] blue_scaled_sum_raw = buff_blue_scaled + vram_blue_scaled;
wire [7:0] blue_final = blue_scaled_sum_raw >> 8;

wire [15:0] buff_green_scaled = vram_color_buff[15:8] * mul_factor;
wire [15:0] vram_green_scaled = vram_rcol[15:8] * inv_mul_factor;
wire [16:0] green_scaled_sum_raw = buff_green_scaled + vram_green_scaled;
wire [7:0] green_final = green_scaled_sum_raw >> 8;

wire [15:0] buff_red_scaled = vram_color_buff[23:16] * mul_factor;
wire [15:0] vram_red_scaled = vram_rcol[23:16] * inv_mul_factor;
wire [16:0] red_scaled_sum_raw = buff_red_scaled + vram_red_scaled;
wire [7:0] red_final = red_scaled_sum_raw >> 8;

wire [23:0] final_mixed_color = {red_final, green_final, blue_final};

wire [15:0] vram_rval = address_latch[0] ? {8'hFF, vram_rcol[23:16]} : vram_rcol[15:0];

wire cpy_address_target = VRAM_A >= `DISP_ADDRCOUNT;

assign DISP_D = VRAM_OEb && DISP_RDb ? disp_d_obuff : 12'hzzz;

reg disp_cpy_act = 0;
always @(posedge clk_0) begin
	if(!porb) begin
		DISP_CSb       <= 1'b1;
		DISP_RDb       <= 1'b1;
		DISP_WRb       <= 1'b1;
		disp_cmd_step  <= 0;
		disp_clkdiv    <= 0;
		disp_dat_step  <= 0;
		VRAM_A         <= `DISP_ADDRCOUNT;
		VRAM_CSb       <= 1'b1;
		VRAM_OEb       <= 1'b1;
		VRAM_WEb       <= 1'b1;
		vram_access_step <= 0;
		disp_cpy_act   <= 0;
	end else begin
		disp_clkdiv <= disp_clkdiv + 1;
		if(vram_access_step) begin
			if(disp_clkdiv == 0) begin
				vram_access_step <= vram_access_step + 1;
				case(vram_access_step)
					1: begin
						VRAM_CSb <= 1'b0;
						VRAM_OEb <= 1'b0;
						VRAM_A <= {address_latch[19:1], 1'b0};
					end
					2: begin
						vram_rcol[23:12] <= DISP_D;
						VRAM_A <= VRAM_A | 1;
					end
					3: begin
						vram_rcol[11:0] <= DISP_D;
						if(vram_access_type == 0) begin
							VRAM_CSb <= 1'b1;
							vram_access_step <= 0;
						end
						VRAM_OEb <= 1'b1;
					end
					4: begin
						VRAM_CSb <= 1'b0;
						VRAM_A <= {address_latch[19:1], 1'b0};
						disp_d_obuff <= final_mixed_color[23:12];
					end
					5: begin
						VRAM_WEb <= 1'b0;
					end
					6: begin
						VRAM_WEb <= 1'b1;
					end
					7: begin
						VRAM_A <= VRAM_A | 1;
						disp_d_obuff <= final_mixed_color[11:0];
					end
					8: begin
						VRAM_WEb <= 1'b0;
					end
					9: begin
						VRAM_WEb <= 1'b1;
						//VRAM_CSb <= 1'b1;
						vram_access_step <= 0;
					end
				endcase
			end
		end else if(disp_clkdiv == 0) begin
			DISP_WRb <= 1'b1;
			if(disp_cmd_step != 0) begin
				disp_cmd_step <= disp_cmd_step - 1;
				DISP_CSb      <= disp_cmd_step == 1;
				DISP_WRb      <= disp_cmd_step != 3;
			end
			if(disp_cpy_act) begin
				disp_dat_step <= disp_dat_step + 1;
				case(disp_dat_step)
					1: begin
						DISP_WRb <= 0;
					end
					2: begin
						DISP_WRb <= 1;
					end
					3: begin
						VRAM_A <= VRAM_A + 1;
						disp_dat_step <= 1;
						if(cpy_address_target) disp_cpy_act <= 1'b0;
					end
				endcase
			end
			if(disp_cmd_step == 0 && !disp_cpy_act) begin
				DISP_CSb <= 1'b1;
				VRAM_CSb <= 1'b1;
				VRAM_OEb <= 1'b1;
				VRAM_WEb <= 1'b1;
			end
		end
		if(we_edge && is_mmio) begin
			if(address_latch[7:1] == 7'h70) begin
				//LCD Command transfer
				disp_d_obuff  <= {4'h0, AD_in_latch[7:0]};
				DISP_D_Cb     <= address_latch[0];
				disp_cmd_step <= 3'b100;
				disp_clkdiv   <= 1'b1;
			end
			if(address_latch[7:0] == 8'hE4) begin
				//LCD Buffer copy
				DISP_D_Cb <= 1'b1;
				DISP_CSb <= 1'b0;
				VRAM_OEb <= 1'b0;
				VRAM_CSb <= 1'b0;
				VRAM_A <= 0;
				disp_cpy_act <= 1'b1;
				disp_dat_step <= 1;
			end
		end
		if(we_edge && is_vram) begin
			if(address_latch[0]) vram_color_buff[31:16] <= AD_in_latch;
			else vram_color_buff[15:0] <= AD_in_latch;
			if(address_latch[0]) begin
				vram_access_step <= AD_in_latch[15:8] == 8'hFF ? 4 : 1;
				vram_access_type <= 1;
				disp_clkdiv <= 1'b1;
			end
		end
		if(oe_edge && is_vram && !address_latch[0]) begin
			vram_access_step <= 1;
			vram_access_type <= 0;
			disp_clkdiv <= 1'b1;
		end
	end
end

uart uart(
	.TX(TXD),
	.RX(RXD),
	
`ifdef BENCH
	.divisor(2),
`else
	//.divisor(1307), //150MHz
	//.divisor(1094), //125MHz
	.divisor(863), //100MHz
	//.divisor(470), //54MHz
`endif
	.din(AD_in_latch[7:0]),
	.dout(uart_dout),
	
	.start(is_mmio && we_edge && address_latch[7:0] == 8'h80),
	.clr_hb(is_mmio && !OEb && address_latch[7:0] == 8'h80),
	.busy(uart_busy),
	.has_byte(uart_has_byte),
	
	.clk(clk_0),
	.rst(!porb)
);

/*tt_um_rejunity_sn76489 psg(
	.clk(clk_0),
	.rst_n(porb),
	.data(AD_in_latch[7:0]),
	.web(!(we_edge && is_mmio && address_latch[7:0] == 8'hF0)),
	.DAC_clk(DAC_clk),
	.DAC_leb(DAC_leb),
	.DAC_dat(DAC_dat),
	.DAC_csb(DAC_csb)
);*/

wire [7:0] sid_rval;
sid_top sid(
	.clk(inclk),
	.rst_n(porb),
	.WEb(!(we_cond && is_mmio && address_latch[7] == 0)),
	.bus_in(AD_in_latch[7:0]),
	.bus_out(sid_rval),
	.reg_addr(address_latch[4:0]),
	.DAC_clk(DAC_clk),
	.DAC_leb(DAC_leb),
	.DAC_dat(DAC_dat),
	.DAC_csb(DAC_csb)
);

endmodule

module button_debouncer(
	input clk,
	input btn,
	output debounced,
	output pedge,
	output nedge
);

localparam sfr_width = 2;

reg [sfr_width-1:0] sfr = 2'h3;
wire sfr_out = sfr[sfr_width-1];
wire load = btn == sfr_out;
reg prev_d = 0;
always @(posedge clk) begin
	if(load) sfr <= {sfr_width{sfr_out}};
	else sfr <= {sfr[sfr_width-2:0], btn};
	prev_d <= debounced;
end

assign debounced = sfr_out;
assign pedge = !prev_d && debounced;
assign nedge = prev_d && !debounced;

endmodule
