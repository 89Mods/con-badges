//Constants for the particular RAM chip used

//CL = 3 seems fine at the clock speed its at here

//Defines for MR settings
`define MR_BURST_LEN_4 'b010
`define MR_BURST_LEN_8 'b011
`define MR_BURST_SEQUENTIAL 0
`define MR_BURST_INTERLEAVED (1 << 3)
`define MR_CAS_LATENCY(x) (x << 4)
`define MR_MODE_TEST (1 << 7)
`define MR_MODE_NORMAL 0
`define MR_DLL_RESET (1 << 8)
`define MR_WRITE_RECOVERY(x) ((x - 1) << 9)
`define MR_PD_FAST 0
`define MR_PD_SLOW (1 << 12)

`define CAS_LATENCY 3 //What goes into the MR
//Actual delays the controller takes
`define WRITE_LATENCY (`CAS_LATENCY-1)
`define READ_LATENCY (`CAS_LATENCY)

`define READ_RECOVERY 0 //How long the controller will delay after a read
`define WRITE_RECOVERY_SETTING 2 //This is what goes in the MR
`define WRITE_RECOVERY 2 //This is how much delay the controller will actually take after a write

`define MR_SETTING (`MR_BURST_LEN_4 | `MR_BURST_SEQUENTIAL | `MR_CAS_LATENCY(`CAS_LATENCY) | `MR_MODE_NORMAL | `MR_WRITE_RECOVERY(`WRITE_RECOVERY_SETTING) | `MR_PD_FAST)

//Defines for EMR settings
`define EMR_DLL_NORMAL 0
`define EMR_DLL_TEST 1
`define EMR_FULL_STRENGTH 0
`define EMR_REDUCED_STRENGTH (1 << 1)
`define EMR_R_DISABLED 0
`define EMR_R_75 (1 << 2)
`define EMR_R_150 (1 << 6)
`define EMR_R_50 ((1 << 2) | (1 << 6))
`define EMR_AL(x) (x << 3)
`define EMR_OCD_EXIT 0
`define EMR_OCD_DEFAULTS (7 << 7)
`define EMR_NDQS_ON 0
`define EMR_NDQS_OFF (1 << 10)
`define EMR_RDQS_OFF 0
`define EMR_RDQS_ON (1 << 11)
`define EMR_OUTS_ON 0
`define EMR_OUTS_OFF (1 << 12)

`define EMR_SETTING (`EMR_DLL_NORMAL | `EMR_R_150 | `EMR_FULL_STRENGTH | `EMR_AL(0) | `EMR_NDQS_OFF | `EMR_RDQS_OFF)

//How many clock cycles correspond to one tRFC
`define REFRESH_WAIT 7

//How many clock cycles correspond to one tRP
`define PRECHARGE_WAIT 1

//How many clock cycles correspond to one tRCD (activate command)
//Minimum value of 1
//(I found real hardware glitches out when this is 0)
`define TRCD_CYCLES 1

`define EARLY_READY

module dram_controller(
	input clk,
	output reg ddr_clk = 0,
	input [7:0] DQ_in,
	output [7:0] DQ_out,
	output DQ_oe,
	output reg CS_b = 1,
	output reg ODT = 0,
	output reg RAS_b = 1,
	output reg CAS_b = 1,
	output reg WE_b = 1,
	output reg [2:0] BA = 0,
	output [13:0] A,
	inout DQS,
	output DM,
	output reg CKE = 0,
	output cmd_act,
	output reg bus_act = 0,

	/*
	 * Flat memory interface
	 */
	input CEb_in,
	input [31:0] Q_in,
	output [31:0] Q_out,
	input [3:0] write_enables,
	input [24:0] A_f,
	input rst_b,
	output ready,
	output reg init_done = 0
);

wire reset = !rst_b;

reg [31:0] data_out_buff;
reg [3:0] data_enable_buff;

assign DM = !writing || data_enable_buff[0];
assign DQ_oe = writing;
assign DQ_out = data_out_buff[7:0];
assign DQS = writing ? DQS_ll : 1'bz;
//assign DM = !writing || ((rw_step == 0 || !counter_expired) && WEb_f_hi) || ((rw_step == 2 || rw_step == 1) && WEb_f_lo);

/*
 * Define address bus value
 * During init sequence, taken from below table
 * During normal operation, row address during ACTIVATE, column address otherwise
 * Note that A10 in the column address is always low
 */
reg [13:0] initialization_A;
always @(*) begin
	casez(init_step)
		default: initialization_A = 0;
		7'b?000101: initialization_A = 1<<10;
		7'b?010001: initialization_A = `MR_DLL_RESET;
		7'b?010100: initialization_A = 1<<10;
		7'b?011110: initialization_A = `MR_SETTING;
		7'b?100001: initialization_A = `EMR_SETTING | `EMR_OCD_DEFAULTS;
		7'b?100100: initialization_A = `EMR_SETTING;
	endcase
end

/*
 * Bank address during init sequence, combines with above table
 */
reg [2:0] BA_init;
always @(*) begin
	casez(init_step)
		default: BA_init = 3'bxxx; //Don’t care
		7'b?000111: BA_init = 3'b010;
		7'b?001010: BA_init = 3'b011;
		7'b?001101: BA_init = 3'b001;
		7'b?010000: BA_init = 3'b000;
		7'b?011101: BA_init = 3'b000;
		7'b?100000: BA_init = 3'b001;
		7'b?100011: BA_init = 3'b001;
	endcase
end

wire [13:0] normal_A = state == 1 ? row_address : {3'b000, 1'b0, 1'b0, column_address[9:0]};
assign A = init_done ? normal_A : initialization_A;

reg [2:0] state           = 0;
reg [8:0] counter         = 9'h1FF;
reg [8:0] init_counter    = 9'h1FF;
reg [2:0] rw_step         = 3'b111;
reg [8:0] command_timeout = 0; //TODO: adjust
reg writing               = 0;
reg DQS_l                 = 0;
reg DQS_ll                = 0;
reg last_DQS              = 0;
reg ready_l               = 0;
reg needs_precharge       = 0;
reg [13:0] row_address_l  = 0;
reg latch_command         = 0;
reg [6:0] init_step       = 7'h40;
reg CE_edge               = 1'b1;
reg CE_edge_edge          = 1'b1;
reg [31:0] dbuff          = 0;
reg [24:0] addr_latch     = 0;
reg bus_act_soon          = 0;

wire [7:0] counter_dec = counter - 1;
wire counter_expired = counter == 0;

assign Q_out = dbuff;
wire ready_to_latch = ready_l && !latch_command;
assign ready = ready_to_latch && !start;
reg cmd_act_latency = 0;
assign cmd_act = !CS_b || cmd_act_latency || latch_command;
wire start = (CE_edge && !CEb_in) || (CE_edge_edge && !CE_edge) || (CE_edge_edge && !CEb_in);

wire [9:0] column_address = {addr_latch[7:0], 2'b00};
wire [13:0] row_address = addr_latch[21:8];

`ifdef BENCH
wire [7:0] #1 DQ_in_del = DQ_in;
`else
wire [7:0] DQ_in_del = DQ_in;
`endif

always @(negedge clk) DQS_ll <= DQS_l;

localparam ddr_clkdiv = 1;

reg [4:0] ddr_clkdiv_ctr = 0;

always @(posedge clk) begin
	if(ready_to_latch && !reset) begin
		CE_edge_edge <= CE_edge;
		CE_edge <= CEb_in;
		if(start) latch_command <= 1;
	end
	ddr_clkdiv_ctr <= ddr_clkdiv_ctr + 1;
	if(command_timeout && !reset) command_timeout <= command_timeout - 1;
	if(reset) begin
			CKE       <= 0;
			CS_b      <= 1'b1;
			RAS_b     <= 1'b1;
			CAS_b     <= 1'b1;
			WE_b      <= 1'b1;
			ready_l   <= 0;
			init_done <= 0;
			state     <= 0;
			DQS_l     <= 0;
			writing   <= 0;
			rw_step   <= 2'b11;
			init_step <= 7'h40;
			needs_precharge <= 0;
			ODT       <= 0;
			counter   <= 8'hFF;
			init_counter <= 9'h1FF;
			dbuff     <= 0;
			bus_act   <= 0;
			bus_act_soon <= 0;
			command_timeout <= 0;
	end else if(ddr_clkdiv_ctr == (ddr_clkdiv-1)) begin
		ddr_clkdiv_ctr <= 0;
		cmd_act_latency <= !CS_b;
		ddr_clk <= !ddr_clk;
		if(ddr_clk) addr_latch <= A_f;
		if(counter_expired) bus_act <= bus_act_soon;
		/*
		* Normal operation
		*/
		last_DQS <= DQS;
		//Commented out DQS edge check when reading
		//Seems unecessary, still works and needs less LUTs
		if(counter_expired && state[1]/* && (writing || last_DQS != DQS || !rw_step[1])*/) begin
			rw_step <= rw_step - 1;
			if(rw_step == 0) begin
				state <= 0;
`ifdef EARLY_READY
				ready_l <= 1;
`endif
				//TODO: Write recovery can be 0 if we know the next cycle isn’t going to be a PRECHARGE right away
				counter <= writing ? `WRITE_RECOVERY : `READ_RECOVERY;
			end
			DQS_l <= !DQS_l;
			if(!writing) dbuff <= {dbuff[23:0], DQ_in_del};
			data_out_buff <= {8'hxx, data_out_buff[31:8]};
			data_enable_buff <= {1'b1, data_enable_buff[3:1]};
		end else if(init_done && ddr_clk) begin
			CS_b  <= 1;
			RAS_b <= 1;
			CAS_b <= 1;
			WE_b  <= 1;
			DQS_l <= 0;

			if(!counter_expired) begin
				counter <= counter_dec;
			end else if(state == 4) begin
				activate();
			end else if(state == 5) begin
				refresh();
				state <= 0;
`ifdef EARLY_READY
				ready_l <= 1;
`endif
			end else if(state) begin
				if(write_enables == 0) begin
					begin_read();
				end else begin
					begin_write();
				end
			end else begin
				writing <= 0;
				bus_act <= 0;
				bus_act_soon <= 0;
`ifndef EARLY_READY
				ready_l <= 1;
`endif
				if(!command_timeout && needs_precharge) begin
					needs_precharge <= 0;
					precharge();
					state <= 5;
				end else begin
					if(latch_command) begin
						ready_l <= 0;
						latch_command <= 0;
						CE_edge_edge <= CEb_in;
						CE_edge <= CEb_in;
						if(command_timeout) begin
							if(row_address == row_address_l && addr_latch[24:22] == BA) begin
								if(write_enables == 0) begin
									begin_read();
								end else begin
									begin_write();
								end
							end else begin
								precharge();
								state <= 4;
							end
						end else begin
							activate();
							command_timeout <= 511;
							needs_precharge <= 1;
						end
					end else if(!command_timeout) begin
						refresh();
					end
				end
			end
		end
		
		/*
		* Initialization
		*/
		if(ddr_clk && !init_done) begin
			if(init_step == 1) begin
				//Startup
				CKE <= 1;
			end
			if(init_step == 2) begin
				//Startup delay
				init_counter <= 511;
			end
			if(init_step == 4 || init_step == 19) begin
				//PRECHARGE (ALL), start of command
				CS_b <= 0;
				RAS_b <= 0;
				WE_b <= 0;
			end
			if(init_step == 5 || init_step == 20) begin
				//PRECHARGE (ALL), end of command
				CS_b <= 1;
				RAS_b <= 1;
				WE_b <= 1;
				init_counter <= 511;
			end
			if(init_step == 7 || init_step == 10 || init_step == 13
			|| init_step == 16 || init_step == 29 || init_step == 32
			|| init_step == 35) begin
				//All instances of LOAD MODE (start of command)
				BA <= BA_init;
				CS_b <= 0;
				RAS_b <= 0;
				CAS_b <= 0;
				WE_b <= 0;
			end
			if(init_step == 8 || init_step == 11 || init_step == 14
			|| init_step == 17 || init_step == 30 || init_step == 33
			|| init_step == 36) begin
				//All instances of LOAD MODE (end of command)
				CS_b <= 1;
				RAS_b <= 1;
				CAS_b <= 1;
				WE_b <= 1;
				init_counter <= 255;
			end
			if(init_step == 22 || init_step == 25) begin
				//REFRESH, start of command
				CS_b <= 0;
				RAS_b <= 0;
				CAS_b <= 0;
				init_counter <= 255;
			end
			if(init_step == 23 || init_step == 26) begin
				//REFRESH, end of command
				CS_b <= 1;
				RAS_b <= 1;
				CAS_b <= 1;
			end
			if(init_step == 38) begin
				init_done <= 1;
				ODT <= 1;
`ifdef EARLY_READY
				ready_l <= 1;
`endif
			end
`ifdef BENCH
			if(init_step[6]) init_counter <= 5;
`else
			if(init_step[6]) init_counter <= 255;
`endif	
		
			if(init_counter == 0) begin
				init_step <= init_step + 1;
`ifdef BENCH
				if(init_step <= 38) $display("Init step %d", init_step);
`endif
			end else init_counter <= init_counter - 1;
		end
	end
end

task begin_read();
	begin
		CS_b     <= 0;
		CAS_b    <= 0;
		counter  <= `READ_LATENCY;
		rw_step  <= 4;
		state    <= 2;
		last_DQS <= 0;
		dbuff    <= 0;
		bus_act_soon <= 1;
	end
endtask

task begin_write();
	begin
		writing <= 1;
		DQS_l   <= 0;
		CS_b    <= 0;
		CAS_b   <= 0;
		WE_b    <= 0;
		counter <= `WRITE_LATENCY;
		rw_step <= 3;
		state   <= 3;
		bus_act_soon <= 1;
		data_out_buff <= Q_in;
		data_enable_buff <= ~write_enables;
		//dbuff <= Q_f;
	end
endtask

task activate();
	begin
		CS_b    <= 0;
		RAS_b   <= 0;
		BA      <= addr_latch[24:22];
		state   <= 1;
		counter <= `TRCD_CYCLES;
		row_address_l <= row_address;
	end
endtask

task precharge();
	begin
		CS_b    <= 0;
		RAS_b   <= 0;
		WE_b    <= 0;
		counter <= `PRECHARGE_WAIT;
	end
endtask

task refresh();
	begin
		CS_b    <= 0;
		RAS_b   <= 0;
		CAS_b   <= 0;
		counter <= `REFRESH_WAIT;
	end
endtask

endmodule
