// -------------------------------------------------------
// Module Name: TDCDECODER
// Function: pure combinational logic
// Author: Yang Yumeng Date: 4/7 2022
// Version: v1p0
// -------------------------------------------------------
module TDCDECODER (
IN64BIT,
OUT6BIT
);

input [63:0] IN64BIT;
output [5:0] OUT6BIT;

// wire [63:0] data64;
// wire [31:0] data32;
// wire [15:0] data16;
// wire [7:0] data8;
// wire [3:0] data4;
// wire [1:0] data2;
// wire [5:0] tdccnt;

// assign data64 = ~IN64BIT;
// assign tdccnt[5] = ~|data64[31:0];
// assign data32 = tdccnt[5] ? data64[63:32]: data64[31:0];
// assign tdccnt[4] = ~|data32[15:0];
// assign data16 = tdccnt[4] ? data32[31:16]: data32[15:0];
// assign tdccnt[3] = ~|data16[7:0];
// assign data8 = tdccnt[3] ? data16[15:8]: data16[7:0];
// assign tdccnt[2] = ~|data8[3:0];
// assign data4 = tdccnt[2] ? data8[7:4]: data8[3:0];
// assign tdccnt[1] = ~|data4[1:0];
// assign data2 = tdccnt[1] ? data4[3:2]: data4[1:0];
// assign tdccnt[0] = ~data2[0];

// assign OUT6BIT = 63 - tdccnt;

integer i;
integer sum;
always @* begin
	sum = 0;
	for (i=0; i<=63; i=i+1) begin
		sum = sum + IN64BIT[i];
	end
end

assign OUT6BIT = sum;

endmodule