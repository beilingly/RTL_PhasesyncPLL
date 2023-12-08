
`timescale 1s / 1fs

//**************************************************************
// PD_TOP module
//**************************************************************
module PD_TOP (
EN_PFD,
EN_SSPD,
NRST_PFD,
PRECHARGE,
REF_DTC,
VREF,
FBCKVD,
VSMP,
IPFD,
ISSPD,
VOUT
);

// io
input EN_PFD;
input EN_SSPD;
input NRST_PFD;
input PRECHARGE;
input REF_DTC;
input var real VREF;
input wire FBCKVD;
output real VSMP;
output real IPFD;
output real ISSPD;
output real VOUT;

PFD_CP 	U0_PFDCP (
.EN			(EN_PFD),
.NRST_PFD	(NRST_PFD),
.REF_PFD	(REF_DTC),
.FBCKVD		(FBCKVD),
.IPFD		(IPFD)
);

SSPD_CP U1_SSPDCP (
.EN			(EN_SSPD),
.VREF		(VREF),
.REF_SSPD	(REF_DTC),
.FBCKVD		(FBCKVD),
.VSMP		(VSMP),
.ISSPD      (ISSPD)
);

real itotal;

always @* begin
	itotal = IPFD+ISSPD;
end

LPF 	U3_LPF (
.PRECHARGE	(PRECHARGE),
.IIN		(itotal),
.VOUT       (VOUT)
);

// test for vctrl psd
real fs = 20e9;
integer fp;

initial fp = $fopen("./vctrl.txt");

always #(1/fs) begin
	$fstrobe(fp, "%3.15e %3.15e", $realtime, VOUT);
end

endmodule

//**************************************************************
// PFD&CP module
//**************************************************************
module PFD_CP (
EN,
NRST_PFD,
REF_PFD,
FBCKVD,
IPFD
);

// io
input EN;
input NRST_PFD;
input wire REF_PFD;
input wire FBCKVD;
output real IPFD;


// loop parameters
parameter real iCP = 150e-6; //80uA~5000uA
// parameter real iCP = 1600e-6; //80uA~5000uA

localparam s0 = 0;
localparam s1 = 1;
localparam s2 = 2;

// internal signal
reg [1:0] state; //PFD state
reg up;
reg dn;

// reset delay half ref cycle
reg nrst_dly;
always @ (posedge REF_PFD) begin
	nrst_dly <= NRST_PFD;
end

//PFD
always @ (negedge REF_PFD or negedge nrst_dly) begin
	if (!nrst_dly)
		state <= s0;
	else case (state)
		s0: state <= s2;
		s1: state <= s0;
		s2: state <= s2;
		default: state <= s0;
	endcase
end

always @ (negedge FBCKVD or negedge nrst_dly) begin
	if (!nrst_dly)
		state <= s0;
	else case (state)
		s0: state <= s1;
		s1: state <= s1;
		s2: state <= s0;
		default: state <= s0;
	endcase
end

always @* begin
	case (state)
		s0: begin up=0; dn=0; end
		s1: begin up=0; dn=1; end
		s2: begin up=1; dn=0; end
		default: begin up=0; dn=0; end
	endcase
end

//CP
always @* begin
	if (EN)
		case (state)
			s0: IPFD = 0;
			s1: IPFD = -iCP;
			s2: IPFD = iCP;
			default: IPFD = 0;
		endcase
	else
		IPFD = 0;
end

endmodule

//**************************************************************
// SSPD&CP module
//**************************************************************
module SSPD_CP (
EN,
VREF,
REF_SSPD,
FBCKVD,
VSMP,
ISSPD
);

// io
input EN;
input var real VREF;
input REF_SSPD;
input FBCKVD;
output real VSMP;
output real ISSPD;

// loop parameters
parameter real slope = 4e9;
parameter real gm = 200e-6;
// parameter real Tpulse = 670e-12; // BW 500k
parameter real Tpulse = 0.18e-9*4;

// internal signal
real falling_edge;
real vsmp_temp;
real vdiff;
real iout;
reg pulse;

// code begin
always @ (negedge REF_SSPD)
	falling_edge = $realtime;

always @ (negedge FBCKVD) begin
	vsmp_temp = ($realtime - falling_edge)*slope;
	VSMP = (vsmp_temp<1.8)? vsmp_temp: 
			(vsmp_temp<4e-9*slope)? 1.8: 0;
	vdiff = VSMP - VREF; // restrict by vslope voltage range
	iout = vdiff*gm;
end

always @* begin
	if (EN)
		ISSPD = iout * pulse; // only work when pulse is asserted
	else
		ISSPD = 0;
end

// sspd pulse generator
always @ (negedge REF_SSPD) begin
	pulse = 1'b1;
	#Tpulse;
	pulse = 1'b0;
end

// test for vsmp psd
real fs = 20e9;
integer fp1;

initial fp1 = $fopen("./vsmp.txt");

always #(1/fs) begin
	$fstrobe(fp1, "%3.15e %3.15e", $realtime, VSMP);
end

endmodule


//**************************************************************
// RC loop filter module
// R: 2k~66k
// C: 100p~300p
//**************************************************************
module LPF (
PRECHARGE,
IIN,
VOUT
);

// io
input PRECHARGE;
input var real IIN;
output real VOUT;

// internal signal
real fs; //LPF parameter
real Ts;
real vout;
real a0;
real a10;
real a11;
real b11;
real x1;
real x2;
real x3;
real x4;

real precharge;

// code begin
initial begin
	fs = 1000.0e9;
	Ts = 1.0/fs;

	// r1 = 20e3 c1 = 200e-12 fs = 1000G
	a0 = 0.00454545454545455;
	a10 = 11;
	a11 = -10.99999725;
	b11 = -0.99999725;
end

always @ (*) begin
	x1 = (~PRECHARGE)? a0*IIN + x2: 0;
	x3 = (~PRECHARGE)? x1 - b11*x4: 0;
	vout = (~PRECHARGE)? a10*x3 + a11*x4: 0;
	VOUT = PRECHARGE? precharge: (vout+precharge);
end

// precharge
initial precharge = 0;

always @ (posedge PRECHARGE) begin
	precharge <= 0.9;
end

always #(Ts) begin
	x2 <= x1;
	x4 <= x3;
end

endmodule

