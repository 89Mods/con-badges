`timescale 1ns/100ps

module gal(
	input clk,
	input BE0b,
	input BE1b,
	input BE2b,
	input BE3b,
	input WR,
	input ADS,
	input A31,
	input A13,
	input A10,
	input RESET,
	input MIO,
	
	output reg READYb,
	output reg STATE0,
	output reg ATAOEb,
	output ATACS0b,
	output reg CPLDCSb,
	output A1,
	output reg ROMCSb,
	output reg STATE1,
	output RAMCEb,
	output reg WEb
);

//assign WEb = !WR | RESET | !MIO & !A13 & !READYb | MIO & !READYb;
assign A1 = BE0b & BE1b;

assign ATACS0b = !A10 | RESET | MIO | !MIO & A13;
assign RAMCEb = !MIO | A31 | ADS & WR | RESET;

always @(posedge clk) begin
	ROMCSb <= !MIO | !A31 | !READYb & !STATE0 & !STATE1 | RESET;
	CPLDCSb <= MIO | !A13 | !A10 | !READYb & !STATE0 & !STATE1 | WR & ADS & !STATE0 | RESET;
	ATAOEb <= WR | RESET | MIO | !MIO & A13 | !READYb;
	WEb <= !WR | MIO & ADS | RESET | !MIO & !READYb;
	
	STATE0 <= !MIO & !ADS | MIO & A31 & !ADS;
	STATE1 <= STATE0;
	READYb <= !MIO & !ADS | MIO & A31 & !ADS | STATE1 | STATE0;
end

endmodule
