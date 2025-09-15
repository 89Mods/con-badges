module AS6C6416(
	input [21:0] A,
	inout [15:0] IO,
	input CEb,
	input CE2,
	input LBb,
	input UBb,
	input OEb,
	input WEb
);

wire chip_select = !CEb && CE2;

reg [15:0] memory [4194303:0];

initial begin
	for(integer i = 0; i < 4194304; i++) begin
		memory[i] = $random();
	end
	$readmemh("fastram_init.txt", memory);
end

assign IO = chip_select && !OEb && WEb ? {UBb ? 8'hzz : memory[A][15:8], LBb ? 8'hzz : memory[A][7:0]} : 16'hzzzz;

always @(posedge WEb or negedge chip_select) begin
	if((!chip_select && !WEb) || (chip_select && WEb)) begin
		if(!LBb) memory[A][7:0] <= IO[7:0];
		if(!UBb) memory[A][15:8] <= IO[15:8];
	end
end

endmodule
