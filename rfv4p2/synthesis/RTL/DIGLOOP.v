`timescale 1s / 1fs

// word width define
`define WI 9
`define WF 26
`define WFPHASE 16
`define OTW_L 9
`define DTC_L 12

// -------------------------------------------------------
// Module Name: LFSR32
// Function: 32 bit LFSR used in sdm for dither
// Author: Yang Yumeng Date: 6/26 2021
// Version: v1p0, cp from BBPLL202108
// -------------------------------------------------------
module LFSR32 (
CLK,
NRST,
EN,
DO,
URN26
);

input CLK;
input NRST;
input EN;
output DO;
output [`WF-1:0] URN26;

wire lfsr_fb;
reg [32:1] lfsr;

assign DO = EN? lfsr[1]: 1'b0;
assign URN26 = EN? lfsr[26:1]: 1'b0;

// create feedback polynomials
assign lfsr_fb = lfsr[32] ^~ lfsr[22] ^~ lfsr[2] ^~ lfsr[1];

always @(posedge CLK or negedge NRST) begin
	if(!NRST)
		lfsr <= 32'b1;
	else if (EN) begin
		lfsr <= {lfsr[31:1], lfsr_fb};
	end else begin
		lfsr <= 32'b1;
	end
end

endmodule

module LFSR32_initial (
CLK,
NRST,
EN,
DO,
INI,
lfsr
);

input CLK;
input NRST;
input EN;
input [31:0]INI;
output DO;
output [32:1]lfsr;
wire lfsr_fb;
reg [32:1] lfsr;

assign DO = EN? lfsr[1]: 1'b0;

// create feedback polynomials
assign lfsr_fb = lfsr[32] ^~ lfsr[22] ^~ lfsr[2] ^~ lfsr[1];

always @(posedge CLK or negedge NRST) begin
	if (!NRST) begin
		lfsr <= INI;
	end else if (EN) begin
		lfsr <= {lfsr[31:1], lfsr_fb};
	end else begin
		lfsr <= INI;
	end
end

endmodule
 
// -------------------------------------------------------
// Module Name: DSM_MESH11_PDS
// Function: modulator for mmd ctrl word
// Author: Yan Angxiao Date: 9th. Mar. 2023
// Version: v1p0 from KAIST
// -------------------------------------------------------
module DSM_MESH11_PDS2 (
CLK,
NRST,
EN,
PDS_EN,
DN_EN,
DN_WEIGHT,
IN,
OUT,
PHE
);

// io
input CLK;
input NRST;
input EN;
input PDS_EN;
input DN_EN;
input [4:0] DN_WEIGHT; // dither weight, left shift, 0-31, default is 12
input [`WF-1:0] IN;
output reg [3:0] OUT; // sfix, 2-order (-3 to 4)
output [`WF+1:0] PHE; // ufix, 0<x<2
reg signed [`WF+2:0] PHE_Full;


// internal signal
wire [`WF:0] sum1_temp;
wire [`WF:0] sum2_temp;

wire [`WF+2:0] sum1_temp_d;
wire [`WF-1:0] sum1;
wire [`WF-1:0] sum2;
reg [`WF-1:0] sum1_reg;
reg [`WF-1:0] sum2_reg;
wire signed [1:0] ca1;
wire signed [2:0] ca2;//[-1,2]
reg signed [2:0] ca2_reg; // output combine

wire [`WF-1:0] dn;
wire [`WF-1:0] dn_n;
wire [`WF-1:0] dn_y;
wire LFSR_DN;
reg dither;

wire signed [31:0] LFSROUT1;
wire signed [31:0] LFSROUT2;
wire signed [31:0] LFSROUT3;

// reg signed [31:0]RDNUM1;
// reg signed [31:0]RDNUM2;
// reg signed [31:0]RDNUM3;

reg signed [`WF-1:0]RDNUM1_C;
reg signed [`WF-1:0]RDNUM2_C;
// reg signed [`WF-1:0]RDNUM3_C;
integer seed1,seed2,seed3;

wire signed [`WF+1:0]RDNUMSUM;
wire signed [`WF+1:0]RDNUMSUM_test;
//assign RDNUMSUM = {2'b00,RDNUM1_C}-{2'b00,RDNUM2_C}+{2'b00,RDNUM3_C};
assign RDNUMSUM = {2'b00,RDNUM1_C}-{2'b00,RDNUM2_C} + {2'b00,sum2_reg} ;
//assign RDNUMSUM = {2'b00,RDNUM1_C}+{2'b00,RDNUM2_C};
//assign RDNUMSUM = {2'b00,RDNUM1_C}-{2'b00,RDNUM2_C};
//assign RDNUMSUM = {1'b0,RDNUM1_C}+ {1'b0,sum2_reg};
// assign RDNUMSUM = {2'b00,sum2_reg};
//assign RDNUMSUM = 0;
//assign RDNUMSUM = {1'b0,RDNUM1_C};
//assign RDNUMSUM_test = RDNUM1_C-RDNUM2_C+RDNUM3_C;

assign PHE = PHE_Full[`WF+1:0];
//assign PHE = PHE_Full;

LFSR32_initial utLFSR1( .CLK(CLK), .NRST(NRST), .EN(1'b1), .DO(), .INI(32'd101  ), .lfsr(LFSROUT1) );
// //LFSR32_initial utLFSR2( .CLK(CLK), .NRST(NRST), .EN(1'b1), .DO(), .INI(32'd2 ), .lfsr(LFSROUT2) );
LFSR32_initial utLFSR2( .CLK(CLK), .NRST(NRST), .EN(1'b1), .DO(), .INI(32'd1000001 ), .lfsr(LFSROUT2) );
// LFSR32_initial utLFSR3( .CLK(CLK), .NRST(NRST), .EN(1'b1), .DO(), .INI(32'd1000000001), .lfsr(LFSROUT3) );

initial 
begin seed1 = 1;seed2 = 2;seed3 = 6; end

always@(posedge CLK  or negedge NRST) begin
	if (!NRST) begin
	// RDNUM1<=0;
	// RDNUM2<=0;
	// RDNUM3<=0;
	RDNUM1_C<=0;//6
	RDNUM2_C<=0;//6
	// RDNUM3_C<=0;//6	
	end
	else begin
	// RDNUM1<=$random(seed1);
	// RDNUM2<=$random(seed2);
	// RDNUM3<=$random(seed3);
	
	// RDNUM1_C<= PDS_EN ? RDNUM1>>6 : {`WF{1'b0}};//6
	// RDNUM2_C<= PDS_EN ? RDNUM2>>6 : {`WF{1'b0}};//6
	// RDNUM3_C<= PDS_EN ? RDNUM3>>6 : {`WF{1'b0}};//6
	
	
	
	RDNUM1_C<= PDS_EN ? LFSROUT1>>6 : {`WF{1'b0}};//6
	RDNUM2_C<= PDS_EN ? LFSROUT2>>6 : {`WF{1'b0}};//6
	//RDNUM3_C<= PDS_EN ? LFSROUT3>>6 : {`WF{1'b0}};//6	
	end
end


// output generate
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) ca2_reg <= 0;
	else if (EN) begin
		ca2_reg <= ca2;
	end
end

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		OUT <= 0;
		PHE_Full <= {2'b01, {`WF{1'b1}}};
	end else if (EN) begin
			OUT <= {2'b00,ca1} + {ca2[2],ca2} - {ca2_reg[2],ca2_reg};//[-3,4]
			// DTC put on REF path
			PHE_Full <= {ca2,{`WF{1'b0}}} - {3'b000,sum1} + {3'b010, {`WF{1'b0}}};//[-2,2)->[0,4)
			// DTC put on CKVD path
			// PHE <= (-(ca2<<`WF) + sum1 + {2'b01, {`WF{1'b0}}});
		end
end

// 2-orser adder
// assign dither = LFSR_DN;
always @* begin
	dither = DN_EN & LFSR_DN;
end

LFSR32 	DSMMESH11DN_LFSR32 ( .CLK(CLK), .NRST(NRST), .EN(DN_EN), .DO(LFSR_DN), .URN26());

assign dn_y = (2'b11) << DN_WEIGHT;
assign dn_n = (2'b01) << DN_WEIGHT;
assign dn = dither? dn_y: dn_n;
//assign dn = dn_y;
assign sum1_temp = sum1_reg + IN + dn - dn_n;
//assign sum1_temp = sum1_reg + IN + RDNUMSUM;
//assign sum1_temp = sum1_reg + IN;
assign sum1 = sum1_temp[`WF-1:0];
assign ca1 = {1'b0, sum1_temp[`WF]};
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) sum1_reg <= 0;
	else if (EN) begin 
		sum1_reg <= sum1;
	end
end
always @ (posedge CLK or negedge NRST) begin
	if (!NRST) sum2_reg <= 0;
	else if (EN) begin 
		sum2_reg <= sum2;
	end
end
assign sum2 = sum1_temp_d[`WF-1:0];
assign sum1_temp_d = {3'b000,sum1} + {RDNUMSUM[`WF+1],RDNUMSUM};// [-1,3)
assign ca2 = sum1_temp_d[`WF+2:`WF];// [-1,3)->[-1,2]

// // test signal
// integer fp1;
// integer fp2;
// integer fp3;
// integer fp4;
// integer fp5;
// integer fp6;
// real fs = 40e9;

// initial fp1 = $fopen("../results/sdmout.txt");
// initial fp2 = $fopen("./dither.txt");
// initial fp3 = $fopen("./random_test.txt");
// initial fp4 = $fopen("../results/phe.txt");
// initial fp5 = $fopen("./sum1tempd.txt");

// always @ (posedge CLK) begin
	// $fstrobe(fp1, "%3.15e %d", $realtime, $signed(OUT));
// 	$fstrobe(fp2, "%3.15e %d", $realtime, dither);
// 	$fstrobe(fp3, "%3.15e %d", $realtime, $signed(RDNUMSUM));
	// $fstrobe(fp4, "%3.15e %d", $realtime, PHE);
// 	$fstrobe(fp5, "%3.15e %d", $realtime, $signed(sum1_temp_d));
// end

endmodule

// -------------------------------------------------------
// Module Name: PHASESYNC
// Function: generate a complement FCW to adjust PLL phase according to NCO & LO phase
// 			support for /5 mode, add a indicader
// Author: Yang Yumeng Date: 6/28 2023
// Version: v1p1
// -------------------------------------------------------
module PHASESYNC (
NRST,
CKVD,
SYS_REF,
SYS_EN,
FCW,
LO_PHASECAL_EN,
LO_PHASECAL_EN_SEL,
LO_PHASECAL_EN_LO,
LO_DIV,
LO_DIV5,
LO_STATE,
LO_PCALI_KI,
LO_PCALI_KI_iir,
LO_PCALI_DN_EN,
DSM_BOOTMODE,
SYS_EDGE_SEL,
dsm_nrst,
cali,
pcali_done
);

input NRST;
input CKVD;
input SYS_REF; // system reference for phase synchronization
input SYS_EN; // synchronization enable
input [`WI+`WF-1:0] FCW;
input LO_PHASECAL_EN;
input LO_PHASECAL_EN_LO; // lo divider get ready
input LO_PHASECAL_EN_SEL; // select phase cali en source, 0: spi, 1:lo
input [2:0] LO_DIV; // LO generate divider 2/4/8/16/32/64/128/256
input LO_DIV5; // priority than LO_DIV
input [1:0] LO_STATE; // LO sample I/Q
input [4:0] LO_PCALI_KI; // range -16 to 15, kdtc cali step
input [4:0] LO_PCALI_KI_iir; // range 0 to 31, iir scale coefficient
input LO_PCALI_DN_EN;
input DSM_BOOTMODE; // mode 0: normal; mode 1: fractional fcw send to DSM untill system ref trigger
input [2:0] SYS_EDGE_SEL; // select a edge of system ref to reset DSM, 0 is the 1st edge
output dsm_nrst; // MASH11 DSM rst signal
output [`WI+`WF-1:0] cali;
output pcali_done;

wire signed [`WI+`WF-1:0] cali;
wire signed [`WI+`WF-1:0] fcw_cali_p;

// internal signal
reg [`WI+`WF-1:0] PACCUM_LIMIT; // LO digital freq accumulation limitation.
reg [`WI+`WF-1:0] LO_FCW_F;
wire [`WF-1:0] URN26;
reg [`WF-1:0] URN26_d1;
reg [`WI+`WF-1:0] PACCUM_s;
reg [`WI+`WF-1:0] PACCUM_s_rnd; // with random
reg [`WFPHASE-1:0] dphase_lo_c;
reg [`WFPHASE-1:0] dphase_lo_m;
// phase difference
reg [`WFPHASE:0] diffphase_temp; // (ufix), 1+16, (0deg,720deg)
reg [`WFPHASE+1:0] diffphase_comp1;
reg [`WFPHASE+1:0] diffphase_comp2;
reg [`WFPHASE:0] diffphase;// (sfix), 1+16, [-180deg,180deg)

reg sys_ref_d1;
reg sys_ref_d2;
reg sys_ref_d3;
reg sys_ref_d4;
wire sys_comb;
wire sys_ctrl;
reg sys_pcali_en; // use it to reset NCO and DSM, is independent with LO_PHASECAL_EN
reg [2:0] sys_cnt; // counter for posedge of sys ref
reg sys_mask;
reg [2:0] sys_edge_sel_reg;

wire phasecal_en;
assign phasecal_en = LO_PHASECAL_EN_SEL? LO_PHASECAL_EN_LO: LO_PHASECAL_EN;

// reset signal generation
// counter for system reference
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		sys_cnt <= 0;
	end else begin
		if (sys_comb && (sys_cnt<7)) begin
			sys_cnt <= sys_cnt + 1;
		end else if (SYS_EN==1'b0) begin
			sys_cnt <= 0;
		end
	end
end

always @* begin
	case (sys_edge_sel_reg)
		3'd0: sys_mask = (sys_cnt==3'd0);
		3'd1: sys_mask = (sys_cnt==3'd1);
		3'd2: sys_mask = (sys_cnt==3'd2);
		3'd3: sys_mask = (sys_cnt==3'd3);
		3'd4: sys_mask = (sys_cnt==3'd4);
		3'd5: sys_mask = (sys_cnt==3'd5);
		3'd6: sys_mask = (sys_cnt==3'd6);
		3'd7: sys_mask = (sys_cnt==3'd7);
	endcase
end

// sys phase
always @ (posedge CKVD) begin
	sys_ref_d1 <= SYS_REF;
	sys_ref_d2 <= sys_ref_d1;
	sys_ref_d3 <= sys_ref_d2;
	sys_ref_d4 <= sys_ref_d3;
	sys_edge_sel_reg <= SYS_EDGE_SEL;
end

assign sys_comb = sys_ref_d3 & (~sys_ref_d4);
assign sys_ctrl = SYS_EN & sys_comb & sys_mask;
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin 
		sys_pcali_en <= 1'b0;
	end else begin
		if ((sys_pcali_en==1'b0)&&(sys_ctrl==1'b1)) begin
			sys_pcali_en <= 1'b1;
		end else if (SYS_EN==1'b0) begin
			sys_pcali_en <= 1'b0;
		end
	end
end

assign dsm_nrst = DSM_BOOTMODE? sys_pcali_en: (NRST & (~sys_ctrl));

// NCO digital phase generate
reg [`WI:0] FCW_I_t2;
reg [`WI-1:0] FCW_I_div5_rem; // range: 0~4
wire [`WI:0] FCW_I_div5_quo_temp;
wire [`WI:0] FCW_I_div5_rem_temp;


always @* begin
	// fcw preprocess
	FCW_I_t2 = FCW[`WI+`WF-1:`WF-1]; // floor(fcw*2)
	FCW_I_div5_rem = FCW_I_div5_rem_temp;
	if (LO_DIV5) begin
		LO_FCW_F = {FCW_I_div5_rem, FCW[`WF-2:0], 1'b0}; // mod(fcw*2, 5)
		PACCUM_LIMIT = 10'd5 << (`WF);
	end else begin
		LO_FCW_F = FCW - ((FCW >> (`WF+LO_DIV)) << (`WF+LO_DIV));
		PACCUM_LIMIT = 1'b1 << (`WF+LO_DIV);
	end
end

// arithmetic divider: DIVA / DIVB = QUO ... REM
USWI16DIV #(.WI(`WI+1)) DTCMMDCTRL_USWI16DIV ( .DIVA(FCW_I_t2), .DIVB(10'd5), .QUO(FCW_I_div5_quo_temp), .REM(FCW_I_div5_rem_temp) );

// module accumulator
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		PACCUM_s <= 0;
		URN26_d1 <= 0;
	end else if (sys_pcali_en) begin
		if ( ( PACCUM_s + LO_FCW_F ) < PACCUM_LIMIT ) begin
			PACCUM_s <= PACCUM_s + LO_FCW_F;
		end else begin
			PACCUM_s <= PACCUM_s + LO_FCW_F - PACCUM_LIMIT;
		end
		URN26_d1 <= URN26;
	end else begin
		PACCUM_s <= 0;
		URN26_d1 <= 0;
	end
end

// attach phase dither to NCO
reg [`WI+`WF-1:0] rand_u; // uniform to 0~1
always @* begin
	if (LO_DIV5) begin
		rand_u = (URN26) + (URN26>>2);
	end else begin
		rand_u = ((URN26<<LO_DIV)>>2);
	end
	PACCUM_s_rnd = PACCUM_s + rand_u;
	if (PACCUM_s_rnd < PACCUM_LIMIT) begin
		PACCUM_s_rnd = PACCUM_s_rnd;
	end else begin
		PACCUM_s_rnd = PACCUM_s_rnd - PACCUM_LIMIT;
	end
end

LFSR32 	DTCMMDCTRL_LFSR32 ( .CLK(CKVD), .NRST(NRST&sys_pcali_en), .EN(LO_PCALI_DN_EN), .DO() , .URN26(URN26) );

// map lo state to digital phase
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) dphase_lo_m <= 0;
	else if (sys_pcali_en) begin
		if (LO_DIV5) begin
			case (LO_STATE) // LO_I, LO_Q
				// // i sample, 2 phase egment
				// 2'b1: dphase_lo_m <= 0;
				// 2'b0: dphase_lo_m <= {4'b010_1, {12{1'b0}}}; // 180 deg
				// i/q sample, 4 phase egment
				2'b10: dphase_lo_m <= 0;
				2'b11: dphase_lo_m <= {2'b01, {(`WFPHASE-2){1'b0}}}; // 090 deg
				2'b01: dphase_lo_m <= {2'b10, {(`WFPHASE-2){1'b0}}}; // 180 deg
				2'b00: dphase_lo_m <= {2'b11, {(`WFPHASE-2){1'b0}}}; // 270 deg
			endcase
		end else begin
			case (LO_STATE) // LO_I, LO_Q
				// // i sample, 2 phase egment
				// 2'b1: dphase_lo_m <= 0;
				// 2'b0: dphase_lo_m <= {2'b10, {14{1'b0}}}; // 180 deg
				// i/q sample, 4 phase egment
				2'b10: dphase_lo_m <= 0;
				2'b11: dphase_lo_m <= {2'b01, {(`WFPHASE-2){1'b0}}}; // 090 deg
				2'b01: dphase_lo_m <= {2'b10, {(`WFPHASE-2){1'b0}}}; // 180 deg
				2'b00: dphase_lo_m <= {2'b11, {(`WFPHASE-2){1'b0}}}; // 270 deg
			endcase
		end
	end else begin
		dphase_lo_m <= 0;
	end
end

// paccum_s_rnd truncate
always @* begin
	if (LO_DIV5) begin
		dphase_lo_c = PACCUM_s_rnd[`WF-14]? (PACCUM_s_rnd[`WI+`WF-1:`WF-13] + 1'b1): (PACCUM_s_rnd[`WI+`WF-1:`WF-13] + 1'b0);
		// calculate phase difference
		diffphase_temp = {1'b0, dphase_lo_m} - {1'b0, dphase_lo_c} + (3'd5<<(`WFPHASE-3)); // +360deg
		diffphase_comp1 = diffphase_temp - (3'd5<<(`WFPHASE-4)); // -180deg
		diffphase_comp2 = diffphase_temp - (3'd5<<(`WFPHASE-4)) - (3'd5<<(`WFPHASE-3)); // -180deg - 360deg
		case ({diffphase_comp1[`WFPHASE+1], diffphase_comp2[`WFPHASE+1]})
			2'b00: diffphase = diffphase_temp - (3'd5<<(`WFPHASE-2)); // -720deg, [-180deg,0deg)
			2'b01: diffphase = diffphase_temp - (3'd5<<(`WFPHASE-3)); // -360deg, [-180deg,0deg)+[0deg,180deg)
			2'b11: diffphase = diffphase_temp; // (0deg,180deg)
			default: diffphase = 0;
		endcase
	end else begin
		dphase_lo_c = (|((1'b1<<(`WF-`WFPHASE-1+LO_DIV))&PACCUM_s_rnd))? ((PACCUM_s_rnd>>(`WF-`WFPHASE+LO_DIV)) + 1'b1): ((PACCUM_s_rnd>>(`WF-`WFPHASE+LO_DIV)) + 1'b0);
		// calculate phase difference
		diffphase_temp = {1'b0, dphase_lo_m} - {1'b0, dphase_lo_c} + (1'b1<<(`WFPHASE)); // +360deg
		diffphase_comp1 = diffphase_temp - (1'b1<<(`WFPHASE-1)); // -180deg
		diffphase_comp2 = diffphase_temp - (1'b1<<(`WFPHASE-1)) - (1'b1<<(`WFPHASE)); // -180deg - 360deg
		case ({diffphase_comp1[`WFPHASE+1], diffphase_comp2[`WFPHASE+1]})
			2'b00: diffphase = diffphase_temp - (1'b1<<(`WFPHASE+1)); // -720deg, [-180deg,0deg)
			2'b01: diffphase = diffphase_temp - (1'b1<<(`WFPHASE)); // -360deg, [-180deg,0deg)+[0deg,180deg)
			2'b11: diffphase = diffphase_temp; // (0deg,180deg)
			default: diffphase = 0;
		endcase
	end
end

reg signed [`WFPHASE:0] lms_err_pcali;
reg signed [`WFPHASE+8:0] lms_err_pcali_shift;
reg signed [`WFPHASE:0] lms_err_pcali_abs;
reg signed [`WFPHASE+8:0] lms_err_pcali_abs_shift;

reg signed [`WFPHASE+8:0] lms_err_pcali_iir;
reg signed [`WFPHASE+8:0] lms_err_pcali_iir_shift;
reg signed [`WFPHASE+8:0] lms_err_pcali_iir_abs;
reg signed [`WFPHASE+8:0] lms_err_pcali_iir_abs_shift;

reg pcali_done;

reg signed [`WFPHASE:0] lms_err_pcali_iir_abs_shift_cut;
reg signed [`WFPHASE:0] lms_err_pcali_iir_shift_cut;

// reg signed [`WFPHASE:0] lms_err_pcali_iir_abs_comp_shift;
// reg signed [`WFPHASE:0] lms_err_pcali_iir_comp_shift;

assign fcw_cali_p = (sys_pcali_en&phasecal_en)? (LO_PCALI_KI[4]? (lms_err_pcali >>> (~LO_PCALI_KI+1'b1)): (lms_err_pcali <<< LO_PCALI_KI)):0;
// assign fcw_cali_p = phasecal_en? lms_err_pcali_iir_comp_shift:0;

assign cali = fcw_cali_p;

always @(posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		lms_err_pcali_iir <= (17'h01000<<8);
	end else if (sys_pcali_en&phasecal_en) begin
		lms_err_pcali_iir <= lms_err_pcali_iir - lms_err_pcali_iir_shift + lms_err_pcali_shift;
	end else begin
		lms_err_pcali_iir <= (17'h01000<<8);
	end
end

always @* begin
	// initial mu coefficient
	// lms_err_pcali = sys_pcali_en? (~diffphase + 1'b1): 0;
	lms_err_pcali = sys_pcali_en? (diffphase[`WFPHASE]? 17'h01000: 17'h1f000): 0;
	// iir shifter 
	lms_err_pcali_abs = lms_err_pcali[`WFPHASE]? (~lms_err_pcali+1'b1): lms_err_pcali;
	lms_err_pcali_abs_shift = lms_err_pcali_abs>>>(2 + LO_PCALI_KI_iir);
	lms_err_pcali_shift = lms_err_pcali[`WFPHASE]? (~lms_err_pcali_abs_shift+1'b1): lms_err_pcali_abs_shift;
	// iir shifter 
	lms_err_pcali_iir_abs = lms_err_pcali_iir[`WFPHASE+8]? (~lms_err_pcali_iir+1'b1): lms_err_pcali_iir;
	lms_err_pcali_iir_abs_shift = lms_err_pcali_iir_abs>>>(10 + LO_PCALI_KI_iir);
	lms_err_pcali_iir_shift = lms_err_pcali_iir[`WFPHASE+8]? (~lms_err_pcali_iir_abs_shift+1'b1): lms_err_pcali_iir_abs_shift;
	// // iir shifter 
	lms_err_pcali_iir_abs_shift_cut = lms_err_pcali_iir_abs>>>10;
	lms_err_pcali_iir_shift_cut = lms_err_pcali_iir[`WFPHASE+8]? (~lms_err_pcali_iir_abs_shift_cut+1'b1): lms_err_pcali_iir_abs_shift_cut;
	// // cali scale factor
	// lms_err_pcali_iir_abs_comp_shift = LO_PCALI_KI[4]? (lms_err_pcali_iir_abs >>> (~LO_PCALI_KI+1'b1)): (lms_err_pcali_iir_abs <<< LO_PCALI_KI);
	// lms_err_pcali_iir_comp_shift = lms_err_pcali_iir[`WFPHASE]? (~lms_err_pcali_iir_abs_comp_shift+1'b1): lms_err_pcali_iir_abs_comp_shift;
end

always @(posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		pcali_done <= 0;
	end else if (sys_pcali_en&phasecal_en) begin
		// pcali_done <= (lms_err_pcali_iir_abs_shift_cut < pcali_lock_threshold)? 1: 0;
		pcali_done <= (lms_err_pcali_iir_abs_shift_cut < 8'h80)? 1: 0;
	end else begin
		pcali_done <= 0;
	end
end

endmodule
// -------------------------------------------------------
// Module Name: DTCMMDCTRL
// Function: MMD & DTC control logic + DTC NONLINEAR CALIBRATION, dtc calibration 2nd nonlinear with piecewise method
//			build the calibration module with real type
// 			segments for piecewise linear fitting could be adjusted
//			add an optional mode for kdtc calibration
//			implement the DPD algorithm by fixed point
// Author: Yang Yumeng Date: 1/20 2022
// Version: v4p1, insert register to adjust temporal logic
//			add register from lsm_errX_ext to LUTX
// -------------------------------------------------------
module DTCMMD_CTRL (
NRST,
DSM_EN,
PDS_EN, 
DN_EN,
DN_WEIGHT,
MMD_EN,
DTC_EN,
GAC_EN,
CALIORDER,
PSEC,
SECSEL_TEST,
REGSEL_TEST,
SYS_REF,
SYS_EN,
FCW,
CKVD,
KDTCA_INIT,
KDTCB_INIT,
KDTCC_INIT,
KA,
KB,
KC,
PHE_SIG,
PHE_SIG2,
GAC_MODE,
MMD_S_DFF,
MMD_P_DFF,
DCW_DELAY,
KDTC_INT,
LO_PHASECAL_EN,
LO_PHASECAL_EN_LO,
LO_PHASECAL_EN_SEL,
LO_DIV,
LO_STATE,
LO_PCALI_KI,
LO_PCALI_KI_iir,
LO_PCALI_DN_EN,
LO_PCALI_DONE,
DSM_BOOTMODE,
SYS_EDGE_SEL
);

input NRST;
input DSM_EN;
input PDS_EN;
input DN_EN;
input [4:0] DN_WEIGHT;
input MMD_EN;
input DTC_EN;
input GAC_EN;
input [2:0] CALIORDER;
input [2:0] PSEC; // piecewise segments control, 1 seg -- 4/ 2 seg -- 3/ 4 seg -- 2/ 8 seg -- 1/ 16 seg -- 0/
//16 seg  adjust to balance between LUT size and predistortion effect of DTCINL 
input [1:0] SECSEL_TEST; // 0or1 -- kdtcA/ 2 -- kdtcB/ 3 -- kdtcC
input [3:0] REGSEL_TEST; // reg0~15
input SYS_REF;
input SYS_EN;
input [`WI+`WF-1:0] FCW; 
input CKVD;
// kdtc should cover 4096 for fin=1G, dtc_res=200fs, and there is another 1 bit for sign. kdtc 13 bit for WI is enough
input [13-1:0] KDTCA_INIT;
input [13-1:0] KDTCB_INIT;
input [13-1:0] KDTCC_INIT; // piecewise initial point, 1 seg -- 0/ 2 seg -- kdtc/ 4 seg -- kdtc/2/ 8 seg -- kdtc/4/ 16 seg -- kdtc/8/ 32 seg -- kdtc/16/ 64 seg -- kdtc/32
input [4:0] KA; // range -16 to 15, kdtc cali step
input [4:0] KB;
input [4:0] KC;
input PHE_SIG;
input PHE_SIG2;
input GAC_MODE;
output reg [2:0] MMD_S_DFF;
output reg [8:0] MMD_P_DFF;
output reg [`DTC_L-1:0] DCW_DELAY;
output reg [12:0] KDTC_INT;
input LO_PHASECAL_EN;
input [2:0] LO_DIV; // LO generate divider 2/4/8/16/32
input [1:0] LO_STATE; // LO sample I/Q
input [4:0] LO_PCALI_KI; // range -16 to 15, kdtc cali step
input [4:0] LO_PCALI_KI_iir;
input LO_PCALI_DN_EN; // NCO dither
output LO_PCALI_DONE;
input DSM_BOOTMODE;
input [2:0] SYS_EDGE_SEL;
input LO_PHASECAL_EN_LO;
input LO_PHASECAL_EN_SEL;

// internal signal
wire [`WI-1:0] FCW_I;
wire [`WF-1:0] FCW_F;
wire iDSM_EN;
wire iDTC_EN;
wire iGAC_EN;
wire int_flag;
wire [3:0] dsm_car; // mesh1-1 (-3 to 4)
wire [2+`WF-1:0] dsm_phe; // 0<x<4
wire [4+`WF-1:0] dsm_phel_2nd;
wire [17+`WF-1:0] product;
wire [17+`WF-1:0] product0;
wire [15+`WF-1:0] product1;
wire [17+`WF-1:0] product2;
wire [11:0] dtc_temp;
wire [6:0] mmd_temp;

reg [`WF+1:0] phel_reg1;
reg [`WF+1:0] phel_reg2;
reg [`WF+1:0] phel_sync; //0<x<4
reg [4+`WF-1:0] phel_reg1_2nd;
reg [4+`WF-1:0] phel_reg2_2nd;
reg [4+`WF-1:0] phel_sync_2nd; // 0<x^2<16
reg sig_sync;
wire [13+`WF-1:0] kdtcA_cali;
wire [13+`WF-1:0] kdtcB_cali;
wire [13+`WF-1:0] kdtcC_cali;
wire signed [5+`WF-1:0] lms_errA; // integral range -16<x<16
wire signed [5+`WF-1:0] lms_errB;
wire signed [5+`WF-1:0] lms_errC;
wire [13+`WF-1:0] lms_errA_ext; 
wire [13+`WF-1:0] lms_errB_ext; 
wire [13+`WF-1:0] lms_errC_ext; 

// cali coefficient LUT
integer i;
wire [3:0] phe_msb;
// wire [`WF:0] phe_msb_ext;
wire [`WF+1:0] phe_lsb;
reg [3:0] phem_reg1;
reg [3:0] phem_reg2;
reg [3:0] phem_sync;
reg [13+`WF-1:0] LUTA [15:0];
reg [13+`WF-1:0] LUTB [15:0];
reg [13+`WF-1:0] LUTC [15:0];
reg [13+`WF-1:0] lut_test;

// reg
reg [6:0] mmd_temp_p_reg1;
reg [6:0] mmd_temp_p_reg2;
reg [6:0] mmd_temp_p_reg3;
reg [6:0] mmd_temp_p_reg4;
reg mmd_temp_s_reg1;
reg mmd_temp_s_reg2;
reg mmd_temp_s_reg3;
reg mmd_temp_s_reg4;
reg [13+`WF-1:0] kdtcA_cali_reg1;
reg [13+`WF-1:0] kdtcA_cali_reg2;
reg [13+`WF-1:0] kdtcB_cali_reg1;
reg [13+`WF-1:0] kdtcB_cali_reg2;
reg [13+`WF-1:0] kdtcC_cali_reg1;
reg [13+`WF-1:0] kdtcC_cali_reg2;
reg [`WF+1:0] phe_lsb_reg1;
reg [`WF+1:0] phe_lsb_reg2;
reg [`WF+1:0] phe_lsb_reg3;
reg [`WF+1:0] phe_lsb_reg4;
reg [17+`WF-1:0] product0_reg1;
reg [17+`WF-1:0] product0_reg2;
reg [3:0] phe_msb_reg1;
reg [3:0] phe_msb_reg2;
reg [3:0] phe_msb_reg3;
reg [3:0] phe_msb_reg4;
reg [4+`WF-1:0] dsm_phel_2nd_reg1;
reg [4+`WF-1:0] dsm_phel_2nd_reg2;

reg [3:0] phem_sync_reg;
reg [13+`WF-1:0] lms_errA_ext_reg; 
reg [13+`WF-1:0] lms_errB_ext_reg; 
reg [13+`WF-1:0] lms_errC_ext_reg; 

wire dsm_nrst;
wire [`WI+`WF-1:0] fcw_cali_p;

// assign {FCW_I, FCW_F} = FCW;
assign {FCW_I, FCW_F} = FCW + fcw_cali_p;
assign int_flag = |FCW_F;
assign iDSM_EN = DSM_EN; // disable DSM if fcw is integer
assign iDTC_EN = DTC_EN;
assign iGAC_EN = GAC_EN;

PHASESYNC U0_DTCMMDCTRL_PHASESYNC ( .NRST(NRST), .CKVD(CKVD), .SYS_REF(SYS_REF), .SYS_EN(SYS_EN), .FCW(FCW), .LO_PHASECAL_EN(LO_PHASECAL_EN), .LO_PHASECAL_EN_LO(LO_PHASECAL_EN_LO), .LO_PHASECAL_EN_SEL(LO_PHASECAL_EN_SEL), .LO_DIV(LO_DIV), .LO_DIV5(1'b0), .LO_STATE(LO_STATE), .LO_PCALI_KI(LO_PCALI_KI), .LO_PCALI_KI_iir(LO_PCALI_KI_iir), .LO_PCALI_DN_EN(LO_PCALI_DN_EN), .dsm_nrst(dsm_nrst), .cali(fcw_cali_p), .pcali_done(LO_PCALI_DONE), .DSM_BOOTMODE(DSM_BOOTMODE), .SYS_EDGE_SEL(SYS_EDGE_SEL) );

// MMD CTRL
assign mmd_temp = FCW_I + {{3{dsm_car[3]}}, dsm_car};

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		mmd_temp_p_reg1 <= 7'd50;
		mmd_temp_p_reg2 <= 7'd50;
		mmd_temp_p_reg3 <= 7'd50;
		mmd_temp_p_reg4 <= 7'd50;
		MMD_P_DFF <= 7'd50;
	end else if (MMD_EN) begin
		mmd_temp_p_reg1 <= mmd_temp;
		mmd_temp_p_reg2 <= mmd_temp_p_reg1;
		mmd_temp_p_reg3 <= mmd_temp_p_reg2;
		mmd_temp_p_reg4 <= mmd_temp_p_reg3;
		// MMD_P_DFF <= mmd_temp_p_reg4;  	// 5 periods to output, as well as DCW_DELAY
		MMD_P_DFF <= mmd_temp_p_reg3;  	// 4 periods to output, lead then DCW_DELAY for 1 period
	end else begin
		mmd_temp_p_reg1 <= 7'd50;
		mmd_temp_p_reg2 <= 7'd50;
		mmd_temp_p_reg3 <= 7'd50;
		mmd_temp_p_reg4 <= 7'd50;
		MMD_P_DFF <= 7'd50;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		mmd_temp_s_reg1 <= 1'b0;
		mmd_temp_s_reg2 <= 1'b0;
		mmd_temp_s_reg3 <= 1'b0;
		mmd_temp_s_reg4 <= 1'b0;
		MMD_S_DFF <= 1'b0;
	end else if (MMD_EN) begin
		mmd_temp_s_reg1 <= (FCW_I>64)? 1'b1: 1'b0;
		mmd_temp_s_reg2 <= mmd_temp_s_reg1;
		mmd_temp_s_reg3 <= mmd_temp_s_reg2;
		mmd_temp_s_reg4 <= mmd_temp_s_reg3;
		MMD_S_DFF <= mmd_temp_s_reg4;
	end else begin
		mmd_temp_s_reg1 <= 1'b0;
		mmd_temp_s_reg2 <= 1'b0;
		mmd_temp_s_reg3 <= 1'b0;
		mmd_temp_s_reg4 <= 1'b0;
		MMD_S_DFF <= 1'b0;
	end
end

// DTC CTRL
assign phe_msb = dsm_phe[`WF+1:`WF+1-3]>>PSEC; // 15 segments
assign phe_lsb = ((dsm_phe<<(4-PSEC))>>(4-PSEC)); 
assign kdtcA_cali = LUTA[phe_msb]; assign kdtcB_cali = LUTB[phe_msb]; assign kdtcC_cali = LUTC[phe_msb];

USWI1WF16PRO #(2, `WF) U0_DTCMMDCTRL_USWI1WF16PRO( .NRST(NRST), .CLK(CKVD), .PRO(dsm_phel_2nd), .MULTIA(phe_lsb), .MULTIB(phe_lsb) );

SWIWFPRO #(13, 5, `WF) U1_DTCMMDCTRL_SWIWFPRO( .NRST(NRST), .CLK(CKVD), .PROS(product2), .MULTIAS(kdtcA_cali_reg2), .MULTIBS({1'b0,dsm_phel_2nd}) );
SWIWFPRO #(13, 3, `WF) U2_DTCMMDCTRL_SWIWFPRO( .NRST(NRST), .CLK(CKVD), .PROS(product1), .MULTIAS(kdtcB_cali_reg2), .MULTIBS({1'b0,phe_lsb_reg2}) );

assign product0 = {{4{kdtcC_cali_reg2[12+`WF]}}, kdtcC_cali_reg2};
assign product = product2 + {{2{product1[14+`WF]}}, product1} + product0_reg2; //4period to generate product from phe
assign dtc_temp = product[`WF-1]? (product[11+`WF:`WF]+1'b1): product[11+`WF:`WF]; //round

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		DCW_DELAY <= 0;
	end else begin
		DCW_DELAY <= iDTC_EN? dtc_temp: 0;  // 5 periods to output, as well as MMD_P_DFF
	end
end

// DTC NONLINEAR CALI
// generate synchronouse phe and phe_sig
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		sig_sync <= 0;

		phel_reg1 <= 0;
		phel_reg2 <= 0;
		phel_sync <= 0;

		phel_reg1_2nd <= 0;
		phel_reg2_2nd <= 0;
		phel_sync_2nd <= 0;
		
		phem_reg1 <= 0;
		phem_reg2 <= 0;
		phem_sync <= 0;
	end else if (GAC_EN) begin
		sig_sync <= GAC_MODE? PHE_SIG: PHE_SIG2;   // 1period in DTC and 1period from PHE_SIG to sig_sync so 7 periods in total
		
		phel_reg1 <= phe_lsb_reg4;
		phel_reg2 <= phel_reg1;
		phel_sync <= phel_reg2;
		
		phel_reg1_2nd <= dsm_phel_2nd_reg2;
		phel_reg2_2nd <= phel_reg1_2nd;
		phel_sync_2nd <= phel_reg2_2nd;
		
		phem_reg1 <= phe_msb_reg4;
		phem_reg2 <= phem_reg1;
		phem_sync <= phem_reg2;
	end
end

// LUT calibration
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		// LUT initial
		for (i = 15; i >= 0; i = i-1) begin
			LUTA[i] <= KDTCA_INIT<<`WF;
			LUTB[i] <= KDTCB_INIT<<`WF;
		end
		for (i = 15; i >= 0; i = i-1) begin
			LUTC[i] <= (KDTCC_INIT*i)<<`WF;		
		end
	end else if (iGAC_EN==1'b1) begin				
		LUTA[phem_sync_reg] <= LUTA[phem_sync_reg] + lms_errA_ext_reg;
		LUTB[phem_sync_reg] <= LUTB[phem_sync_reg] + lms_errB_ext_reg;
		LUTC[phem_sync_reg] <= (|phem_sync_reg)? (LUTC[phem_sync_reg] + lms_errC_ext_reg): 0; // set fix point to zero
	end
end

// piecewise start point cali
assign lms_errC = sig_sync? {5'b00001, {`WF{1'b0}}}: {5'b11111, {`WF{1'b0}}}; // sig = 1 for kdtc is smaller; sig = 0 for kdtc is larger
assign lms_errC_ext = CALIORDER[0]? (KC[4]? (lms_errC>>>(~KC+1'b1)): (lms_errC<<<KC)): 0;

// 1-st nonlinear
assign lms_errB = sig_sync? {3'b000, phel_sync}: (~{3'b000, phel_sync}+1'b1); // sig = 1 for kdtc is smaller; sig = 0 for kdtc is larger
assign lms_errB_ext = CALIORDER[1]? (KB[4]? (lms_errB>>>(~KB+1'b1)): (lms_errB<<<KB)): 0;

// 2-nd nonlinear
assign lms_errA = sig_sync? {1'b0, phel_sync_2nd}: (~{1'b0, phel_sync_2nd}+1'b1); // sig = 1 for kdtc is smaller; sig = 0 for kdtc is larger
assign lms_errA_ext = CALIORDER[2]? (KA[4]? (lms_errA>>>(~KA+1'b1)): (lms_errA<<<KA)): 0;

// MASH 1-1 PDS-DSM
DSM_MESH11_PDS2 DTCMMDCTRL_PDSDSM(	.CLK(CKVD), 
									.NRST(NRST&dsm_nrst),
									.EN(iDSM_EN),
									.PDS_EN(PDS_EN),
									.DN_EN(DN_EN),
									.DN_WEIGHT(DN_WEIGHT),
									.IN (FCW_F),
									.OUT (dsm_car), 
									.PHE (dsm_phe)
									);

// register
always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		kdtcA_cali_reg1 <= 0;
		kdtcA_cali_reg2 <= 0;
		kdtcB_cali_reg1 <= 0;
		kdtcB_cali_reg2 <= 0;
		kdtcC_cali_reg1 <= 0;
		kdtcC_cali_reg2 <= 0;
	end else begin
		kdtcA_cali_reg1 <= kdtcA_cali;
		kdtcA_cali_reg2 <= kdtcA_cali_reg1;
		kdtcB_cali_reg1 <= kdtcB_cali;
		kdtcB_cali_reg2 <= kdtcB_cali_reg1;
		kdtcC_cali_reg1 <= kdtcC_cali;
		kdtcC_cali_reg2 <= kdtcC_cali_reg1;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		phe_lsb_reg1 <= 0;
		phe_lsb_reg2 <= 0;
		phe_lsb_reg3 <= 0;
		phe_lsb_reg4 <= 0;
	end else begin
		phe_lsb_reg1 <= phe_lsb;
		phe_lsb_reg2 <= phe_lsb_reg1;
		phe_lsb_reg3 <= phe_lsb_reg2;
		phe_lsb_reg4 <= phe_lsb_reg3;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		phe_msb_reg1 <= 0;
		phe_msb_reg2 <= 0;
		phe_msb_reg3 <= 0;
		phe_msb_reg4 <= 0;
	end else begin
		phe_msb_reg1 <= phe_msb;
		phe_msb_reg2 <= phe_msb_reg1;
		phe_msb_reg3 <= phe_msb_reg2;
		phe_msb_reg4 <= phe_msb_reg3;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		product0_reg1 <= 0;
		product0_reg2 <= 0;
	end else begin
		product0_reg1 <= product0;
		product0_reg2 <= product0_reg1;
	end
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		dsm_phel_2nd_reg1 <= 0;
		dsm_phel_2nd_reg2 <= 0;
	end else begin
		dsm_phel_2nd_reg1 <= dsm_phel_2nd;
		dsm_phel_2nd_reg2 <= dsm_phel_2nd_reg1;
	end
end

always @ (posedge CKVD) begin
	phem_sync_reg <= phem_sync;
	lms_errA_ext_reg <= lms_errA_ext;
	lms_errB_ext_reg <= lms_errB_ext;
	lms_errC_ext_reg <= lms_errC_ext;
end

// kdtc test output signal
always @* begin
	case (SECSEL_TEST)
		2'b11: lut_test = LUTC[REGSEL_TEST]; // kdtcC
		2'b10: lut_test = LUTB[REGSEL_TEST]; // kdtcB
		default: lut_test = LUTA[REGSEL_TEST]; //kdtcA
	endcase
end

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		KDTC_INT <= 0;
	end else begin
		KDTC_INT <= lut_test[13+`WF-1:`WF];
	end
end

// // test
// real rphe, rphel, rphel_2;
// real luta0, luta1, luta2, luta3, lutb0, lutb1, lutb2, lutb3, lutc0, lutc1, lutc2, lutc3;
// real rp1, rp2, rp;
// // integer fp_w0, fp_w1, fp_w2, fp_w3, fp_w4;
// // integer j;

// always @* begin
	// rphe = dsm_phe * (2.0**(-`WF));
	// rphel = phe_lsb * (2.0**(-`WF));
	// rphel_2 = dsm_phel_2nd * (2.0**(-`WF));
	// rp1 = $signed(product1) * (2.0**(-`WF));
	// rp2 = $signed(product2) * (2.0**(-`WF));
	// rp = $signed(product) * (2.0**(-`WF));
	// luta0 = $signed(LUTA[0]) * (2.0**(-`WF));
	// luta1 = $signed(LUTA[1]) * (2.0**(-`WF));
	// luta2 = $signed(LUTA[2]) * (2.0**(-`WF));
	// luta3 = $signed(LUTA[3]) * (2.0**(-`WF));
	// lutb0 = $signed(LUTB[0]) * (2.0**(-`WF));
	// lutb1 = $signed(LUTB[1]) * (2.0**(-`WF));
	// lutb2 = $signed(LUTB[2]) * (2.0**(-`WF));
	// lutb3 = $signed(LUTB[3]) * (2.0**(-`WF));
	// lutc0 = $signed(LUTC[0]) * (2.0**(-`WF));
	// lutc1 = $signed(LUTC[1]) * (2.0**(-`WF));
	// lutc2 = $signed(LUTC[2]) * (2.0**(-`WF));
	// lutc3 = $signed(LUTC[3]) * (2.0**(-`WF));
// end

// initial begin
// 	fp_w0 = $fopen("../results/rphe.txt");
	// fp_w1 = $fopen("../results/dtc_dcw.txt");
	// fp_w2 = $fopen("dtc_luta.txt");
	// fp_w3 = $fopen("dtc_lutb.txt");
	// fp_w4 = $fopen("dtc_lutc.txt");
// end
// always @ (posedge CKVD) begin
// 	$fstrobe(fp_w0, "%3.13e %3.13e", $realtime, rphe);
	// $fstrobe(fp_w1, "%3.13e %3.13e %d", $realtime, $unsigned(dsm_phe)*(2.0**(-`WF)), $unsigned(dtc_temp));
	// // LUTA
	// $fwrite(fp_w2, "%3.13e", $realtime);
	// for (j=0; j<63; j=j+1) begin
		// $fwrite(fp_w2, " %f", $signed(LUTA[j])*(2.0**(-`WF)));
	// end
	// $fwrite(fp_w2, "\n");
	// // LUTB
	// $fwrite(fp_w3, "%3.13e", $realtime);
	// for (j=0; j<63; j=j+1) begin
		// $fwrite(fp_w3, " %f", $signed(LUTB[j])*(2.0**(-`WF)));
	// end
	// $fwrite(fp_w3, "\n");
	// // LUTC
	// $fwrite(fp_w4, "%3.13e", $realtime);
	// for (j=0; j<63; j=j+1) begin
		// $fwrite(fp_w4, " %f", $signed(LUTC[j])*(2.0**(-`WF)));
	// end
	// $fwrite(fp_w4, "\n");
// end

endmodule
// -------------------------------------------------------
// Module Name: PHESIG_SDM
// Function: control V-DAC according to phe_sig 
// Author: Yang Yumeng Date: 4/5 2022
// Version: v1p0, cp from RTLv1p0
// -------------------------------------------------------
module PHESIG_SDM (
EN,
NRST,
CLK,
ALPHA,
PHE_SIG,
OUT,
OUTN
);

// io
input EN;
input NRST;
input CLK;
input [3:0] ALPHA; // fractional part, range 1/16~15/16
input PHE_SIG;
output [1:0] OUT;
output [1:0] OUTN;

// internal signal
wire [`WF-1:0] beta;
reg flag; // 1 for increase, 0 for decrease
reg [`WF-1:0] sdmsum;
reg [`WF-1:0] sumreg;
reg [1:0] sdmcarry;
wire [`WF-1:0] sum;
wire carry;

// sdm output
assign OUT = sdmcarry;
assign OUTN = ~sdmcarry;

// +/-1 SDM
assign beta = (ALPHA << (`WF-4));
assign {carry, sum} = sdmsum + beta;

always @(posedge CLK or negedge NRST) begin
	if (!NRST) begin
		flag <= 1'b0;
		sdmsum <= 0;
		sdmcarry <= 2'b00;
	end else if (EN) begin
		if (flag==1'b1) begin
			flag <= PHE_SIG? 1'b1: 
					(beta>sdmsum)? 1'b0: 1'b1;
			sdmsum <= PHE_SIG? (sdmsum+beta):
					(beta>sdmsum)? (beta-sdmsum): (sdmsum-beta);
			sdmcarry <= PHE_SIG? {1'b0, carry}: 2'b00;
		end else begin
			flag <= (~PHE_SIG)? 1'b0:
					(beta>sdmsum)? 1'b1: 1'b0;
			sdmsum <= (~PHE_SIG)? (sdmsum+beta):
					(beta>sdmsum)? (beta-sdmsum): (sdmsum-beta);
			sdmcarry <= (~PHE_SIG)? {1'b1, carry}: 2'b00;
		end
	end
end

endmodule
// -------------------------------------------------------
// Module Name: OTWCALI
// Function: after AFC has done, the OTW is locked at a certain value, the variation of temperature will lead VCTRL deviate to the appropriate range.
// enabel the OTWCALI module to auto adjust the OTW according to the vctrl monitor
// Author: Yang Yumeng Date: 9/5 2023
// Version: v1p0
// -------------------------------------------------------
module OTWCALI(
CLK,
EN,
NRST,
VCTEST,
STEP_SEL,
OTWIN,
OTWOUT
);

input CLK;
input EN;
input NRST;
input [1:0] VCTEST; // vctrl monitor detect signal; 2'b10: vc is higher; 2'b01: vc is lower; 2'b00: lock
input [1:0] STEP_SEL; //step select; 2'00: step=1; 2'01: step=2; 2'10: step=3; 2'11: step=4;
input [`OTW_L-1:0] OTWIN;
output [`OTW_L-1:0] OTWOUT;

// code begin
reg [9:0] win; // detect window 1024 cycles
reg flag;
reg [`OTW_L-1:0] otw_cali;
reg powerup; // need to distinguish the powerup state or enabel state, cali module will use different otw source as the base

assign OTWOUT = otw_cali;

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		win <= 0;
		flag <= 0;
		powerup <= 0;
	end else if (EN) begin
		win <= win + 1;
		flag <= (win==1023)? 1: 0;
		powerup <= 1;
	end else begin
		win <= 0;
		flag <= 0;
		powerup <= powerup;
	end
end

always @ (posedge CLK or negedge NRST) begin
	if (!NRST) begin
		otw_cali <= (1'b1 << (`OTW_L-1));
	end else if (EN) begin
		if (flag) begin // otw cali
			case (VCTEST)
				2'b10: begin
					case (STEP_SEL)
						2'b00: otw_cali <= otw_cali + `OTW_L'd1;
						2'b01: otw_cali <= otw_cali + `OTW_L'd2;
						2'b10: otw_cali <= otw_cali + `OTW_L'd3;
						2'b11: otw_cali <= otw_cali + `OTW_L'd4;
					endcase
				end
				2'b01: begin
					case (STEP_SEL)
						2'b00: otw_cali <= otw_cali - `OTW_L'd1;
						2'b01: otw_cali <= otw_cali - `OTW_L'd2;
						2'b10: otw_cali <= otw_cali - `OTW_L'd3;
						2'b11: otw_cali <= otw_cali - `OTW_L'd4;
					endcase
				end
				default: otw_cali <= otw_cali;
			endcase
		end
	end else begin
		otw_cali <= powerup? otw_cali: OTWIN;
	end
end

endmodule
// -------------------------------------------------------
// Module Name: CTRLMUX
// Function: multiplexer for control signal, enabel signal
// Author: Yang Yumeng Date: 4/5 2022
// Version: v1p0
// -------------------------------------------------------
module CTRLMUX (
SPI_PLL_EN,
// afc ctrl
AFC_CTRL, FAFC_CTRL, SPI_FAFC_EN, SPI_AFC_EN,
AFC_OTWP, AFC_OTWN, FAFC_OTWP, FAFC_OTWN,
// spi ctrl
SPI_CTRL,
SPI_PHESIG_GEN_EN, SPI_DTC_GAINCAL_EN, SPI_DTC_EN, SPI_MMD_EN, SPI_DSM_EN, SPI_PDS_EN, SPI_DN_EN, SPI_SPD_EN, SPI_PFD_EN, SPI_CP_EN, SPI_PRECHARGE_EN, SPI_SNPCNTTDC_EN, SPI_CNTPREDIV_EN,
SPI_CP, SPI_CS, SPI_OTWSOURCE,
SPI_MMD_P, SPI_MMD_S,
// loop ctrl
LOOP_MMD_P, LOOP_MMD_S,
// output 
O_PHESIG_GEN_EN, O_DTC_GAINCAL_EN, O_DTC_EN, O_MMD_EN, O_DSM_EN, O_PDS_EN, O_DN_EN, O_SPD_EN, O_PFD_EN, O_CP_EN, O_PRECHARGE_EN, O_SNPCNTTDC_EN, O_CNTPREDIV_EN,
O_MMD_P, O_MMD_S,
O_CP, O_CS, O_CP_N, O_CS_N,
// for otw cali
CKVD, SPI_OTWCALI_EN, NRST, VCTEST, SPI_OTWCALI_STEPSEL
);

input SPI_PLL_EN;			// all enable signal canbe disable

input AFC_CTRL;				// en signal ctrl right to afc
input FAFC_CTRL;
input SPI_AFC_EN;
input SPI_FAFC_EN;
input [8:0] SPI_MMD_P;
input [2:0] SPI_MMD_S;
input [`OTW_L-1:0] AFC_OTWP;
input [`OTW_L-1:0] AFC_OTWN;
input [`OTW_L-1:0] FAFC_OTWP;
input [`OTW_L-1:0] FAFC_OTWN;

input SPI_CTRL;				// en signal ctrl right to spi
input SPI_PHESIG_GEN_EN;
input SPI_DTC_GAINCAL_EN;
input SPI_DTC_EN;
input SPI_MMD_EN;
input SPI_DSM_EN;
input SPI_PDS_EN;
input SPI_DN_EN;
input SPI_SPD_EN;
input SPI_PFD_EN;
input SPI_CP_EN;
input SPI_PRECHARGE_EN;
input [`OTW_L-1:0] SPI_CP;
input [`OTW_L-1:0] SPI_CS;
input SPI_OTWSOURCE;

input [8:0] LOOP_MMD_P;
input [2:0] LOOP_MMD_S;

input SPI_SNPCNTTDC_EN;
input SPI_CNTPREDIV_EN;

output O_PHESIG_GEN_EN;
output O_DTC_GAINCAL_EN;
output O_DTC_EN;
output O_MMD_EN;
output O_DSM_EN;
output O_PDS_EN;
output O_DN_EN;
output O_SPD_EN;
output O_PFD_EN;
output O_CP_EN;
output O_PRECHARGE_EN;
output [8:0] O_MMD_P;
output [2:0] O_MMD_S;
output [`OTW_L-1:0] O_CP;
output [`OTW_L-1:0] O_CS;
output [`OTW_L-1:0] O_CP_N;
output [`OTW_L-1:0] O_CS_N;
output O_SNPCNTTDC_EN;
output O_CNTPREDIV_EN;

input CKVD;
input SPI_OTWCALI_EN;
input NRST;
input [1:0] VCTEST;
input [1:0] SPI_OTWCALI_STEPSEL;

// MODELMUX
wire S;
reg [`OTW_L-1:0] OTWP;
reg [`OTW_L-1:0] OTWN;

// mux begin
// mux sel ctrl SPI-0/AFC-1
// AFC_CTRL		SPI_CTRL		CONTROLLOR
// 0			0				SPI
// 0			1				SPI
// 1			0				AFC **
// 1			1				SPI
// assign S = (~SPI_CTRL) & AFC_CTRL;

assign S = (~SPI_CTRL) & (AFC_CTRL|FAFC_CTRL); //S=0 for SPI mode

// ENABLE
assign O_PHESIG_GEN_EN 	= SPI_PLL_EN? (S? 0: SPI_PHESIG_GEN_EN): 0;
assign O_DTC_GAINCAL_EN = SPI_PLL_EN? (S? 0: SPI_DTC_GAINCAL_EN): 0;
assign O_DTC_EN 		= SPI_PLL_EN? (S? 0: SPI_DTC_EN): 0;
assign O_MMD_EN 		= SPI_PLL_EN? (S? 0: SPI_MMD_EN): 0;
assign O_DSM_EN 		= SPI_PLL_EN? (S? 0: SPI_DSM_EN): 0;
assign O_PDS_EN 		= SPI_PLL_EN? (S? 0: SPI_PDS_EN): 0;
assign O_DN_EN 			= SPI_PLL_EN? (S? 0: SPI_DN_EN): 0;
assign O_SPD_EN 		= SPI_PLL_EN? (S? 0: SPI_SPD_EN): 0;
assign O_PFD_EN 		= SPI_PLL_EN? (S? 0: SPI_PFD_EN): 0;
assign O_CP_EN 			= SPI_PLL_EN? (S? 0: SPI_CP_EN): 0;
assign O_PRECHARGE_EN 	= (S? 1: SPI_PRECHARGE_EN);
assign O_SNPCNTTDC_EN 	= (S? 1: SPI_SNPCNTTDC_EN);
assign O_CNTPREDIV_EN 	= (S? 1: SPI_CNTPREDIV_EN);

// OTW
always @* begin
	case ({SPI_AFC_EN, SPI_FAFC_EN})
		2'b01: begin OTWP = SPI_OTWSOURCE? FAFC_OTWP: SPI_CP; OTWN = SPI_OTWSOURCE? FAFC_OTWN: ~SPI_CP; end
		2'b10: begin OTWP = SPI_OTWSOURCE? AFC_OTWP: SPI_CP; OTWN = SPI_OTWSOURCE? AFC_OTWN: ~SPI_CP; end
		default: begin OTWP = AFC_OTWP; OTWN = AFC_OTWN; end
	endcase
end

// OTW cali
wire [`OTW_L-1:0] OTWP_cali; 

OTWCALI U0_OTWCALI (
.CLK		(CKVD),	
.EN			(SPI_OTWCALI_EN),
.NRST		(NRST),	
.VCTEST		(VCTEST),	
.STEP_SEL	(SPI_OTWCALI_STEPSEL),
.OTWIN		(OTWP),	
.OTWOUT		(OTWP_cali)
);

// SPI_OTWSOURCE SPI-0/AFC-1
// assign O_CP = SPI_OTWSOURCE? OTWP: SPI_CP;
// assign O_CS = SPI_OTWSOURCE? OTWP: SPI_CS;
// assign O_CP_N = SPI_OTWSOURCE? OTWN: ~SPI_CP;
// assign O_CS_N = SPI_OTWSOURCE? OTWN: ~SPI_CS;
assign O_CP = OTWP_cali;
assign O_CS = OTWP_cali;
assign O_CP_N = ~OTWP_cali;
assign O_CS_N = ~OTWP_cali;

// MMD CTRL
assign O_MMD_P = S? SPI_MMD_P: LOOP_MMD_P;
assign O_MMD_S = S? SPI_MMD_S: LOOP_MMD_S;

endmodule
// -------------------------------------------------------
// Module Name: DIGLOOP
// Function: digital loop top
// Author: Yang Yumeng Date: 4/5 2022
// Version: v1p0
// -------------------------------------------------------
module DIGLOOP (
// rst clk w
SPI_NARST,
CKVD,
SPI_CONFIG,
// synchronous
SYNC_EN,
SYNC_REF,
// SPI input
SPI_DIGRST,
SPI_AFC_EN, SPI_FAFC_EN,
SPI_PLL_EN, SPI_CTRL, AFC_CTRL, FAFC_CTRL, FREQLOCK, FREQLOCK2,
SPI_PHESIG_GEN_EN, SPI_DTC_GAINCAL_EN, SPI_DTC_EN, SPI_MMD_EN, SPI_DSM_EN, SPI_PDS_EN, SPI_DN_EN, SPI_SPD_EN, SPI_PFD_EN, SPI_CP_EN, SPI_PRECHARGE_EN, SPI_SNPCNTTDC_EN, SPI_CNTPREDIV_EN,
SPI_FCW, SPI_KDTCA_INIT, SPI_KDTCB_INIT, SPI_KDTCC_INIT, SPI_KA, SPI_KB, SPI_KC, SPI_ALPHA, SPI_DN_WEIGHT, SPI_CALIORDER, SPI_PSEC, SPI_SECSEL_TEST, SPI_REGSEL_TEST, SPI_CAL_MODE,

SPI_CP, SPI_CS, SPI_OTWSOURCE, SPI_OTWSEL,

SPI_FCW_MULTI, SPI_FAFC_FMULTI, SPI_MMD_P, SPI_MMD_S, SPI_TDCRESNORM, SPI_AUXMMD_SEL, SPI_FCW_MGN,
AFC_OTWP, AFC_OTWN, FAFC_OTWP, FAFC_OTWN,

PHE_SIG, PHE_SIG2, LO_PHASECAL_EN_LO,

LO_STATE, SPI_LO_DIV, SPI_LO_PCALI_KI, SPI_LO_PCALI_KI_iir, SPI_LO_PCALI_DN_EN, SPI_LO_PHASECAL_EN, SPI_LO_PHASECAL_EN_SEL, SPI_DSM_BOOTMODE, SPI_SYS_EDGE_SEL,
// output
O_PHESIG_GEN_EN, O_DTC_GAINCAL_EN, O_DN_EN, O_DTC_EN, O_MMD_EN, O_DSM_EN, O_PDS_EN, O_PRECHARGE_EN, O_PFD_EN, O_CP_EN, O_SPD_EN, O_SNPCNTTDC_EN, O_CNTPREDIV_EN,
O_MMD_P, O_MMD_S, DCW_DELAY, VDACCTRL_OUTP, VDACCTRL_OUTN,
SPI_FCW_O, SPI_MMD_P_O, SPI_MMD_S_O, SPI_FCW_MULTI_O, SPI_FAFC_FMULTI_O, SPI_TDCRESNORM_O, SPI_AUXMMD_SEL_O, SPI_FCW_MGN_O,
O_CP, O_CS, O_CP_N, O_CS_N, SPI_OTWSEL_O,
KDTC_INT, FLOCK, LO_PCALI_DONE,
// for OTW cali
VCTEST, SPI_OTWCALI_EN, SPI_OTWCALI_STEPSEL
);

// rst
input SPI_NARST;
input SYNC_EN;
input SYNC_REF;

// CLK
input CKVD;
input SPI_CONFIG;
input [`WI+`WF-1:0] SPI_FCW;
input PHE_SIG;
input PHE_SIG2;
output reg [`WI+`WF-1:0] SPI_FCW_O;

input SPI_PLL_EN;			// all enable signal canbe disable

input AFC_CTRL;				// en signal ctrl right to afc
input FAFC_CTRL;
input SPI_DIGRST;
input SPI_AFC_EN;
input SPI_FAFC_EN;
input FREQLOCK;
input FREQLOCK2;
input [`OTW_L-1:0] AFC_OTWP;
input [`OTW_L-1:0] AFC_OTWN;
input [`OTW_L-1:0] FAFC_OTWP;
input [`OTW_L-1:0] FAFC_OTWN;

input SPI_CTRL;				// en signal ctrl right to spi
input SPI_PHESIG_GEN_EN;
input SPI_DTC_GAINCAL_EN;
input SPI_DTC_EN;
input SPI_MMD_EN;
input SPI_DSM_EN;
input SPI_PDS_EN;
input SPI_DN_EN;
input SPI_SPD_EN;
input SPI_PFD_EN;
input SPI_CP_EN;
input SPI_PRECHARGE_EN;
input [12:0] SPI_KDTCA_INIT;
input [12:0] SPI_KDTCB_INIT;// kdtc range 400~1330, 11bit for int is enough
input [12:0] SPI_KDTCC_INIT;
input [4:0] SPI_KA;
input [4:0] SPI_KB;
input [4:0] SPI_KC;// range -16 to 15
input [3:0] SPI_ALPHA;
input [4:0] SPI_DN_WEIGHT;
input [2:0] SPI_CALIORDER;
input [2:0] SPI_PSEC;
input [1:0] SPI_SECSEL_TEST;
input [3:0] SPI_REGSEL_TEST;
input SPI_CAL_MODE;
input [`OTW_L-1:0] SPI_CP;
input [`OTW_L-1:0] SPI_CS;
input SPI_OTWSOURCE; // determin otw controlled by afc or spi
input [2:0]  SPI_OTWSEL;
input SPI_SNPCNTTDC_EN;
input SPI_CNTPREDIV_EN;

input [6:0] SPI_FCW_MULTI;
input [4:0] SPI_FAFC_FMULTI;
input [8:0] SPI_MMD_P;
input [2:0] SPI_MMD_S;
input [15:0] SPI_TDCRESNORM;
input SPI_AUXMMD_SEL;
input [7:0] SPI_FCW_MGN;

input SPI_LO_PHASECAL_EN;
input [2:0] SPI_LO_DIV;
input [4:0] SPI_LO_PCALI_KI;
input [4:0] SPI_LO_PCALI_KI_iir;
input SPI_LO_PCALI_DN_EN;
input [1:0] LO_STATE;
input SPI_DSM_BOOTMODE;
input [2:0] SPI_SYS_EDGE_SEL;
input LO_PHASECAL_EN_LO;
input SPI_LO_PHASECAL_EN_SEL;

// DTC MMD CTRL
wire NRST;
wire NRST1;
wire NRST2;
wire inrst;

reg [12:0] SPI_KDTCA_INIT_O;
reg [12:0] SPI_KDTCB_INIT_O;
reg [12:0] SPI_KDTCC_INIT_O;
reg [4:0] SPI_KA_O;
reg [4:0] SPI_KB_O;
reg [4:0] SPI_KC_O;
reg [3:0] SPI_ALPHA_O;
reg [4:0] SPI_DN_WEIGHT_O;
reg [2:0] SPI_CALIORDER_O;
reg [2:0] SPI_PSEC_O;
reg [1:0] SPI_SECSEL_TEST_O;
reg [3:0] SPI_REGSEL_TEST_O;
reg SPI_OTWSOURCE_O;
reg [`OTW_L-1:0] SPI_CP_O;
reg [`OTW_L-1:0] SPI_CS_O;
reg SPI_CAL_MODE_O;
reg [2:0] SPI_LO_DIV_O;
reg [4:0] SPI_LO_PCALI_KI_O;
reg [4:0] SPI_LO_PCALI_KI_iir_O;
reg SPI_LO_PCALI_DN_EN_O;
reg SPI_LO_PHASECAL_EN_O;

wire [8:0] MMD_DCW;
wire [2:0] MMD_S;
output [1:0] VDACCTRL_OUTP;
output [1:0] VDACCTRL_OUTN;
output reg [8:0] SPI_MMD_P_O;
output reg [2:0] SPI_MMD_S_O;
output reg [6:0] SPI_FCW_MULTI_O;
output reg [4:0] SPI_FAFC_FMULTI_O;
output reg [15:0] SPI_TDCRESNORM_O;
output reg SPI_AUXMMD_SEL_O;
output reg [7:0] SPI_FCW_MGN_O;
output [11:0] DCW_DELAY;
output [8:0] O_MMD_P;
output [2:0] O_MMD_S;
output [`OTW_L-1:0] O_CP;
output [`OTW_L-1:0] O_CS;
output [`OTW_L-1:0] O_CP_N;
output [`OTW_L-1:0] O_CS_N;
output reg [2:0] SPI_OTWSEL_O;

output O_PHESIG_GEN_EN;
output O_DTC_GAINCAL_EN;
output O_DN_EN;
output O_DTC_EN;
output O_MMD_EN;
output O_DSM_EN;
output O_PDS_EN;
output O_PRECHARGE_EN;
output O_PFD_EN;
output O_CP_EN;
output O_SPD_EN;
output O_SNPCNTTDC_EN;
output O_CNTPREDIV_EN;

// output to spi reg
output [12:0] KDTC_INT;
output FLOCK;
output LO_PCALI_DONE;

// for otw cali
input SPI_OTWCALI_EN;
input [1:0] VCTEST;
input [1:0] SPI_OTWCALI_STEPSEL;

// input register
reg conf_reg;
wire conf_win;

assign conf_win = conf_reg;

assign inrst = SPI_DIGRST? NRST2: NRST;

always @ (posedge CKVD or negedge inrst) begin
	if (!inrst) begin
		conf_reg <= 1'b1;
	end else if (SPI_CONFIG) conf_reg <= 1'b1;
	else conf_reg <= 1'b0;
end

assign FLOCK = FREQLOCK | FREQLOCK2;

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		// spi ctrl init
		SPI_FCW_O		<= SPI_FCW;
		SPI_KA_O 		<= SPI_KA;
		SPI_KB_O 		<= SPI_KB;
		SPI_KC_O 		<= SPI_KC;
		SPI_ALPHA_O		<= SPI_ALPHA;
		SPI_KDTCA_INIT_O <= SPI_KDTCA_INIT;
		SPI_KDTCB_INIT_O <= SPI_KDTCB_INIT;
		SPI_KDTCC_INIT_O <= SPI_KDTCC_INIT;
		SPI_DN_WEIGHT_O <= SPI_DN_WEIGHT;
		SPI_CALIORDER_O <= SPI_CALIORDER;
		SPI_PSEC_O <= SPI_PSEC;
		SPI_SECSEL_TEST_O <= SPI_SECSEL_TEST;
		SPI_REGSEL_TEST_O <= SPI_REGSEL_TEST;
		SPI_OTWSOURCE_O	<= SPI_OTWSOURCE;
		SPI_OTWSEL_O	<= SPI_OTWSEL;
		SPI_CP_O		<= SPI_CP;
		SPI_CS_O		<= SPI_CS;
		SPI_MMD_P_O		<= SPI_MMD_P;
		SPI_MMD_S_O		<= SPI_MMD_S;
		SPI_FCW_MULTI_O	<= SPI_FCW_MULTI;
		SPI_FAFC_FMULTI_O<= SPI_FAFC_FMULTI;
		SPI_TDCRESNORM_O<= SPI_TDCRESNORM;
		SPI_CAL_MODE_O	<= SPI_CAL_MODE;
		SPI_AUXMMD_SEL_O<= SPI_AUXMMD_SEL;
		SPI_FCW_MGN_O	<= SPI_FCW_MGN;
		SPI_LO_DIV_O		<= SPI_LO_DIV;
		SPI_LO_PCALI_KI_O	<= SPI_LO_PCALI_KI;
		SPI_LO_PCALI_KI_iir_O	<= SPI_LO_PCALI_KI_iir;
		SPI_LO_PCALI_DN_EN_O<= SPI_LO_PCALI_DN_EN;
		SPI_LO_PHASECAL_EN_O<= SPI_LO_PHASECAL_EN;
	end else if (conf_win) begin
		SPI_FCW_O		<= SPI_FCW;
		SPI_KA_O 		<= SPI_KA;
		SPI_KB_O 		<= SPI_KB;
		SPI_KC_O 		<= SPI_KC;
		SPI_ALPHA_O		<= SPI_ALPHA;
		SPI_KDTCA_INIT_O <= SPI_KDTCA_INIT;
		SPI_KDTCB_INIT_O <= SPI_KDTCB_INIT;
		SPI_KDTCC_INIT_O <= SPI_KDTCC_INIT;
		SPI_DN_WEIGHT_O <= SPI_DN_WEIGHT;
		SPI_CALIORDER_O <= SPI_CALIORDER;
		SPI_PSEC_O <= SPI_PSEC;
		SPI_SECSEL_TEST_O <= SPI_SECSEL_TEST;
		SPI_REGSEL_TEST_O <= SPI_REGSEL_TEST;
		SPI_OTWSOURCE_O	<= SPI_OTWSOURCE;
		SPI_OTWSEL_O	<= SPI_OTWSEL;
		SPI_CP_O		<= SPI_CP;
		SPI_CS_O		<= SPI_CS;
		SPI_MMD_P_O		<= SPI_MMD_P;
		SPI_MMD_S_O		<= SPI_MMD_S;
		SPI_FCW_MULTI_O	<= SPI_FCW_MULTI;
		SPI_FAFC_FMULTI_O<= SPI_FAFC_FMULTI;
		SPI_TDCRESNORM_O<= SPI_TDCRESNORM;
		SPI_CAL_MODE_O	<= SPI_CAL_MODE;
		SPI_AUXMMD_SEL_O<= SPI_AUXMMD_SEL;
		SPI_FCW_MGN_O	<= SPI_FCW_MGN;
		SPI_LO_DIV_O		<= SPI_LO_DIV;
		SPI_LO_PCALI_KI_O	<= SPI_LO_PCALI_KI;
		SPI_LO_PCALI_KI_iir_O	<= SPI_LO_PCALI_KI_iir;
		SPI_LO_PCALI_DN_EN_O<= SPI_LO_PCALI_DN_EN;
		SPI_LO_PHASECAL_EN_O<= SPI_LO_PHASECAL_EN;
	end
end

CTRLMUX U0_MUX (
.LOOP_MMD_P			(MMD_DCW			),
.LOOP_MMD_S 		(MMD_S				),
.SPI_PLL_EN         (SPI_PLL_EN         ),
.AFC_CTRL           (AFC_CTRL           ),
.FAFC_CTRL          (FAFC_CTRL          ),
.SPI_AFC_EN			(SPI_AFC_EN			),
.SPI_FAFC_EN		(SPI_FAFC_EN		),
.SPI_MMD_P          (SPI_MMD_P_O        ),
.SPI_MMD_S          (SPI_MMD_S_O        ),
.AFC_OTWP           (AFC_OTWP           ),
.AFC_OTWN           (AFC_OTWN           ),
.FAFC_OTWP          (FAFC_OTWP          ),
.FAFC_OTWN          (FAFC_OTWN          ),
.SPI_CTRL           (SPI_CTRL           ),
.SPI_PHESIG_GEN_EN 	(SPI_PHESIG_GEN_EN ),
.SPI_DTC_GAINCAL_EN (SPI_DTC_GAINCAL_EN ),
.SPI_DTC_EN         (SPI_DTC_EN         ),
.SPI_MMD_EN         (SPI_MMD_EN         ),
.SPI_DSM_EN         (SPI_DSM_EN         ),
.SPI_PDS_EN         (SPI_PDS_EN         ),
.SPI_DN_EN          (SPI_DN_EN          ),
.SPI_SPD_EN			(SPI_SPD_EN			),
.SPI_PFD_EN			(SPI_PFD_EN			),
.SPI_CP_EN			(SPI_CP_EN			),
.SPI_PRECHARGE_EN	(SPI_PRECHARGE_EN	),
.SPI_CP				(SPI_CP_O			),
.SPI_CS				(SPI_CS_O			),
.SPI_OTWSOURCE    	(SPI_OTWSOURCE_O   	),
.O_PHESIG_GEN_EN	(O_PHESIG_GEN_EN 	),
.O_DTC_GAINCAL_EN   (O_DTC_GAINCAL_EN   ),
.O_DTC_EN           (O_DTC_EN           ),
.O_MMD_EN           (O_MMD_EN           ),
.O_DSM_EN           (O_DSM_EN           ),
.O_PDS_EN           (O_PDS_EN           ),
.O_DN_EN            (O_DN_EN            ),
.O_SPD_EN			(O_SPD_EN			),
.O_PFD_EN			(O_PFD_EN			),
.O_CP_EN			(O_CP_EN			),
.O_PRECHARGE_EN		(O_PRECHARGE_EN		),
.O_MMD_P            (O_MMD_P            ),
.O_MMD_S	        (O_MMD_S            ),
.O_CP             	(O_CP             	),
.O_CS             	(O_CS             	),
.O_CP_N            	(O_CP_N            	),
.O_CS_N            	(O_CS_N            	),
.SPI_SNPCNTTDC_EN	(SPI_SNPCNTTDC_EN	),
.SPI_CNTPREDIV_EN	(SPI_CNTPREDIV_EN	),
.O_SNPCNTTDC_EN		(O_SNPCNTTDC_EN		),
.O_CNTPREDIV_EN		(O_CNTPREDIV_EN		),
.CKVD				(CKVD),
.SPI_OTWCALI_EN		(SPI_OTWCALI_EN),
.NRST				(inrst),
.VCTEST				(VCTEST),
.SPI_OTWCALI_STEPSEL(SPI_OTWCALI_STEPSEL)
);

DTCMMD_CTRL U0_DTCMMDCTRL(
.NRST			(inrst				),
.DSM_EN			(O_DSM_EN			),
.PDS_EN			(O_PDS_EN			), 
.DN_EN			(O_DN_EN			),
.DN_WEIGHT		(SPI_DN_WEIGHT_O	),
.MMD_EN			(O_MMD_EN			),
.DTC_EN			(O_DTC_EN			),
.GAC_EN			(O_DTC_GAINCAL_EN	),
.CALIORDER		(SPI_CALIORDER_O	),
.PSEC			(SPI_PSEC_O			),
.SECSEL_TEST	(SPI_SECSEL_TEST_O	),
.REGSEL_TEST	(SPI_REGSEL_TEST_O	),
.SYS_REF		(SYNC_REF			),
.SYS_EN			(SYNC_EN			),
.FCW			(SPI_FCW_O			),
.CKVD			(CKVD				),
.KDTCA_INIT		(SPI_KDTCA_INIT_O	),
.KDTCB_INIT		(SPI_KDTCB_INIT_O	),
.KDTCC_INIT		(SPI_KDTCC_INIT_O	),
.KA				(SPI_KA_O			),
.KB				(SPI_KB_O			),
.KC				(SPI_KC_O			),
.PHE_SIG		(PHE_SIG			),
.PHE_SIG2		(PHE_SIG2			),
.GAC_MODE		(SPI_CAL_MODE_O		),
.MMD_S_DFF		(MMD_S				),
.MMD_P_DFF		(MMD_DCW			),
.DCW_DELAY		(DCW_DELAY			),
.KDTC_INT		(KDTC_INT			),
.LO_PHASECAL_EN	(SPI_LO_PHASECAL_EN_O),
.LO_PHASECAL_EN_SEL	(SPI_LO_PHASECAL_EN_SEL),
.LO_PHASECAL_EN_LO	(LO_PHASECAL_EN_LO),
.LO_DIV			(SPI_LO_DIV_O		),
.LO_STATE		(LO_STATE			),
.LO_PCALI_KI	(SPI_LO_PCALI_KI_O	),
.LO_PCALI_KI_iir(SPI_LO_PCALI_KI_iir_O	),
.LO_PCALI_DN_EN	(SPI_LO_PCALI_DN_EN_O),
.LO_PCALI_DONE 	(LO_PCALI_DONE),
.DSM_BOOTMODE	(SPI_DSM_BOOTMODE),
.SYS_EDGE_SEL	(SPI_SYS_EDGE_SEL)
);

PHESIG_SDM U0_PHESIG_SDM(
.EN			(O_PHESIG_GEN_EN),
.NRST		(inrst),
.CLK		(CKVD),
.ALPHA		(SPI_ALPHA_O),
.PHE_SIG	(PHE_SIG),
.OUT		(VDACCTRL_OUTP),
.OUTN       (VDACCTRL_OUTN)
);

SYNCRSTGEN U0_SYNCRST( .CLK (CKVD), .NARST (SPI_NARST), .NRST (NRST), .NRST1 (NRST1), .NRST2(NRST2));

endmodule
