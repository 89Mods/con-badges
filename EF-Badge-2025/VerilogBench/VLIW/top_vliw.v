`default_nettype none

`define NUM_REGS 64
`define REG_IDX ($clog2(`NUM_REGS)-1)

module vliw(
  input clk, //Clock input (you can also use an input pin as a custom clock pin and ignore this)
  input rstn, //Active low
  //Be careful with io_in/out/oeb[2:0] - these are assigned to the management controller on power-up
  //They may behave eratically until the firmware can assign them to your project
  //It is recommended to use them as outputs only
  input [35:0] io_in,
  output [35:0] io_out,
  output [35:0] io_oeb, //Output Enable Bar ; 0 = Output, 1 = Input
  input [4:0] custom_settings, //Custom settings register, settable over mgmt controller firmware
  
  /*
   * Wiring to execution units
   */
   //1
   input [`REG_IDX:0] reg1_idx0,
   input [`REG_IDX:0] reg2_idx0,
   input [31:0] dest_val0,
   input [1:0] dest_mask0,
   input [`REG_IDX:0] dest_idx0,
   
   input [2:0] pred_idx0,
   input [2:0] dest_pred0,
   input dest_pred_val0,
   
   input [31:0] loadstore_address0,
   input is_load0,
   input is_store0,
   input sign_extend0,
   input [1:0] loadstore_size0,
   
   input take_branch0,
   input [27:0] new_PC0,
   input int_return0,
   
   input eu0_busy,
   
   output [41:0] eu0_instruction,
   output [31:0] reg1_val0,
   output [31:0] reg2_val0,
   output pred_val0,
   
   //2
   input [`REG_IDX:0] reg1_idx1,
   input [`REG_IDX:0] reg2_idx1,
   input [31:0] dest_val1,
   input [1:0] dest_mask1,
   input [`REG_IDX:0] dest_idx1,
   
   input [2:0] pred_idx1,
   input [2:0] dest_pred1,
   input dest_pred_val1,
   
   input [31:0] loadstore_address1,
   input is_load1,
   input is_store1,
   input sign_extend1,
   input [1:0] loadstore_size1,
   
   input take_branch1,
   input [27:0] new_PC1,
   input int_return1,
   
   input eu1_busy,
   
   output [41:0] eu1_instruction,
   output [31:0] reg1_val1,
   output [31:0] reg2_val1,
   output pred_val1,
   
   //3
   input [`REG_IDX:0] reg1_idx2,
   input [`REG_IDX:0] reg2_idx2,
   input [31:0] dest_val2,
   input [1:0] dest_mask2,
   input [`REG_IDX:0] dest_idx2,
   
   input [2:0] pred_idx2,
   input [2:0] dest_pred2,
   input dest_pred_val2,
   
   input [31:0] loadstore_address2,
   input is_load2,
   input is_store2,
   input sign_extend2,
   input [1:0] loadstore_size2,
   
   input take_branch2,
   input [27:0] new_PC2,
   input int_return2,
   
   input eu2_busy,
   
   output [41:0] eu2_instruction,
   output [31:0] reg1_val2,
   output [31:0] reg2_val2,
   output pred_val2,
   
   output rst_eu,
   output [27:0] curr_PC,
   
   input cache_hit,
   output cache_invalidate,
   input [127:0] cache_entry,
   output [127:0] cache_new_entry,
   output [27:0] cache_PC,
   output cache_rst,
   output cache_entry_valid
);
reg cache_hit_used;
wire [127:0] curr_pack_next = {bus_in, curr_pack[127:16]};
wire cache_enabled;
assign cache_new_entry = curr_pack_next;
assign cache_entry_valid = memory_cyc == 4'hF && !serving_interrupt;
assign cache_PC = cache_entry_valid || memory_cyc[3] ? PC : PC_inc;
assign cache_rst = !rstn;
assign cache_invalidate = !cache_enabled;
wire valid_cache_hit = custom_settings[4] && cache_enabled && cache_hit;
wire [2:0] execution_mask_from_cache = {cache_entry[127:126] == 0, cache_entry[126] == 0, 1'b1};

assign rst_eu = !rstn || !startup_delay || memory_cyc[3];
assign curr_PC = PC;

assign eu0_instruction = curr_pack[41:0];
assign eu1_instruction = curr_pack[83:42];
assign eu2_instruction = curr_pack[125:84];
assign reg1_val0 = regfile[reg1_idx0];
assign reg2_val0 = regfile[reg2_idx0];
assign pred_val0 = predicates[pred_idx0] & execution_mask[0] & fetched;
assign reg1_val1 = regfile[reg1_idx1];
assign reg2_val1 = regfile[reg2_idx1];
assign pred_val1 = predicates[pred_idx1] & execution_mask[1] & fetched;
assign reg1_val2 = regfile[reg1_idx2];
assign reg2_val2 = regfile[reg2_idx2];
assign pred_val2 = predicates[pred_idx2] & execution_mask[2] & fetched;

wire blinkLED;
blink blink(
	.clk(clk),
	.LED(blinkLED)
);

reg M1;
reg processing_load;
reg processing_store;
wire processing_loadstore = processing_store || processing_load;

wire [15:0] bus_in = io_in[18:3];
wire [7:0] in_8bit = loadstore_address[0] ? bus_in[15:8] : bus_in[7:0];
wire [31:0] in_8bit_se = sign_extend ? {{24{in_8bit[7]}}, in_8bit} : {24'h000000, in_8bit};
wire [31:0] in_16bit_se = sign_extend ? {{16{bus_in[15]}}, bus_in} : {16'h0000, bus_in};

reg [30:0] requested_addr;
reg [30:0] curr_addr;
reg [1:0] requested_len;
reg [3:0] memory_cyc;

wire le_hi = curr_addr[30:16] != requested_addr[30:16] && !io_access;
wire le_lo = !le_hi && (curr_addr[15:0] != requested_addr[15:0]) && !io_access;
assign io_out[19] = le_hi && clk && rstn && !last_le_hi && startup_delay;
assign io_out[20] = le_lo && clk && rstn && !last_le_lo && startup_delay;
assign io_oeb[24:19] = 6'h00;

wire bus_dir = le_hi || le_lo || !web;
assign io_oeb[18:3] = {16{!bus_dir}};
assign io_out[18:3] = le_hi ? {1'b0, requested_addr[30:16]} : (le_lo ? requested_addr[15:0] : (processing_store ? (memory_cyc[2:0] == 0 ? mem_buff[15:0] : mem_buff[31:16]) : 0));
assign io_out[21] = !bus_dir;

assign io_out[1] = M1;
assign io_oeb[1] = 0;

wire oeb = !memory_cyc[3] || le_hi || le_lo || !rstn || !startup_delay || processing_store || io_access;
assign io_out[22] = oeb;
wire web = !memory_cyc[3] || !processing_store || le_hi || le_lo || !rstn || !startup_delay || io_access;
wire web_lo_pre = web || (loadstore_size == 0 && loadstore_address[0]);
wire web_hi_pre = web || (loadstore_size == 0 && !loadstore_address[0]);
assign io_out[23] = custom_settings[1:0] == 0 ? web_lo_pre : (custom_settings[1:0] == 1 ? web_lo_pre | clk : web_lo_pre | !clk);
assign io_out[24] = custom_settings[1:0] == 0 ? web_hi_pre : (custom_settings[1:0] == 1 ? web_hi_pre | clk : web_hi_pre | !clk);

reg [31:0] mem_buff;
reg [127:0] curr_pack;
reg last_le_lo;
reg last_le_hi;

//FIXME
always @(negedge clk) begin
	if(!rstn || !startup_delay) begin
		last_le_lo <= 0;
		last_le_hi <= 0;
	end else begin
		last_le_lo <= le_lo;
		last_le_hi <= le_hi;
	end
end

wire [1:0] stops = curr_pack[127:126];
reg [2:0] execution_mask;

reg [31:0] regfile [`NUM_REGS-1:0];
reg predicates [7:0];
reg fetched;

//Simulator Workaround
integer i2;
initial begin
	for(i2 = 0; i2 < `NUM_REGS; i2=i2+1) begin
		regfile[i2] = 0;
	end
end

/*
 * Having multiple loadstore type instructions in one pack is illegal.
 * But without proper exception support, the best way to build this is to
 * always handle the first loadstore in the pack.
 * If there are multiple, the rest are silently ignored.
 */
wire [1:0] ls_unit = (is_load0 || is_store0) ? 0 : ((is_load1 || is_store1) ? 1 : ((is_load2 || is_store2) ? 2 : 3));
reg is_load;
reg is_store;
reg sign_extend;
reg [1:0] loadstore_size;
reg [31:0] loadstore_address;
reg [`REG_IDX:0] load_dest;
reg [1:0] load_mask;
always @(*) begin
	case(ls_unit)
		default: begin
			is_load = 0;
			is_store = 0;
			load_dest = 0;
			load_mask = 0;
		end
		0: begin
			is_load = is_load0;
			is_store = is_store0;
			sign_extend = sign_extend0;
			loadstore_size = loadstore_size0;
			loadstore_address = loadstore_address0;
			load_dest = dest_idx0;
			load_mask = dest_mask0;
		end
		1: begin
			is_load = is_load1;
			is_store = is_store1;
			sign_extend = sign_extend1;
			loadstore_size = loadstore_size1;
			loadstore_address = loadstore_address1;
			load_dest = dest_idx1;
			load_mask = dest_mask1;
		end
		2: begin
			is_load = is_load2;
			is_store = is_store2;
			sign_extend = sign_extend2;
			loadstore_size = loadstore_size2;
			loadstore_address = loadstore_address2;
			load_dest = dest_idx2;
			load_mask = dest_mask2;
		end
	endcase
end

reg serving_interrupt;
wire io_access = requested_addr[30:6] == 25'h1FFFFFF && requested_len == 2 && (processing_load || processing_store) && memory_cyc[3];
wire [31:0] io_rval;
wire [7:0] ioport_out;
wire [7:0] ioport_oeb;
wire int0;
wire int1;
wire int2;
wire int3;
wire int_enable;
wire needs_interrupt = (int0 || int1 || int2 || int3) && int_enable;
wire [27:0] int_loc = int1 ? 2 : (int2 ? 3 : (int3 ? 4 : 1));
wire int_return = int_return0 || int_return1 || int_return2;
io_block io_block(
	.io_addr(requested_addr[5:1]),
	.io_wval(mem_buff),
	.io_rval(io_rval),
	.io_wen(processing_store && io_access),
	.UTX(io_out[25]),
	.URX(io_in[26]),
	.SCLK(io_out[27]),
	.SDO(io_out[28]),
	.SDI(io_in[29]),
	.ioport_out(ioport_out),
	.ioport_in({io_in[0], io_in[2], io_in[35:30]}),
	.ioport_oeb(ioport_oeb),
	.clk(clk),
	.rst(!rstn || !startup_delay),
	.cache_enabled(cache_enabled),
	.int0(int0),
	.int1(int1),
	.int2(int2),
	.int3(int3),
	.ie(int_enable),
	.int_return(int_return),
	.serving_interrupt(serving_interrupt),
	.cache_hit_used(cache_hit_used)
);
assign io_out[29] = 1'b0;
assign io_out[26] = 1'b1;

assign io_oeb[25] = 1'b0;
assign io_oeb[26] = 1'b1;
assign io_oeb[28:27] = 2'b00;
assign io_oeb[29] = 1'b1;
assign io_out[35:30] = ioport_out[5:0];

assign io_out[2] = custom_settings[3] ? blinkLED : ioport_out[6];
assign io_oeb[35:30] = ioport_oeb[5:0];
assign io_oeb[2] = custom_settings[3] ? 1'b0 : ioport_oeb[6];
assign io_out[0] = custom_settings[2] ? predicates[1] : ioport_out[7];
assign io_oeb[0] = custom_settings[2] ? 1'b0 : ioport_oeb[7];

reg [27:0] PC;
wire [27:0] PC_inc = PC + 1'b1;
wire [27:0] next_PC = take_branch0 ? new_PC0 : (take_branch1 ? new_PC1 : (take_branch2 ? new_PC2 : PC_inc));
wire take_branch = take_branch0 || take_branch1 || take_branch2;
wire [27:0] fetch_PC = processing_load || processing_store ? PC : next_PC;

reg just_branched;
reg startup_delay;
always @(posedge clk) begin
	regfile[0] <= 0;
	predicates[0] <= 1;
	M1 <= 0;
	just_branched <= 0;
	cache_hit_used <= 0;
	
	if(!rstn) startup_delay <= 0;
	else startup_delay <= 1;
	if(!rstn || !startup_delay) begin
		curr_pack <= 0;
		curr_addr <= 31'h7FFFFFFF;
		requested_addr <= 0;
		requested_len <= 3;
		memory_cyc <= 8;
		predicates[1] <= 1;
		predicates[2] <= 0;
		predicates[3] <= 1;
		predicates[4] <= 1;
		predicates[5] <= 0;
		predicates[6] <= 1;
		predicates[7] <= 0;
		regfile[1] <= 0;
		regfile[2] <= 0;
		regfile[3] <= 0;
		regfile[4] <= 0;
		regfile[5] <= 0;
		regfile[6] <= 0;
		regfile[7] <= 0;
		regfile[8] <= 0;
		regfile[9] <= 0;
		regfile[10] <= 0;
		regfile[11] <= 0;
		regfile[12] <= 0;
		regfile[13] <= 0;
		regfile[14] <= 0;
		regfile[15] <= 0;
		regfile[31] <= 0;
		PC <= 0;
		processing_load <= 0;
		processing_store <= 0;
		execution_mask <= 2'b11;
		fetched <= 0;
		serving_interrupt <= 0;
	end else begin
		if(le_hi) curr_addr[30:16] <= requested_addr[30:16];
		if(le_lo) curr_addr[15:0] <= requested_addr[15:0];
		if(just_branched && valid_cache_hit) begin
			curr_pack <= cache_entry;
			execution_mask <= execution_mask_from_cache;
			fetched <= 1;
			memory_cyc <= 0;
			cache_hit_used <= 1;
		end else if(curr_addr == requested_addr || io_access) begin
			if(memory_cyc[3]) begin
				memory_cyc <= 0;
				if(io_access) begin
					if(processing_load) begin
						regfile[load_dest] <= io_rval;
					end
					next_instr();
				end else if(memory_cyc[2:0] == 0) begin
					if(requested_len == 0) begin
						if(processing_loadstore) next_instr();
						if(processing_load) begin
							regfile[load_dest][7:0] <= in_8bit_se[7:0];
							if(load_mask[0]) regfile[load_dest][15:8] <= in_8bit_se[15:8];
							if(load_mask[1]) regfile[load_dest][31:16] <= in_8bit_se[31:16];
						end
					end else if(requested_len == 1) begin
						if(processing_loadstore) next_instr();
						if(processing_load) begin
							regfile[load_dest][15:0] <= in_16bit_se[15:0];
							if(load_mask[1]) regfile[load_dest][31:16] <= in_16bit_se[31:16];
						end
					end else begin
						if(!processing_store) mem_buff[15:0] <= bus_in;
						memory_cyc <= 9;
						requested_addr <= requested_addr + 1;
					end
				end else if(memory_cyc[2:0] == 1) begin
					if(processing_loadstore) next_instr();
					if(processing_load) regfile[load_dest] <= {bus_in[15:0], mem_buff[15:0]};
					if(requested_len == 3) begin
						//This is an instruction pack fetch
						memory_cyc <= 10;
						curr_pack[127:96] <= {bus_in[15:0], mem_buff[15:0]};
						requested_addr <= requested_addr + 1;
					end
				end else begin
					curr_pack <= curr_pack_next;
					if(memory_cyc != 4'hF) requested_addr <= requested_addr + 1;
					else begin
						fetched <= 1;
						serving_interrupt <= 0;
					end
					memory_cyc <= memory_cyc + 1;
					execution_mask <= {bus_in[15:14] == 0, bus_in[14] == 0, 1'b1}; //Parse initial 'stop' pattern
				end
			end else if(!(eu0_busy || eu1_busy || eu2_busy)) begin
				M1 <= 1;

				if(dest_mask2[0] && !(is_load2 || is_store2)) regfile[dest_idx2][15:0] <= dest_val2[15:0];
				if(dest_mask2[1] && !(is_load2 || is_store2)) regfile[dest_idx2][31:16] <= dest_val2[31:16];
				if(dest_pred2 != 0) predicates[dest_pred2] <= dest_pred_val2;

				if(dest_mask1[0] && !(is_load1 || is_store1)) regfile[dest_idx1][15:0] <= dest_val1[15:0];
				if(dest_mask1[1] && !(is_load1 || is_store1)) regfile[dest_idx1][31:16] <= dest_val1[31:16];
				if(dest_pred1 != 0) predicates[dest_pred1] <= dest_pred_val1;

				if(dest_mask0[0] && !(is_load0 || is_store0)) regfile[dest_idx0][15:0] <= dest_val0[15:0];
				if(dest_mask0[1] && !(is_load0 || is_store0)) regfile[dest_idx0][31:16] <= dest_val0[31:16];
				if(dest_pred0 != 0) predicates[dest_pred0] <= dest_pred_val0;

				/*
				 * Branching stuffs
				 */
				if(take_branch || execution_mask[2]) PC <= next_PC;
				/*
				 * Load/Store stuffs
				 */
				if(loadstore_size == 0) begin
					if(loadstore_address[0]) mem_buff <= {16'h0000, regfile[load_dest][7:0], 8'h00};
					else mem_buff <= {24'h000000, regfile[load_dest][7:0]};
				end else mem_buff <= regfile[load_dest];
				if(is_load || is_store) begin
					requested_addr <= loadstore_address[31:1];
					requested_len <= loadstore_size;
					if(is_load) processing_load <= 1;
					else if(is_store) begin
						processing_store <= 1;
					end
					memory_cyc <= 8;
				end else begin
					next_instr();
				end
			end
		end
	end
end

task next_instr();
	begin
		processing_load <= 0;
		processing_store <= 0;
		//Always move on to next instruction if taking a branch
		//If there are stops, instructions after the stop following the branch are aborted even though
		//They are in the same pack
		if(execution_mask[2] || take_branch) begin
			if(needs_interrupt) begin
				requested_addr <= {int_loc, 3'b000};
				PC <= int_loc;
				memory_cyc <= 8;
				requested_len <= 3;
				fetched <= 0;
				regfile[`NUM_REGS-1] <= {4'h0, fetch_PC};
				serving_interrupt <= 1;
			end else begin
				if(!take_branch && valid_cache_hit) begin
					curr_pack <= cache_entry;
					execution_mask <= execution_mask_from_cache;
					cache_hit_used <= 1;
				end else begin
					just_branched <= take_branch;
					requested_addr <= {fetch_PC, 3'b000};
					memory_cyc <= 8;
					requested_len <= 3;
					fetched <= 0;
				end
			end
		//Define all possible transitions for the execution mask based on stops configuration
		end else if(execution_mask == 3'b001) begin
			execution_mask <= stops[1] ? 3'b010 : 3'b110;
		end else begin
			execution_mask <= 3'b100;
		end
	end
endtask

wire dbg_icache_enabled = custom_settings[4] && cache_enabled;

wire [31:0] r0 = regfile[0];
wire [31:0] r1 = regfile[1];
wire [31:0] r2 = regfile[2];
wire [31:0] r3 = regfile[3];
wire [31:0] r4 = regfile[4];
wire [31:0] r5 = regfile[5];
wire [31:0] r6 = regfile[6];
wire [31:0] r7 = regfile[7];
wire [31:0] r8 = regfile[8];
wire [31:0] r9 = regfile[9];
wire [31:0] r10 = regfile[10];
wire [31:0] r11 = regfile[11];
wire [31:0] r12 = regfile[12];
wire [31:0] r13 = regfile[13];
wire [31:0] r14 = regfile[14];
wire [31:0] r15 = regfile[15];
wire [31:0] r20 = regfile[20];
wire [31:0] r21 = regfile[21];
wire [31:0] r22 = regfile[22];
wire [31:0] r23 = regfile[23];
wire [31:0] r31 = regfile[31];
wire [31:0] r32 = regfile[32];
wire [31:0] r59 = regfile[59];
wire [31:0] r60 = regfile[60];
wire [31:0] sp = regfile[61];
wire [31:0] iobase = regfile[62];
wire [31:0] int_link = regfile[63];

wire p0 = predicates[0];
wire p1 = predicates[1];
wire p2 = predicates[2];
wire p3 = predicates[3];
wire p4 = predicates[4];
wire p5 = predicates[5];
wire p6 = predicates[6];
wire p7 = predicates[7];

endmodule

module io_block(
	input [4:0] io_addr,
	input [31:0] io_wval,
	output [31:0] io_rval,
	input io_wen,

	output UTX,
	input URX,

	output SCLK,
	output SDO,
	input SDI,

	output [7:0] ioport_out,
	input [7:0] ioport_in,
	output [7:0] ioport_oeb,
	
	output reg cache_enabled,
	
	output reg int0,
	output reg int1,
	output reg int2,
	output reg int3,
	output reg ie,
	input int_return,
	input serving_interrupt,
	input cache_hit_used,

	input clk,
	input rst
);

reg [7:0] io_dir;
reg [7:0] io_dat;
assign ioport_oeb = ~io_dir;
assign ioport_out = io_dat;

reg [31:0] timer0;
reg [31:0] timer1;
reg [31:0] timer0_top;
reg [31:0] timer1_top;

reg [16:0] timer0_prescaler;
reg [16:0] timer1_prescaler;
reg [16:0] timer0_pre_counter;
reg [16:0] timer1_pre_counter;

reg [15:0] udiv;
reg [7:0] sdiv;

reg [7:0] alt_funct;

reg [17:0] cache_hit_ctr;
reg [31:0] test;

reg [7:0] pwm_counter;
wire [7:0] pwm_counter_next = pwm_counter + 1;
reg [7:0] pwm_setting;
reg pwm;

wire uart_busy;
wire uart_has_byte;
wire spi_busy;
wire [7:0] udat;
wire [7:0] sdat;

reg [31:0] io_rval_tbl;
always @(*) begin
	case(io_addr)
		default: io_rval_tbl = 32'hFFFFFFFF;
		0: io_rval_tbl = timer0;
		1: io_rval_tbl = timer1;
		2: io_rval_tbl = timer0_top;
		3: io_rval_tbl = timer1_top;
		4: io_rval_tbl = {15'h0000, timer0_prescaler};
		5: io_rval_tbl = {15'h0000, timer1_prescaler};
		6: io_rval_tbl = {16'h0000, udiv};
		7: io_rval_tbl = {24'h000000, sdiv};
		8: io_rval_tbl = {24'h000000, udat};
		9: io_rval_tbl = {24'h000000, sdat};
		10: io_rval_tbl = {29'h0, uart_busy, spi_busy, uart_has_byte};
		11: io_rval_tbl = {24'h000000, io_dir};
		12: io_rval_tbl = {24'h000000, io_dat};
		13: io_rval_tbl = {24'h000000, ioport_in};
		14: io_rval_tbl = {24'h000000, alt_funct};
		16: io_rval_tbl = {14'h0000, cache_hit_ctr};
		17: io_rval_tbl = test;
		18: io_rval_tbl = {8'h72, 8'h69, 8'h68, 8'h43};
		19: io_rval_tbl = {16'h0000, 8'h21, 8'h70};
		20: io_rval_tbl = {24'h000000, pwm_setting};
	endcase
end
assign io_rval = io_rval_tbl;

reg int_edge;

always @(posedge clk) begin
	if(rst) begin
		timer0 <= 0;
		timer0_prescaler <= 100;
		timer1 <= 0;
		timer1_prescaler <= 100;
		timer0_pre_counter <= 0;
		timer1_pre_counter <= 0;
		timer0_top <= 32'hFFFFFFFF;
		timer1_top <= 32'hFFFFFFFF;
		io_dir <= 0;
		io_dat <= 8'h55;
		udiv <= 16'h0080;
		sdiv <= 8'h08;
		cache_enabled <= 0;
		alt_funct <= 0;
		int_edge <= 0;
		int0 <= 0;
		int1 <= 0;
		int2 <= 0;
		int3 <= 0;
		ie <= 0;
		cache_hit_ctr <= 0;
		test <= 0;
		pwm_counter <= 0;
		pwm_setting <= 66;
		pwm <= 0;
	end else begin
		pwm_counter <= pwm_counter_next;
		if(pwm_counter_next == 0) pwm <= 0;
		if(pwm_counter_next >= pwm_setting) pwm <= 1;
		if(alt_funct[5]) io_dat[1] <= pwm;
		
		if(alt_funct[4] && uart_has_byte) int3 <= 1;
		else int3 <= 0;
		if(cache_hit_used) cache_hit_ctr <= cache_hit_ctr + 1;
		if(alt_funct[3]) io_dat[0] <= 0;
		if(int_return) ie <= 1;
		if(serving_interrupt) ie <= 0;
		if(alt_funct[1]) begin
			if(ioport_in[1] && !int_edge) int0 <= 1;
			int_edge <= ioport_in[1];
		end else int_edge <= 0;
		timer0_pre_counter <= timer0_pre_counter + 1;
		timer1_pre_counter <= timer1_pre_counter + 1;
		if(timer0_prescaler == timer0_pre_counter) begin
			timer0_pre_counter <= 0;
			timer0 <= timer0 + 1;
			if(timer0 == timer0_top) begin
				timer0 <= 0;
				if(alt_funct[2]) int1 <= 1;
			end
		end
		if(timer1_prescaler == timer1_pre_counter) begin
			timer1_pre_counter <= 0;
			timer1 <= timer1 + 1;
			if(timer1 == timer1_top) begin
				timer1 <= 0;
				if(alt_funct[0]) io_dat[0] <= ~io_dat[0];
			end
		end
		if(io_wen) begin
			case(io_addr)
				0: timer0 <= io_wval;
				1: timer1 <= io_wval;
				2: timer0_top <= io_wval;
				3: timer1_top <= io_wval;
				4: timer0_prescaler <= io_wval[16:0];
				5: timer1_prescaler <= io_wval[16:0];
				6: udiv <= io_wval[15:0];
				7: sdiv <= io_wval[7:0];
				11: io_dir <= io_wval[7:0];
				12: io_dat <= io_wval[7:0];
				13: cache_enabled <= io_wval[0];
				14: alt_funct <= io_wval[7:0];
				15: begin
					if(io_wval[0]) int0 <= 0;
					if(io_wval[1]) int1 <= 0;
					int2 <= io_wval[2];
					ie <= io_wval[4] ? io_wval[3] : ie;
					if(io_wval[5]) int2 <= 0;
				end
				16: cache_hit_ctr <= io_wval[17:0];
				17: test <= io_wval;
				20: pwm_setting <= io_wval[7:0];
			endcase
		end
	end
end

vliw_uart uart(
	.divisor(udiv),
	.din(io_wval[7:0]),
	.dout(udat),
	.TX(UTX),
	.RX(URX),
	.start(io_wen && io_addr == 8),
	.busy(uart_busy),
	.has_byte(uart_has_byte),
	.clr_hb(io_wen && io_addr == 10),
	.clk(clk),
	.rst(rst)
);

vliw_spi spi(
	.divisor(sdiv),
	.din(io_wval[7:0]),
	.dout(sdat),
	.SCLK(SCLK),
	.DO(SDO),
	.DI(SDI),
	.start(io_wen && io_addr == 9),
	.busy(spi_busy),
	.clk(clk),
	.rst(rst)
);

endmodule

module blink(
    input clk,
    output LED
    );
integer counter;
reg state;
always @ (posedge clk) begin
    counter <= counter + 1;
     if(counter >= 8000000 )begin
        counter <=0;
        state <= !state;
     end 
end 
assign LED = state;        
endmodule
