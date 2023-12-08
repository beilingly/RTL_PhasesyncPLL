`define M_PI 3.1415926
// -------------------------------------------------------
// Module Name: DTC_NL
// Function: DTC with non-linear
// Author: Yang Yumeng Date: 1/10 2022
// Version: v1p0
// -------------------------------------------------------
`timescale 1s / 1fs

module DTC (
CKIN,
CKOUT,
DTCDCW
);

input [11:0] DTCDCW;
input CKIN;
output CKOUT;

// dtc delay define
parameter real dtc_ofst = 20e-12;
// parameter real dtc_ofst = 0;
parameter real dtc_res = 500e-15;
real dtc_delay;

// // white noise, reference freq 200M
// integer seed1;
// localparam real	WHITE_N	= -120.0;
// localparam real Sigma_Tpp = 5e-9/(2.0*`M_PI)*(((10.0**(WHITE_N/10.0))*200e6)**0.5); // jitter
// real tpp;

// // nonlinear delay
// integer fp_r;
// integer freturn;
// integer index;
// integer inl_dealy_mem [0:4095];


// DTC delay logic
// detect and delay the falling edge
// assign dtc_delay = (dtc_ofst+dtc_res*$unsigned(DTCDCW)) + (dtc_res*5*$signed(inl_dealy_mem[DTCDCW])*(2.0**-16));
// assign dtc_delay = tpp + (dtc_ofst+dtc_res*$unsigned(DTCDCW));
assign dtc_delay = (dtc_ofst+dtc_res*$unsigned(DTCDCW));

assign #dtc_delay ckin_delay = CKIN;
assign CKOUT = ckin_delay & CKIN; // make delay for posedge

// // delay noise generate
// initial seed1 = 7;
// always @ (posedge CKIN) begin
	// tpp = $dist_normal(seed1, 0, $rtoi(Sigma_Tpp*1e18))*1e-18;		// jitter
// end

// // load nonlinear delay
// initial begin
	// index = 0;
	// fp_r = $fopen("D:/Project/OFM/data/dtcnonlinear.txt", "r");
	// while(! $feof(fp_r)) begin
		// freturn = $fscanf(fp_r, "%d", inl_dealy_mem[index]);
		// // $display("%d::::%f", index, $signed(inl_dealy_mem[index])*(2.0**-16));
		// index = index + 1;
	// end
	// $display("load DTC INL data successfully !");
	// $fclose(fp_r);
// end

endmodule