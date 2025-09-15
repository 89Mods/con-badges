module icache(
	input [27:0] curr_PC,
	output [127:0] cache_entry,
	output cache_hit,
	
	input [127:0] new_entry,
	input entry_valid,
	
	input invalidate,
	input clk,
	input rst
);

reg [127:0] cache_packs [31:0];
reg [27:0] cache_addrs [31:0];

reg [5:0] hit_cache_entry;
always @(*) begin
	if(cache_addrs[0] == curr_PC) hit_cache_entry = 0;
	else if(cache_addrs[1] == curr_PC) hit_cache_entry = 1;
	else if(cache_addrs[2] == curr_PC) hit_cache_entry = 2;
	else if(cache_addrs[3] == curr_PC) hit_cache_entry = 3;
	else if(cache_addrs[4] == curr_PC) hit_cache_entry = 4;
	else if(cache_addrs[5] == curr_PC) hit_cache_entry = 5;
	else if(cache_addrs[6] == curr_PC) hit_cache_entry = 6;
	else if(cache_addrs[7] == curr_PC) hit_cache_entry = 7;
	else if(cache_addrs[8] == curr_PC) hit_cache_entry = 8;
	else if(cache_addrs[9] == curr_PC) hit_cache_entry = 9;
	else if(cache_addrs[10] == curr_PC) hit_cache_entry = 10;
	else if(cache_addrs[11] == curr_PC) hit_cache_entry = 11;
	else if(cache_addrs[12] == curr_PC) hit_cache_entry = 12;
	else if(cache_addrs[13] == curr_PC) hit_cache_entry = 13;
	else if(cache_addrs[14] == curr_PC) hit_cache_entry = 14;
	else if(cache_addrs[15] == curr_PC) hit_cache_entry = 15;
	else if(cache_addrs[16] == curr_PC) hit_cache_entry = 16;
	else if(cache_addrs[17] == curr_PC) hit_cache_entry = 17;
	else if(cache_addrs[18] == curr_PC) hit_cache_entry = 18;
	else if(cache_addrs[19] == curr_PC) hit_cache_entry = 19;
	else if(cache_addrs[20] == curr_PC) hit_cache_entry = 20;
	else if(cache_addrs[21] == curr_PC) hit_cache_entry = 21;
	else if(cache_addrs[22] == curr_PC) hit_cache_entry = 22;
	else if(cache_addrs[23] == curr_PC) hit_cache_entry = 23;
	else if(cache_addrs[24] == curr_PC) hit_cache_entry = 24;
	else if(cache_addrs[25] == curr_PC) hit_cache_entry = 25;
	else if(cache_addrs[26] == curr_PC) hit_cache_entry = 26;
	else if(cache_addrs[27] == curr_PC) hit_cache_entry = 27;
	else if(cache_addrs[28] == curr_PC) hit_cache_entry = 28;
	else if(cache_addrs[29] == curr_PC) hit_cache_entry = 29;
	else if(cache_addrs[30] == curr_PC) hit_cache_entry = 30;
	else if(cache_addrs[31] == curr_PC) hit_cache_entry = 31;
	else hit_cache_entry = 32;
end
assign cache_hit = !hit_cache_entry[5];
assign cache_entry = cache_packs[hit_cache_entry];

reg [15:0] rng;

wire [15:0] rng_1 = rng ^ {7'h00, rng[15:7]};
wire [15:0] rng_2 = rng_1 ^ {rng_1[6:0], 9'h000};
wire [15:0] rng_3 = rng_2 ^ {13'h0000, rng_2[15:14]};
wire [4:0] random_entry = {rng[13], rng[12], rng[10], rng[7], rng[3]};

always @(posedge clk) begin
	if(rst || invalidate) begin
		if(rst) rng <= 16'hABCD;
		cache_addrs[0] <= 28'hFFFFFFF; cache_addrs[1] <= 28'hFFFFFFF; cache_addrs[2] <= 28'hFFFFFFF; cache_addrs[3] <= 28'hFFFFFFF;
		cache_addrs[4] <= 28'hFFFFFFF; cache_addrs[5] <= 28'hFFFFFFF; cache_addrs[6] <= 28'hFFFFFFF; cache_addrs[7] <= 28'hFFFFFFF;
		cache_addrs[8] <= 28'hFFFFFFF; cache_addrs[9] <= 28'hFFFFFFF; cache_addrs[10] <= 28'hFFFFFFF; cache_addrs[11] <= 28'hFFFFFFF;
		cache_addrs[12] <= 28'hFFFFFFF; cache_addrs[13] <= 28'hFFFFFFF; cache_addrs[14] <= 28'hFFFFFFF; cache_addrs[15] <= 28'hFFFFFFF;
		cache_addrs[16] <= 28'hFFFFFFF; cache_addrs[17] <= 28'hFFFFFFF; cache_addrs[18] <= 28'hFFFFFFF; cache_addrs[19] <= 28'hFFFFFFF;
		cache_addrs[20] <= 28'hFFFFFFF; cache_addrs[21] <= 28'hFFFFFFF; cache_addrs[22] <= 28'hFFFFFFF; cache_addrs[23] <= 28'hFFFFFFF;
		cache_addrs[24] <= 28'hFFFFFFF; cache_addrs[25] <= 28'hFFFFFFF; cache_addrs[26] <= 28'hFFFFFFF; cache_addrs[27] <= 28'hFFFFFFF;
		cache_addrs[28] <= 28'hFFFFFFF; cache_addrs[29] <= 28'hFFFFFFF; cache_addrs[30] <= 28'hFFFFFFF; cache_addrs[31] <= 28'hFFFFFFF;
	end else if(entry_valid) begin
		cache_packs[random_entry] <= new_entry;
		cache_addrs[random_entry] <= curr_PC;
	end else begin
		rng <= rng_3;
	end
end

`ifdef SIM
wire [127:0] p0 = cache_packs[0];
wire [127:0] p1 = cache_packs[1];
wire [127:0] p2 = cache_packs[2];
wire [127:0] p3 = cache_packs[3];
wire [127:0] p4 = cache_packs[4];
wire [127:0] p5 = cache_packs[5];
wire [127:0] p6 = cache_packs[6];
wire [127:0] p7 = cache_packs[7];
wire [127:0] p8 = cache_packs[8];
wire [127:0] p9 = cache_packs[9];
wire [127:0] p10 = cache_packs[10];
wire [127:0] p11 = cache_packs[11];
wire [127:0] p12 = cache_packs[12];
wire [127:0] p13 = cache_packs[13];
wire [127:0] p14 = cache_packs[14];
wire [127:0] p15 = cache_packs[15];
wire [127:0] p16 = cache_packs[16];
wire [127:0] p17 = cache_packs[17];
wire [127:0] p18 = cache_packs[18];
wire [127:0] p19 = cache_packs[19];
wire [127:0] p20 = cache_packs[20];
wire [127:0] p21 = cache_packs[21];
wire [127:0] p22 = cache_packs[22];
wire [127:0] p23 = cache_packs[23];
wire [127:0] p24 = cache_packs[24];
wire [127:0] p25 = cache_packs[25];
wire [127:0] p26 = cache_packs[26];
wire [127:0] p27 = cache_packs[27];
wire [127:0] p28 = cache_packs[28];
wire [127:0] p29 = cache_packs[29];
wire [127:0] p30 = cache_packs[30];
wire [127:0] p31 = cache_packs[31];

wire [27:0] a0 = cache_addrs[0];
wire [27:0] a1 = cache_addrs[1];
wire [27:0] a2 = cache_addrs[2];
wire [27:0] a3 = cache_addrs[3];
wire [27:0] a4 = cache_addrs[4];
wire [27:0] a5 = cache_addrs[5];
wire [27:0] a6 = cache_addrs[6];
wire [27:0] a7 = cache_addrs[7];
wire [27:0] a8 = cache_addrs[8];
wire [27:0] a9 = cache_addrs[9];
wire [27:0] a10 = cache_addrs[10];
wire [27:0] a11 = cache_addrs[11];
wire [27:0] a12 = cache_addrs[12];
wire [27:0] a13 = cache_addrs[13];
wire [27:0] a14 = cache_addrs[14];
wire [27:0] a15 = cache_addrs[15];
wire [27:0] a16 = cache_addrs[16];
wire [27:0] a17 = cache_addrs[17];
wire [27:0] a18 = cache_addrs[18];
wire [27:0] a19 = cache_addrs[19];
wire [27:0] a20 = cache_addrs[20];
wire [27:0] a21 = cache_addrs[21];
wire [27:0] a22 = cache_addrs[22];
wire [27:0] a23 = cache_addrs[23];
wire [27:0] a24 = cache_addrs[24];
wire [27:0] a25 = cache_addrs[25];
wire [27:0] a26 = cache_addrs[26];
wire [27:0] a27 = cache_addrs[27];
wire [27:0] a28 = cache_addrs[28];
wire [27:0] a29 = cache_addrs[29];
wire [27:0] a30 = cache_addrs[30];
wire [27:0] a31 = cache_addrs[31];
`endif

endmodule
