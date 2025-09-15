module IS61WV102416(
	input [19:0] A,
	inout [15:0] IO,
	input CEb,
	input LBb,
	input UBb,
	input OEb,
	input WEb
);

reg [15:0] memory [1048575:0];

initial begin
	for(integer i = 0; i < 1048576; i++) begin
		memory[i] = $random();
	end
end

assign IO = !CEb && !OEb && WEb ? {UBb ? 8'hzz : memory[A][15:8], LBb ? 8'hzz : memory[A][7:0]} : 16'hzzzz;

always @(posedge WEb or posedge CEb) begin
	if((CEb && !WEb) || (!CEb && WEb)) begin
		if(!LBb) memory[A][7:0] <= IO[7:0];
		if(!UBb) memory[A][15:8] <= IO[15:8];
	end
end

endmodule
