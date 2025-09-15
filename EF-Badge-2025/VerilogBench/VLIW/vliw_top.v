`default_nettype none

module vliw_top (
	input clk,
	input rstn,
	inout [35:0] io
);

wire [35:0] io_out_vliw;
wire [35:0] io_oeb_vliw;

wire [35:0] designs_io_in = io;
assign io[0] = io_oeb_vliw[0] ? 1'bz : io_out_vliw[0];
assign io[1] = io_oeb_vliw[1] ? 1'bz : io_out_vliw[1];
assign io[2] = io_oeb_vliw[2] ? 1'bz : io_out_vliw[2];
assign io[3] = io_oeb_vliw[3] ? 1'bz : io_out_vliw[3];
assign io[4] = io_oeb_vliw[4] ? 1'bz : io_out_vliw[4];
assign io[5] = io_oeb_vliw[5] ? 1'bz : io_out_vliw[5];
assign io[6] = io_oeb_vliw[6] ? 1'bz : io_out_vliw[6];
assign io[7] = io_oeb_vliw[7] ? 1'bz : io_out_vliw[7];
assign io[8] = io_oeb_vliw[8] ? 1'bz : io_out_vliw[8];
assign io[9] = io_oeb_vliw[9] ? 1'bz : io_out_vliw[9];
assign io[10] = io_oeb_vliw[10] ? 1'bz : io_out_vliw[10];
assign io[11] = io_oeb_vliw[11] ? 1'bz : io_out_vliw[11];
assign io[12] = io_oeb_vliw[12] ? 1'bz : io_out_vliw[12];
assign io[13] = io_oeb_vliw[13] ? 1'bz : io_out_vliw[13];
assign io[14] = io_oeb_vliw[14] ? 1'bz : io_out_vliw[14];
assign io[15] = io_oeb_vliw[15] ? 1'bz : io_out_vliw[15];
assign io[16] = io_oeb_vliw[16] ? 1'bz : io_out_vliw[16];
assign io[17] = io_oeb_vliw[17] ? 1'bz : io_out_vliw[17];
assign io[18] = io_oeb_vliw[18] ? 1'bz : io_out_vliw[18];
assign io[19] = io_oeb_vliw[19] ? 1'bz : io_out_vliw[19];
assign io[20] = io_oeb_vliw[20] ? 1'bz : io_out_vliw[20];
assign io[21] = io_oeb_vliw[21] ? 1'bz : io_out_vliw[21];
assign io[22] = io_oeb_vliw[22] ? 1'bz : io_out_vliw[22];
assign io[23] = io_oeb_vliw[23] ? 1'bz : io_out_vliw[23];
assign io[24] = io_oeb_vliw[24] ? 1'bz : io_out_vliw[24];
assign io[25] = io_oeb_vliw[25] ? 1'bz : io_out_vliw[25];
assign io[26] = io_oeb_vliw[26] ? 1'bz : io_out_vliw[26];
assign io[27] = io_oeb_vliw[27] ? 1'bz : io_out_vliw[27];
assign io[28] = io_oeb_vliw[28] ? 1'bz : io_out_vliw[28];
assign io[29] = io_oeb_vliw[29] ? 1'bz : io_out_vliw[29];
assign io[30] = io_oeb_vliw[30] ? 1'bz : io_out_vliw[30];
assign io[31] = io_oeb_vliw[31] ? 1'bz : io_out_vliw[31];
assign io[32] = io_oeb_vliw[32] ? 1'bz : io_out_vliw[32];
assign io[33] = io_oeb_vliw[33] ? 1'bz : io_out_vliw[33];
assign io[34] = io_oeb_vliw[34] ? 1'bz : io_out_vliw[34];
assign io[35] = io_oeb_vliw[35] ? 1'bz : io_out_vliw[35];

`define NUM_REGS 64
`define REG_IDX ($clog2(`NUM_REGS)-1)

wire rst_eu;
wire [27:0] curr_PC;

wire [`REG_IDX:0] reg1_idx0;
wire [`REG_IDX:0] reg2_idx0;
wire [31:0]       dest_val0;
wire [1:0]        dest_mask0;
wire [`REG_IDX:0] dest_idx0;
wire [2:0]        pred_idx0;
wire [2:0]        dest_pred0;
wire              dest_pred_val0;
wire [31:0]       loadstore_address0;
wire              is_load0;
wire              is_store0;
wire              sign_extend0;
wire [1:0]        loadstore_size0;
wire              take_branch0;
wire [27:0]       new_PC0;
wire              eu0_busy;
wire [41:0]       eu0_instruction;
wire [31:0]       reg1_val0;
wire [31:0]       reg2_val0;
wire              pred_val0;
wire              int_return0;

wire [`REG_IDX:0] reg1_idx1;
wire [`REG_IDX:0] reg2_idx1;
wire [31:0]       dest_val1;
wire [1:0]        dest_mask1;
wire [`REG_IDX:0] dest_idx1;
wire [2:0]        pred_idx1;
wire [2:0]        dest_pred1;
wire              dest_pred_val1;
wire [31:0]       loadstore_address1;
wire              is_load1;
wire              is_store1;
wire              sign_extend1;
wire [1:0]        loadstore_size1;
wire              take_branch1;
wire [27:0]       new_PC1;
wire              eu1_busy;
wire [41:0]       eu1_instruction;
wire [31:0]       reg1_val1;
wire [31:0]       reg2_val1;
wire              pred_val1;
wire              int_return1;

wire [`REG_IDX:0] reg1_idx2;
wire [`REG_IDX:0] reg2_idx2;
wire [31:0]       dest_val2;
wire [1:0]        dest_mask2;
wire [`REG_IDX:0] dest_idx2;
wire [2:0]        pred_idx2;
wire [2:0]        dest_pred2;
wire              dest_pred_val2;
wire [31:0]       loadstore_address2;
wire              is_load2;
wire              is_store2;
wire              sign_extend2;
wire [1:0]        loadstore_size2;
wire              take_branch2;
wire [27:0]       new_PC2;
wire              eu2_busy;
wire [41:0]       eu2_instruction;
wire [31:0]       reg1_val2;
wire [31:0]       reg2_val2;
wire              pred_val2;
wire              int_return2;

wire cache_hit;
wire cache_invalidate;
wire [127:0] cache_entry;
wire [127:0] cache_new_entry;
wire [27:0] cache_PC;
wire cache_rst;
wire cache_entry_valid;

vliw vliw(
	.clk(clk),
	.rstn(rstn),
	.io_in(designs_io_in),
	.io_out(io_out_vliw),
	.io_oeb(io_oeb_vliw),
	.custom_settings(5'h11),
	
	.rst_eu(rst_eu),
	.curr_PC(curr_PC),
	
	.reg1_idx0(reg1_idx0),
	.reg2_idx0(reg2_idx0),
	.dest_val0(dest_val0),
	.dest_mask0(dest_mask0),
	.dest_idx0(dest_idx0),
	.pred_idx0(pred_idx0),
	.dest_pred0(dest_pred0),
	.dest_pred_val0(dest_pred_val0),
	.loadstore_address0(loadstore_address0),
	.is_load0(is_load0),
	.is_store0(is_store0),
	.sign_extend0(sign_extend0),
	.loadstore_size0(loadstore_size0),
	.take_branch0(take_branch0),
	.new_PC0(new_PC0),
	.eu0_busy(eu0_busy),
	.eu0_instruction(eu0_instruction),
	.reg1_val0(reg1_val0),
	.reg2_val0(reg2_val0),
	.pred_val0(pred_val0),
	.int_return0(int_return0),
	
	.reg1_idx1(reg1_idx1),
	.reg2_idx1(reg2_idx1),
	.dest_val1(dest_val1),
	.dest_mask1(dest_mask1),
	.dest_idx1(dest_idx1),
	.pred_idx1(pred_idx1),
	.dest_pred1(dest_pred1),
	.dest_pred_val1(dest_pred_val1),
	.loadstore_address1(loadstore_address1),
	.is_load1(is_load1),
	.is_store1(is_store1),
	.sign_extend1(sign_extend1),
	.loadstore_size1(loadstore_size1),
	.take_branch1(take_branch1),
	.new_PC1(new_PC1),
	.eu1_busy(eu1_busy),
	.eu1_instruction(eu1_instruction),
	.reg1_val1(reg1_val1),
	.reg2_val1(reg2_val1),
	.pred_val1(pred_val1),
	.int_return1(int_return1),
	
	.reg1_idx2(reg1_idx2),
	.reg2_idx2(reg2_idx2),
	.dest_val2(dest_val2),
	.dest_mask2(dest_mask2),
	.dest_idx2(dest_idx2),
	.pred_idx2(pred_idx2),
	.dest_pred2(dest_pred2),
	.dest_pred_val2(dest_pred_val2),
	.loadstore_address2(loadstore_address2),
	.is_load2(is_load2),
	.is_store2(is_store2),
	.sign_extend2(sign_extend2),
	.loadstore_size2(loadstore_size2),
	.take_branch2(take_branch2),
	.new_PC2(new_PC2),
	.eu2_busy(eu2_busy),
	.eu2_instruction(eu2_instruction),
	.reg1_val2(reg1_val2),
	.reg2_val2(reg2_val2),
	.pred_val2(pred_val2),
	.int_return2(int_return2),
	
	.cache_hit(cache_hit),
	.cache_invalidate(cache_invalidate),
	.cache_entry(cache_entry),
	.cache_new_entry(cache_new_entry),
	.cache_PC(cache_PC),
	.cache_rst(cache_rst),
	.cache_entry_valid(cache_entry_valid)
);

icache icache(
    .clk(clk),
    .rst(cache_rst),
    .curr_PC(cache_PC),
    .cache_entry(cache_entry),
    .cache_hit(cache_hit),
    .new_entry(cache_new_entry),
    .entry_valid(cache_entry_valid),
    .invalidate(cache_invalidate)
);

execution_unit eu0(
    .clk(clk),
    .rst(rst_eu),
    .curr_PC(curr_PC),
    
    .instruction(eu0_instruction),
    .reg1_idx(reg1_idx0),
    .reg2_idx(reg2_idx0),
    .reg1_val(reg1_val0),
    .reg2_val(reg2_val0),
    .dest_val(dest_val0),
    .dest_mask(dest_mask0),
    .dest_idx(dest_idx0),
    .pred_idx(pred_idx0),
    .pred_val(pred_val0),
    .dest_pred(dest_pred0),
    .dest_pred_val(dest_pred_val0),
    .loadstore_address(loadstore_address0),
    .is_load(is_load0),
    .is_store(is_store0),
    .sign_extend(sign_extend0),
    .loadstore_size(loadstore_size0),
    .take_branch(take_branch0),
    .new_PC(new_PC0),
    .busy(eu0_busy),
    .int_return(int_return0)
);

execution_unit eu1(
    .clk(clk),
    .rst(rst_eu),
    .curr_PC(curr_PC),
    
    .instruction(eu1_instruction),
    .reg1_idx(reg1_idx1),
    .reg2_idx(reg2_idx1),
    .reg1_val(reg1_val1),
    .reg2_val(reg2_val1),
    .dest_val(dest_val1),
    .dest_mask(dest_mask1),
    .dest_idx(dest_idx1),
    .pred_idx(pred_idx1),
    .pred_val(pred_val1),
    .dest_pred(dest_pred1),
    .dest_pred_val(dest_pred_val1),
    .loadstore_address(loadstore_address1),
    .is_load(is_load1),
    .is_store(is_store1),
    .sign_extend(sign_extend1),
    .loadstore_size(loadstore_size1),
    .take_branch(take_branch1),
    .new_PC(new_PC1),
    .busy(eu1_busy),
    .int_return(int_return1)
);

execution_unit eu2(
    .clk(clk),
    .rst(rst_eu),
    .curr_PC(curr_PC),
    
    .instruction(eu2_instruction),
    .reg1_idx(reg1_idx2),
    .reg2_idx(reg2_idx2),
    .reg1_val(reg1_val2),
    .reg2_val(reg2_val2),
    .dest_val(dest_val2),
    .dest_mask(dest_mask2),
    .dest_idx(dest_idx2),
    .pred_idx(pred_idx2),
    .pred_val(pred_val2),
    .dest_pred(dest_pred2),
    .dest_pred_val(dest_pred_val2),
    .loadstore_address(loadstore_address2),
    .is_load(is_load2),
    .is_store(is_store2),
    .sign_extend(sign_extend2),
    .loadstore_size(loadstore_size2),
    .take_branch(take_branch2),
    .new_PC(new_PC2),
    .busy(eu2_busy),
    .int_return(int_return2)
);

endmodule
