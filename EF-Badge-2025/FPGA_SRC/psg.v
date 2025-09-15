/*
 * This is the interface to the external DAC (DAC7611)
 *
 * Outputs LE, CLK and DATA signals for the SPI link
*/

`default_nettype none

module spi_dac_i(
	input [11:0] sample_in,
	
	input clk,
	input div_spike,
	input rst,
	
	output reg spi_leb = 1'b1,
	output reg spi_clk = 0,
	output reg spi_dat = 0,
	output reg spi_csb = 1'b1,
	input sample_ready
);

reg [15:0] spi_dat_buff = 0;
reg [5:0] counter = 0;
reg [1:0] clkdiv = 0;

always @(posedge clk) begin
	if(rst) begin
		spi_leb <= 1;
		spi_csb <= 1;
		spi_clk <= 0;
		spi_dat <= 0;
		counter <= 0;
		spi_dat_buff <= 0;
	end else if(div_spike) begin
		clkdiv <= clkdiv + 1;
		if(clkdiv == 0) begin
			spi_leb <= 1;
			if(counter != 35) counter <= counter + 1;
			if(counter == 33) begin
				//Load next sample & reset counter
				spi_clk <= 0;
				//Pulse LEb
				spi_leb <= 0;
			end else if(counter == 34) begin
			end else if(counter == 35) begin
				spi_leb <= 1;
				spi_csb <= 1;
				if(sample_ready) counter <= 0;
				spi_dat_buff <= {4'b0111, sample_in};
			end else begin
				if(counter[0]) begin
					//Clock in current bit
					spi_clk <= 1;
				end else begin
					//Shift out next bit
					spi_dat <= spi_dat_buff[15];
					spi_dat_buff <= {spi_dat_buff[14:0], 1'bx};
					spi_clk <= 0;
					spi_csb <= 0;
				end
			end
		end
	end
end

endmodule

/*
 * Implements a single SID tone + envelope generator
 * Takes config register values as inputs, outputs sample, as well as sync + ring triggers for the next channel
 */

`define ATTACK 'b01
`define DECAY_SUSTAIN 'b10
`define RELEASE 'b11

module SID_channels(
	input [15:0] freq1,
	input [15:0] freq2,
	input [15:0] freq3,
	input [11:0] pw1,
	input [11:0] pw2,
	input [11:0] pw3,
	input [7:0] ctrl_reg1,
	input [7:0] ctrl_reg2,
	input [7:0] ctrl_reg3,
	input [7:0] atk_dec1,
	input [7:0] atk_dec2,
	input [7:0] atk_dec3,
	input [7:0] sus_rel1,
	input [7:0] sus_rel2,
	input [7:0] sus_rel3,
	
	input clk,
	input div_spike,
	input rst,
	
	output [11:0] sample1,
	output [11:0] sample2,
	output [11:0] sample3,
	
	output [7:0] ch3_env
);

reg [11:0] samples [2:0];
assign sample1 = samples[0];
assign sample2 = samples[1];
assign sample3 = samples[2];

reg ring_outs [2:0];
reg sync_outs [2:0];

reg [15:0] curr_freq;
reg [11:0] curr_pw;
reg [7:0] curr_ctrl_reg;
reg [7:0] curr_atk_dec;
reg [7:0] curr_sus_rel;
reg curr_ring_in;
reg curr_sync_in;
always @(*) begin
	case(curr_channel)
		0: begin
			curr_freq = freq1;
			curr_pw = pw1;
			curr_ctrl_reg = ctrl_reg1;
			curr_atk_dec = atk_dec1;
			curr_sus_rel = sus_rel1;
			curr_ring_in = ring_outs[2];
			curr_sync_in = sync_outs[2];
		end
		1: begin
			curr_freq = freq2;
			curr_pw = pw2;
			curr_ctrl_reg = ctrl_reg2;
			curr_atk_dec = atk_dec2;
			curr_sus_rel = sus_rel2;
			curr_ring_in = ring_outs[0];
			curr_sync_in = sync_outs[0];
		end
		2: begin
			curr_freq = freq3;
			curr_pw = pw3;
			curr_ctrl_reg = ctrl_reg3;
			curr_atk_dec = atk_dec3;
			curr_sus_rel = sus_rel3;
			curr_ring_in = ring_outs[1];
			curr_sync_in = sync_outs[1];
		end
		3: begin
			curr_freq = 0;
			curr_pw = 0;
			curr_ctrl_reg = 0;
			curr_atk_dec = 0;
			curr_sus_rel = 0;
			curr_ring_in = 0;
			curr_sync_in = 0;
		end
	endcase
end

/*
 * Extract individual config options from the registers
*/
wire noise    = curr_ctrl_reg[7];
wire square   = curr_ctrl_reg[6];
wire sawtooth = curr_ctrl_reg[5];
wire triangle = curr_ctrl_reg[4];
wire test     = curr_ctrl_reg[3];
wire ringm    = curr_ctrl_reg[2];
wire sync     = curr_ctrl_reg[1];
wire gate     = curr_ctrl_reg[0];

wire [3:0] attack  = curr_atk_dec[7:4];
wire [3:0] decay   = curr_atk_dec[3:0];
wire [3:0] sustain = curr_sus_rel[7:4];
wire [3:0] releas  = curr_sus_rel[3:0];

/*
 * Tone generator registers
 * lfsr is for random noise
 * accum is the Accumulator, used to generate the periodic signals
 * sample_buff simply buffers the current sample
*/
reg [22:0] lfsr [2:0];
reg [23:0] accum [2:0];

//Compute next lfsr state, and increment accum according to the set frequency
wire lfsr_next = (lfsr[curr_channel][22] ^ lfsr[curr_channel][17]) | test;
wire [23:0] accum_next = accum[curr_channel] + {8'h00, curr_freq};

/*
 * Calculate samples for all tone types
 * Noise is taken from the lfsr value
 * Pulse is high if the Accumulator surpases the configured pulse-width
 * Saw simply is a couple bits of the accumulator value, counting up until wrap-around
 * Triangle is generated similarly to saw, but conditionally inverted using an XOR op if the most-significant bit of accum is 1
 * Lastly, the ring-mod trigger from the previous channel is also applied to invert the triangle sample, through another XOR
*/
wire [7:0] noise_sample = {lfsr[curr_channel][20], lfsr[curr_channel][18], lfsr[curr_channel][14], lfsr[curr_channel][11], lfsr[curr_channel][9], lfsr[curr_channel][5], lfsr[curr_channel][2], lfsr[curr_channel][0]};
wire pulse_sample = accum[curr_channel][23:12] >= curr_pw;
wire [11:0] saw_sample = accum[curr_channel][23:12];
wire [11:0] triangle_sample = {accum[curr_channel][22:12], 1'b0} ^ {12{accum[curr_channel][23]}} ^ {12{ringm && curr_ring_in}};

/*
 * Compute final sample by mixing all the enabled tones using ANDs
*/
wire [11:0] osc_sample = 
	(square ? {12{pulse_sample}} : 12'hFFF) &
	(sawtooth ? saw_sample : 12'hFFF) &
	(triangle ? triangle_sample : 12'hFFF) &
	(noise ? {noise_sample, 4'b0} : 12'hFFF);
	
/*
 * Envelope generator regs and signals
*/
reg [7:0] env_vol [2:0];
reg [4:0] exp_counter [2:0];
reg [14:0] env_counter [2:0];
reg [1:0] adsr_state [2:0];
assign ch3_env = env_vol[2];

wire [7:0] env_vol_curr = env_vol[curr_channel];

reg [4:0] exp_periods [2:0];
wire [4:0] exp_period = exp_periods[curr_channel];

//For the non-linear curves
wire [3:0] table_ptr = adsr_state[curr_channel] == `ATTACK ? attack : (adsr_state[curr_channel] == `DECAY_SUSTAIN ? decay : releas);
reg [14:0] adsr_table;
always @(*) begin
	case(table_ptr)
	0:  adsr_table = 8;
	1:  adsr_table = 31;
	2:  adsr_table = 62;
	3:  adsr_table = 94;
	4:  adsr_table = 148;
	5:  adsr_table = 219;
	6:  adsr_table = 266;
	7:  adsr_table = 312;
	8:  adsr_table = 391;
	9:  adsr_table = 976;
	10: adsr_table = 1953;
	11: adsr_table = 3125;
	12: adsr_table = 3906;
	13: adsr_table = 11719;
	14: adsr_table = 19531;
	15: adsr_table = 31250;
	endcase
end

//Sample with the envelope applied
wire [19:0] mul_sample = osc_sample * env_vol[curr_channel]; 

reg [2:0] clk_div;
wire [1:0] curr_channel = clk_div[2:1];

wire env_top = env_counter[curr_channel] == adsr_table;

always @(posedge clk) begin
	if(rst) begin
		lfsr[0]        <= 23'h7fffff;
		lfsr[1]        <= 23'h7fffff;
		lfsr[2]        <= 23'h7fffff;
		accum[0]       <= 24'h555555;
		accum[1]       <= 24'h555555;
		accum[2]       <= 24'h555555;
		adsr_state[0]  <= `RELEASE;
		adsr_state[1]  <= `RELEASE;
		adsr_state[2]  <= `RELEASE;
		exp_counter[0] <= 0;
		exp_counter[1] <= 0;
		exp_counter[2] <= 0;
		env_counter[0] <= 0;
		env_counter[1] <= 0;
		env_counter[2] <= 0;
		env_vol[0]     <= 0;
		env_vol[1]     <= 0;
		env_vol[2]     <= 0;
		ring_outs[0]   <= 0;
		ring_outs[1]   <= 0;
		ring_outs[2]   <= 0;
		sync_outs[0]   <= 0;
		sync_outs[1]   <= 0;
		sync_outs[2]   <= 0;
		samples[0]     <= 0;
		samples[1]     <= 0;
		samples[2]     <= 0;
		clk_div        <= 3'h0;
		exp_periods[0] <= 5'h01;
		exp_periods[1] <= 5'h01;
		exp_periods[2] <= 5'h01;
	end else if(div_spike) begin
		clk_div <= clk_div + 1;
		if(curr_channel != 3 && clk_div[0] == 1'b0) begin
			sync_outs[curr_channel] <= !accum[curr_channel][23] && accum_next[23];
			ring_outs[curr_channel] <= accum[curr_channel][23];
			
			/*
			* Accumulator + LFSR
			*/
			samples[curr_channel] <= mul_sample[19:8];
			accum[curr_channel]  <= (sync && curr_sync_in) || test ? 0 : accum_next;
			if(!test && !accum[curr_channel][19] && accum_next[19]) begin
				lfsr[curr_channel][22:1] <= lfsr[curr_channel][21:0];
				lfsr[curr_channel][0] <= lfsr_next;
			end
			/*
			* Envelope update
			*/
			exp_counter[curr_channel] <= exp_counter[curr_channel] == exp_period ? 0 : exp_counter[curr_channel] + 1;
			if(exp_counter[curr_channel] == 0 || adsr_state[curr_channel] == `ATTACK) begin
				env_counter[curr_channel] <= env_counter[curr_channel] + 1;
			end

			if(env_top) env_counter[curr_channel] <= 0;
			if(!gate) adsr_state[curr_channel] <= `RELEASE;
			
			case(adsr_state[curr_channel])
				`ATTACK: begin
					if(env_top) env_vol[curr_channel] <= env_vol[curr_channel] + 1;
					if(env_vol[curr_channel] == 255) adsr_state[curr_channel] <= `DECAY_SUSTAIN;
				end
				
				`DECAY_SUSTAIN: begin
					if(env_top && env_vol[curr_channel] != {sustain, sustain}) env_vol[curr_channel] <= env_vol[curr_channel] - 1;
				end
				
				`RELEASE: begin
					if(env_top && env_vol[curr_channel] != 0) env_vol[curr_channel] <= env_vol[curr_channel] - 1;
					
					if(gate) begin
						adsr_state[curr_channel] <= `ATTACK;
					end
				end
			endcase
		end else if(curr_channel != 3 && clk_div[0] == 1'b1) begin
			case(env_vol[curr_channel])
				8'hFF: exp_periods[curr_channel] <= 5'h01;
				8'h5D: exp_periods[curr_channel] <= 5'h02;
				8'h36: exp_periods[curr_channel] <= 5'h04;
				8'h1A: exp_periods[curr_channel] <= 5'h08;
				8'h0E: exp_periods[curr_channel] <= 5'h10;
				8'h06: exp_periods[curr_channel] <= 5'h1E;
				8'h00: exp_periods[curr_channel] <= 5'h01;
				default: exp_periods[curr_channel] <= exp_periods[curr_channel];
			endcase
		end
	end
end

endmodule

/*
 * Implements the SID filters, but using purely digital logic
 * Takes in the sample of each voice, and the values of the config registers
 * Only has one output: the mixed and (possibly) filtered sample
*/

module SID_filter(
	output [14:0] sample_out,
	
	input [11:0] sample_1,
	input [11:0] sample_2,
	input [11:0] sample_3,
	input [10:0] reg_fc,
	input [7:0] res_filt,
	input [7:0] mode_vol,

	input clk,
	input div_spike,
	input rst,
	
	output sample_ready
);

wire [16:0] cutoff_lut = {reg_fc, 6'h00};

reg [10:0] res_lut;
always @(*) begin
	case(res_filt[7:4])
		0: res_lut = 11'h5a8;
		1: res_lut = 11'h52b;
		2: res_lut = 11'h4c2;
		3: res_lut = 11'h468;
		4: res_lut = 11'h41b;
		5: res_lut = 11'h3d8;
		6: res_lut = 11'h39d;
		7: res_lut = 11'h368;
		8: res_lut = 11'h339;
		9: res_lut = 11'h30f;
		10: res_lut = 11'h2e9;
		11: res_lut = 11'h2c6;
		12: res_lut = 11'h2a7;
		13: res_lut = 11'h28a;
		14: res_lut = 11'h270;
		15: res_lut = 11'h257;
	endcase
end

//Extract options from config registers
wire filt_1 = res_filt[0];
wire filt_2 = res_filt[1];
wire filt_3 = res_filt[2];

wire three_off = mode_vol[7];
wire hp = mode_vol[6];
wire bp = mode_vol[5];
wire lp = mode_vol[4];
wire [3:0] vol = mode_vol[3:0];

//Sample buffer
reg [14:0] sample_buff;

//Sample with volume setting applied
assign sample_out = sample_buff;

//Sum of all non-filtered samples
//wire [15:0] out_raw = (filt_1 ? 0 : sample_1) + (filt_2 ? 0 : sample_2) + (filt_3 || three_off ? 0 : sample_3) | 32768;

//Sum of all samples selected for filtering - input to the filters
wire [14:0] filt_in_add = (filt_1 ? {3'b000, sample_1} : 15'h0000) + (filt_2 ? {3'b000, sample_2} : 15'h0000) + (filt_3 ? {3'b000, sample_3} : 15'h0000);
wire [15:0] filt_in = {filt_in_add, 1'b0};

//Store state of the filters using 32-bit signed numbers
reg signed [31:0] high;
reg signed [31:0] band;
reg signed [31:0] low;

reg [2:0] filter_step;

/*
 * Here is where the new filter values are computed. This is using fixed-point arithmatic,
 * since that is pretty much the best that can be done here
*/
wire signed [31:0] temp1 = (filter_step == 0 ? {6'h00, res_lut} : cutoff_lut) * (filter_step == 2 ? high : band);
wire signed [31:0] temp2 = temp1 >>> 20;
wire signed [31:0] band_low_next = (filter_step == 2 ? band : low) - temp2;

wire signed [31:0] temp4 = temp1 >>> 10;
wire signed [31:0] high_next = temp4 - low - {16'h0000, filt_in};

reg signed [31:0] sample_filtered;
wire signed [31:0] sample_filtered_next = sample_filtered + (filter_step == 1 ? high : (filter_step == 2 ? low : band));
wire signed [31:0] sample_filtered_adj = sample_filtered >>> 1;

assign sample_ready = filter_step == 0;
wire [14:0] sample_buff_next = sample_buff + (filter_step == 1 ? sample_1 : (filter_step == 2 ? sample_2 : (filter_step == 7 ? sample_filtered_adj : sample_3)));

always @(posedge clk) begin
	if(rst) begin
		high        <= 0;
		band        <= 0;
		low         <= 0;
		sample_buff <= 0;
		filter_step <= 0;
	end else if(div_spike) begin
		filter_step <= filter_step + 1;
		case(filter_step)
			0: begin
				high <= high_next;
				sample_filtered <= 0;
				sample_buff <= 16384;
			end
			1: begin
				low <= band_low_next;
				if(hp) sample_filtered <= sample_filtered_next;
				if(!filt_1) sample_buff <= sample_buff_next;
			end
			2: begin
				band <= band_low_next;
				if(lp) sample_filtered <= sample_filtered_next;
				if(!filt_2) sample_buff <= sample_buff_next;
			end
			3: begin
				if(bp) sample_filtered <= sample_filtered_next;
				if(!filt_3 && !three_off) sample_buff <= sample_buff_next;
			end
			4: begin
			end
			5: begin
			end
			6: begin
			end
			7: begin
				sample_buff <= sample_buff_next;
			end
		endcase
	end
end

endmodule

`default_nettype none

module sid_top(
	input WEb,
	input [4:0] reg_addr,
   output DAC_clk,
   output DAC_leb,
   output DAC_dat,
   output DAC_csb,
	input [7:0] bus_in,
	output [7:0] bus_out,
	
	input clk,
	input rst_n
);

reg [7:0] read_res;
always @(*) begin
	case(reg_addr[4:0])
		default: read_res = 8'h00;
		0: read_res = freq_1[7:0];
		1: read_res = freq_1[15:8];
		2: read_res = pw_1[7:0];
		3: read_res = {4'h0, pw_1[11:8]};
		4: read_res = ctrl_1;
		5: read_res = atk_dec_1;
		6: read_res = sus_rel_1;
		
		7: read_res = freq_2[7:0];
		8: read_res = freq_2[15:8];
		9: read_res = pw_2[7:0];
		10: read_res = {4'h0, pw_2[11:8]};
		11: read_res = ctrl_2;
		12: read_res = atk_dec_2;
		13: read_res = sus_rel_2;
		
		14: read_res = freq_3[7:0];
		15: read_res = freq_3[15:8];
		16: read_res = pw_3[7:0];
		17: read_res = {4'h0, pw_3[11:8]};
		18: read_res = ctrl_3;
		19: read_res = atk_dec_3;
		20: read_res = sus_rel_3;
		
		21: read_res = {5'h00, fc[2:0]};
		22: read_res = fc[10:3];
		23: read_res = res_filt;
		24: read_res = mode_vol;
		27: read_res = sample_1_3[11:4];
		28: read_res = ch3_1_env;
	endcase
end
assign bus_out = read_res;

/*
 * SID REGISTERS
 */
//Channel 1 config
reg [15:0] freq_1;
reg [11:0] pw_1;
reg [7:0]  ctrl_1;
reg [7:0]  atk_dec_1;
reg [7:0]  sus_rel_1;

//Channel 2 config
reg [15:0] freq_2;
reg [11:0] pw_2;
reg [7:0]  ctrl_2;
reg [7:0]  atk_dec_2;
reg [7:0]  sus_rel_2;

//Channel 3 config
reg [15:0] freq_3;
reg [11:0] pw_3;
reg [7:0]  ctrl_3;
reg [7:0]  atk_dec_3;
reg [7:0]  sus_rel_3;

//Filters config
reg [10:0] fc;
reg [7:0]  res_filt;
reg [7:0]  mode_vol;

/*
 * Channel sample outputs
 */
wire [11:0] sample_1_1;
wire [11:0] sample_1_2;
wire [11:0] sample_1_3;
wire [7:0] ch3_1_env;

always @(posedge clk) begin
    if(!rst_n) begin
        freq_1    <= 0;
        pw_1      <= 0;
        ctrl_1    <= 0;
        atk_dec_1 <= 0;
        sus_rel_1 <= 0;
        
        freq_2    <= 0;
        pw_2      <= 0;
        ctrl_2    <= 0;
        atk_dec_2 <= 0;
        sus_rel_2 <= 0;
        
        freq_3    <= 0;
        pw_3      <= 0;
        ctrl_3    <= 0;
        atk_dec_3 <= 0;
        sus_rel_3 <= 0;
        
        fc        <= 0;
        res_filt  <= 0;
        mode_vol  <= 0;
    end else begin
		if(!WEb) begin
				 /*
				 * SID Register Write
				 */
				 case(reg_addr[4:0])
					  0:  freq_1[7:0]  <= bus_in;
					  1:  freq_1[15:8] <= bus_in;
					  2:  pw_1[7:0]    <= bus_in;
					  3:  pw_1[11:8]   <= bus_in[3:0];
					  4:  ctrl_1       <= bus_in;
					  5:  atk_dec_1    <= bus_in;
					  6:  sus_rel_1    <= bus_in;

					  7:  freq_2[7:0]  <= bus_in;
					  8:  freq_2[15:8] <= bus_in;
					  9:  pw_2[7:0]    <= bus_in;
					  10: pw_2[11:8]   <= bus_in[3:0];
					  11: ctrl_2       <= bus_in;
					  12: atk_dec_2    <= bus_in;
					  13: sus_rel_2    <= bus_in;

					  14: freq_3[7:0]  <= bus_in;
					  15: freq_3[15:8] <= bus_in;
					  16: pw_3[7:0]    <= bus_in;
					  17: pw_3[11:8]   <= bus_in[3:0];
					  18: ctrl_3       <= bus_in;
					  19: atk_dec_3    <= bus_in;
					  20: sus_rel_3    <= bus_in;

					  21: fc[2:0]      <= bus_in[2:0];
					  22: fc[10:3]     <= bus_in;
					  23: res_filt     <= bus_in;
					  24: mode_vol     <= bus_in;
				 endcase
		end
    end
end

reg [2:0] div_counter = 0;
always @(posedge clk) div_counter <= div_counter == 5 ? 0 : div_counter + 1;
wire div_spike = div_counter == 0;

/*
 * Module instantiations for channels
*/

SID_channels channels_0(
    .freq1(freq_1),
    .freq2(freq_2),
    .freq3(freq_3),
    .pw1(pw_1),
    .pw2(pw_2),
    .pw3(pw_3),
    .ctrl_reg1(ctrl_1),
    .ctrl_reg2(ctrl_2),
    .ctrl_reg3(ctrl_3),
    .atk_dec1(atk_dec_1),
    .atk_dec2(atk_dec_2),
    .atk_dec3(atk_dec_3),
    .sus_rel1(sus_rel_1),
    .sus_rel2(sus_rel_2),
    .sus_rel3(sus_rel_3),
    
    .clk(clk),
	 .div_spike(div_spike),
    .rst(~rst_n),
    .sample1(sample_1_1),
    .sample2(sample_1_2),
    .sample3(sample_1_3),
    
    .ch3_env(ch3_1_env)
);

wire [14:0] full_sample_1;
wire sample_ready;
SID_filter filters_0(
    .sample_out(full_sample_1),
    .sample_1(sample_1_1),
    .sample_2(sample_1_2),
    .sample_3(sample_1_3),
    .reg_fc(fc),
    .res_filt(res_filt),
    .mode_vol(mode_vol),
    .clk(clk),
	 .div_spike(div_spike),
    .rst(~rst_n),
    
    .sample_ready(sample_ready)
);

spi_dac_i spi_dac_i(
    .sample_in(full_sample_1[14:3]),
    .clk(clk),
	 .div_spike(div_spike),
    .rst(~rst_n),
    .spi_leb(DAC_leb),
    .spi_clk(DAC_clk),
    .spi_dat(DAC_dat),
    .spi_csb(DAC_csb),
    .sample_ready(sample_ready)
);

endmodule

