`timescale 1s / 1fs

module TDC (
NRST,
CLKX,
CLKY,
CODE
);

parameter delayx = 9.5e-12;

input NRST;
input CLKX;
input CLKY;
output [5:0] CODE;


reg [63:0] code_temp;
// delay line
genvar geni;
wire [63:0] dlyx;

assign #delayx dlyx[0] = CLKX;
generate
	for (geni=1; geni<=63; geni=geni+1) begin
		assign #delayx dlyx[geni] = dlyx[geni-1];
	end
	
	for (geni=0; geni<=63; geni=geni+1) begin
		always @ (negedge NRST or posedge CLKY) begin
			if (!NRST) code_temp[geni] <= 0;
			else code_temp[geni] <= dlyx[geni];
		end
	end
endgenerate

// TDC decoder
TDCDECODER U0_TDCDECODER (
.IN64BIT(code_temp),
.OUT6BIT(CODE)
);

endmodule