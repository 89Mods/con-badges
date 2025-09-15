`define NUM_REGS 64
`define REG_IDX ($clog2(`NUM_REGS)-1)

module execution_unit(
	input [41:0] instruction,
	output [`REG_IDX:0] reg1_idx,
	output [`REG_IDX:0] reg2_idx,
	input [31:0] reg1_val,
	input [31:0] reg2_val,
	output [31:0] dest_val,
	output [1:0] dest_mask,
	output [`REG_IDX:0] dest_idx,
	
	output [2:0] pred_idx,
	input pred_val,
	output [2:0] dest_pred,
	output dest_pred_val,
	
	output [31:0] loadstore_address,
	output is_load,
	output is_store,
	output sign_extend,
	output [1:0] loadstore_size,
	
	input [27:0] curr_PC,
	output take_branch,
	output int_return,
	output [27:0] new_PC,

	input clk,
	input rst,
	output busy
);

wire [7:0] opcode = instruction[7:0];
wire [2:0] instr_type = pred_val ? instruction[2:0] : 0; //Spoof no-op if predicate is false

wire is_NOP = instr_type == 0;
wire is_ALU = instr_type == 1;
wire is_Imm = instr_type == 2;
wire is_pred = instr_type == 3;
wire is_loadstore = instr_type == 4;
wire is_branch = instr_type == 5;
wire is_jump = instr_type == 6;
wire is_reserved = instr_type == 7;

assign pred_idx = instruction[10:8];
assign dest_pred = is_pred ? instruction[13:11] : 0;
assign dest_idx = is_ALU || is_Imm || is_jump || is_loadstore ? instruction[`REG_IDX+11:11] : 0;
assign reg1_idx = is_branch ? instruction[`REG_IDX+11:11] : instruction[`REG_IDX+18:18];
assign reg2_idx = is_branch ? instruction[`REG_IDX+18:18] : instruction[`REG_IDX+25:25];

wire [16:0] imm = is_NOP ? 0 : instruction[41:25];
wire [31:0] signed_imm = {{15{imm[16]}}, imm};

wire [3:0] alu_op = instruction[6:3];
wire upper = is_ALU ? instruction[41] : imm[0];
wire needs_whole_reg = (alu_op == 1 && is_Imm) || (alu_op == 2 && is_Imm) || (alu_op[3:2] == 2'b10) || (is_ALU && !instruction[40]) || (is_Imm && !instruction[17]);
wire [15:0] alu_imm = imm[16:1];
wire sign_extend_imm = instruction[24];

wire [31:0] alu_in2 = is_Imm ? (upper ? {alu_imm, 16'h0000} : (sign_extend_imm ? {{16{alu_imm[15]}}, alu_imm} : {16'h0000, alu_imm})) : reg2_val;
assign dest_mask = is_jump ? 2'b11 : (is_load ? (!opcode[7] ? 2'b11 : (instruction[24] ? 2'b00 : 2'b01)) : (needs_whole_reg ? 2'b11 : (upper ? 2'b10 : 2'b01)));

/*
 * A bit ugly, but an ultra good optimization
 * Reduce the number of barrel shifters in the design to 1 by using the same one for
 * both left and right shifts.
 * It right shifts by default, but can left-shift by inverting the bit order (a free operation in hardware)
 */
wire [4:0] shift_amount = alu_in2[4:0];
wire is_leftshift = alu_op == 2 && instruction[7];
wire [31:0] shifter_in = is_leftshift ? 
{reg1_val[0], reg1_val[1], reg1_val[2], reg1_val[3], reg1_val[4], reg1_val[5],
reg1_val[6], reg1_val[7], reg1_val[8], reg1_val[9], reg1_val[10], reg1_val[11], reg1_val[12],
reg1_val[13], reg1_val[14], reg1_val[15], reg1_val[16], reg1_val[17], reg1_val[18], reg1_val[19],
reg1_val[20], reg1_val[21], reg1_val[22], reg1_val[23], reg1_val[24], reg1_val[25],
reg1_val[26], reg1_val[27], reg1_val[28], reg1_val[29], reg1_val[30], reg1_val[31]}
 : reg1_val;
wire is_signed_shift = alu_op == 1;
wire [31:0] shifter = $signed({is_signed_shift & reg1_val[31], shifter_in}) >>> shift_amount;
wire [31:0] leftshifted = {shifter[0], shifter[1], shifter[2], shifter[3], shifter[4], shifter[5], shifter[6],
shifter[7], shifter[8], shifter[9], shifter[10], shifter[11], shifter[12], shifter[13], shifter[14], shifter[15],
shifter[16], shifter[17], shifter[18], shifter[19], shifter[20], shifter[21], shifter[22],
shifter[23], shifter[24], shifter[25], shifter[26], shifter[27], shifter[28], shifter[29],
shifter[30], shifter[31]};

/*
 * Decide how we want our multiplication or division - signed or unsigned
 */

wire [31:0] reg1_val_cpl = ~reg1_val;
wire [31:0] reg1_val_neg = reg1_val_cpl + 1;
wire m1s = instruction[7] & reg1_val[31];
wire m2s = instruction[7] & alu_in2[31];
wire [31:0] rs1_inv = reg1_val_neg;
wire [31:0] rs2_inv = (~alu_in2) + 1;
wire [31:0] muli1 = m1s ? rs1_inv : reg1_val;
wire [31:0] muli2 = m2s ? rs2_inv : alu_in2;
//wire [63:0] mul = muli1 * muli2;
wire [63:0] mul;
multiplier multiplier(
	.a(muli1),
	.b(muli2),
	.o(mul)
);
wire mres_sign = m1s ^ m2s;
wire [63:0] muls = mres_sign ? (~mul) + 1 : mul;

wire [31:0] XOR = reg1_val ^ alu_in2;
wire LT = reg1_val < alu_in2;
wire LTS = $signed(reg1_val) < $signed(alu_in2);
wire EQL = XOR == 0;

reg [31:0] ALU_res;
always @(*) begin
	case(alu_op)
		0: ALU_res = instruction[7] ? reg1_val - alu_in2 : reg1_val + alu_in2;
		1: ALU_res = alu_in2[5] && is_Imm ? reg1_val + {4'h0, curr_PC} : shifter;
		2: ALU_res = instruction[7] ? leftshifted : shifter;
		3: ALU_res = LT ? 32'h00000001 : 32'h00000000;
		4: ALU_res = LTS ? 32'h00000001 : 32'h00000000;
		5: ALU_res = reg1_val & alu_in2;
		6: ALU_res = reg1_val | alu_in2;
		7: ALU_res = XOR;
		8: ALU_res = muls[31:0];
		9: ALU_res = muls[63:32];
		10: ALU_res = mres_sign ? (~div_res) + 1 : div_res;
		11: ALU_res = divi1_sign && opcode[7] ? (~modulo) + 1: modulo;
		12: ALU_res = reg1_val_cpl;
		13: ALU_res = reg1_val_neg;
		default: ALU_res = 0;
	endcase
end

assign dest_val = is_jump ? {4'h0, curr_PC+1'b1} : (alu_op == 4 && instruction[7] ? alu_in2 : ALU_res);

assign is_load = is_loadstore && !opcode[3];
assign is_store = is_loadstore && opcode[3];
assign sign_extend = opcode[4];
assign loadstore_size = opcode[6:5];
assign loadstore_address = reg1_val + signed_imm;

wire signed_comp = opcode[6];
reg comparison_tbl;
always @(*) begin
	case(opcode[4:3])
		default: comparison_tbl = 0;
		0: comparison_tbl = signed_comp ? reg1_val[31] == alu_in2[31] : EQL;
		1: comparison_tbl = signed_comp ? LTS : LT;
		3: comparison_tbl = signed_comp ? (EQL || LTS) : (EQL || LT);
	endcase
end
wire comparison = comparison_tbl ^ opcode[5];

assign dest_pred_val = comparison;
assign take_branch = (comparison && is_branch) || is_jump;

//Jump: Destination = Imm + rs1, link to dest
wire [27:0] branch_targ = curr_PC + signed_imm[27:0];
wire [27:0] jump_targ = signed_imm[27:0] + reg1_val[27:0];
assign new_PC = is_jump ? jump_targ : branch_targ;
assign int_return = is_jump && reg1_idx == (`NUM_REGS-1);

reg divi1_sign;
wire [31:0] divi1 = muli1;
wire [31:0] divi2 = muli2;
reg [31:0] divi2_l;

reg [31:0] div_res;
reg [63:0] div_shifter;
reg [4:0] div_counter;
reg busy_l;
reg div_complete;
wire [31:0] modulo = div_shifter[63:32];
wire is_div = pred_val && (is_ALU || is_Imm) && (alu_op == 10 || alu_op == 11);
assign busy = (is_div || busy_l) && !div_complete;
always @(posedge clk) begin
	if(rst) begin
		div_res <= 0;
		div_shifter <= 0;
		div_counter <= 0;
		busy_l <= 0;
		divi2_l <= 0;
		divi1_sign <= 0;
		div_complete <= 0;
	end else begin
		if(busy_l) begin
			div_res <= {div_res[30:0], div_shifter[62:31] >= divi2_l};
			if(div_shifter[62:31] >= divi2_l) begin
				div_shifter <= {div_shifter[62:31] - divi2_l, div_shifter[30:0], 1'b0};
			end else div_shifter <= {div_shifter[62:0], 1'b0};
			div_counter <= div_counter + 1;
			if(div_counter == 31) begin
				busy_l <= 0;
				div_complete <= 1;
			end
		end else begin
			if(is_div) begin
				div_counter <= 0;
				div_shifter <= {32'h0, divi1};
				div_res <= 0;
				divi2_l <= divi2;
				divi1_sign <= divi1[31];
				busy_l <= 1;
			end
		end
	end
end

endmodule
