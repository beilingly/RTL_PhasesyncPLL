`timescale 1s / 1fs

module LOGEN_MIS (
CKV,
REF,
LO_DIV,
LO_I,
LO_Q,
LO_STATE
);

input CKV;
input REF;
input [2:0] LO_DIV; // 2/4/8/16/32/64/128/256
output reg LO_I;
output reg LO_Q;
output reg [1:0] LO_STATE;

integer cnt;
integer divnum;

// parameter
parameter real dcmis = 50; // 49~51%
parameter real pmis = 0; // -2~+2 deg
parameter real fref = 100e6;
// parameter real fcwlo = 50.125*2/4;
parameter real fcwlo = 50.27*2/32;

reg loi_t1;
reg loq_t1;
reg LO_I0;


// LO generator
assign divnum = 1<<(LO_DIV+1);

// always @ (posedge CKV) begin
// 	if (cnt < divnum - 1) cnt = cnt + 1;
// 	else cnt = 0;
// 	if (cnt < divnum/2) begin
// 		LO_I0 = 0;
// 	end else begin
// 		LO_I0 = 1;
// 	end
// end

// LO div5
always @ (posedge CKV) begin
	if (cnt < 5 - 1) cnt = cnt + 1;
	else cnt = 0;
	if (cnt < 5/2) begin
		LO_I0 = 0;
	end else begin
		LO_I0 = 1;
	end
end

// duty-cycle mismatch
real dcdelay0 = 1.0/(fref*fcwlo)*(dcmis*0.01);
real dcdelay1 = 1.0/(fref*fcwlo)*(1.0 - dcmis*0.01);
real pdelay0 = 1.0/(fref*fcwlo)*(pmis/360);
always @ (posedge LO_I0) begin
	LO_I = 1;
	# (dcdelay0/2 + pdelay0);
	LO_Q = 1;
	# (dcdelay0/2 - pdelay0);
	LO_I = 0;
	# (dcdelay1/2 + pdelay0);
	LO_Q = 0;
end


// LO sampler
always @ (posedge REF) begin
	{loi_t1, loq_t1} <= {LO_I, LO_Q};
end

always @ (negedge REF) begin
	LO_STATE <= {loi_t1, loq_t1};
end

endmodule