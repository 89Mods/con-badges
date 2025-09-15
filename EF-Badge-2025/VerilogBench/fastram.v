module fastram (
	input [11:0] address,
	input clock,
	input [15:0] data,
	input wren,
	output reg [15:0] q = 0,
	input [1:0] byteena
);

reg [15:0] memory [4095:0];

always @(posedge clock) begin
	q <= memory[address];
	if(wren && byteena[0]) memory[address][7:0] <= data[7:0];
	if(wren && byteena[1]) memory[address][15:8] <= data[15:8];
end

initial begin
	for(integer i = 0; i < 4096; i++) begin
		memory[i] = $random();
	end
end

endmodule
