module clkdiv #(parameter DIV = 3)(
	input clk,
	input en,
	output xclk
);

reg [7:0] counter = 0;
//assign xclk = counter > (((DIV-1)/2)-((DIV-1)/4));
assign xclk = counter > ((DIV-1)/2);
always @(posedge clk) begin
	if(en) counter <= counter == (DIV-1) ? 8'h00 : counter + 1;
end

endmodule
