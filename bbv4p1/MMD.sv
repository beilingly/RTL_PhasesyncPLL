//----------------------------------------------------------------------------
// Revision History:
//----------------------------------------------------------------------------
// 1.0  Guopei Chen  2019/06/14
//      Create the MMD module based on time_adv_enev and time_adv_odd
//		https://blog.csdn.net/moon9999/article/details/75020355
//
//----------------------------------------------------------------------------

`timescale 1s/1fs

//----------------------------------------------------------------------------
// Module definition
//----------------------------------------------------------------------------
module MMD(
NARST,
CKV,
DIVNUM,
CKVD
);

//----------------------------------------------------------------------------
// Parameter declarations
//----------------------------------------------------------------------------
reg  [8:0] counter;

//----------------------------------------------------------------------------
// IO
//----------------------------------------------------------------------------

// inputs
input CKV;
input NARST;
input [8:0] DIVNUM;

// outputs
output reg CKVD; 

always @ (posedge CKV or negedge NARST) begin
	if (!NARST) begin
		counter <= 0;
	end
	else if (counter >= DIVNUM -1) begin
		counter <= 0;
	end
	else begin
		counter <= counter + 1;
	end
end

always @ (posedge CKV or negedge NARST) begin
	if (!NARST) begin
		//reset
		CKVD <= 1'b0;
	end
	else if (counter <= $floor(($unsigned(DIVNUM)+0.0)/2)-1) begin
		CKVD <= 1'b1;
	end
	else begin //if (counter == DivNum -1) begin
		CKVD <= 1'b0;
	end
end // always @ (posedge clk or negedge nrst)

//----------------------------------------------------------------------------
// endmodule
//----------------------------------------------------------------------------	
endmodule