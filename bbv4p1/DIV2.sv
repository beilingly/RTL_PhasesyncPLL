`timescale 1s/1fs

//----------------------------------------------------------------------------
// Module definition
//----------------------------------------------------------------------------
module DIV2(
CKV,
CKD2
);

//----------------------------------------------------------------------------
// IO
//----------------------------------------------------------------------------

// inputs
input CKV;

// outputs
output reg CKD2; 

// pre div2
initial CKD2 = 0;

always @ (posedge CKV) begin
		CKD2 <= ~CKD2;
end

//----------------------------------------------------------------------------
// endmodule
//----------------------------------------------------------------------------	
endmodule

module prediv (
CKV,
SEL,
CKD2,
CKVCNT
);

input CKV;
input SEL;

output CKD2;
output CKVCNT;

wire CKD4;

DIV2 U0_div2 (.CKV(CKV), .CKD2(CKD2));
DIV2 U1_div2 (.CKV(CKD2), .CKD2(CKD4));

assign CKVCNT = SEL? CKD4: CKD2;

endmodule