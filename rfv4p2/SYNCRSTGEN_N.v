// -------------------------------------------------------
// Module Name: SYNCRSTGEN
// Function: generate synchronous reset
// Author: Yang Yumeng Date: 4/2 2022
// Version: v1p0, cp from BBPLL202108
// -------------------------------------------------------
module SYNCRSTGEN_N (
CLK,
NARST,
NRST,
NRST1,
NRST2
);

input CLK;
input NARST;
output NRST;
output NRST1;
output NRST2;

reg [2:0] rgt;

assign NRST = rgt[2];
assign NRST1 = ~(rgt[1] & (~rgt[2]));
assign NRST2 = ~(rgt[0] & (~rgt[2]));

always @ (negedge CLK or negedge NARST) begin
	if (!NARST) begin
		rgt <= 3'b000;
	end else begin
		rgt <= {rgt[1:0], 1'b1};
	end
end

endmodule