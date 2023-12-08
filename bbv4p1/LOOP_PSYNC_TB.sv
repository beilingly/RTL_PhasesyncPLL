`timescale 1s / 1fs

module LOOP_PSYNC_TB;

// word width define
`define WI 9
`define WF 26
`define OTW_L 9
`define DTC_L 12

parameter real fref = 100e6;

parameter integer fcw_frac = 0.123 * (2.0**(`WF));
parameter real fcw_frac_cut = fcw_frac*(2.0**(-`WF));
parameter real fcw_cut = 50 + fcw_frac_cut;
parameter real fcwlo_cut = fcw_cut*2/5;

// SPI outernal CTRL signal
wire SPI_NARST;
wire SPI_CONFIG;
wire SPI_CTRL;
wire SPI_PLL_EN;
wire SPI_PHESIG_GEN_EN;
wire SPI_DTC_GAINCAL_EN;
wire SPI_DTC_EN;
wire SPI_MMD_EN;
wire SPI_DSM_EN;
wire SPI_DN_EN;
wire [1:0] SPI_DN_S;
wire SPI_SPD_EN;
wire SPI_PFD_EN;
wire SPI_CP_EN;
wire SPI_PRECHARGE_EN;
wire SPI_AFC_EN;
wire SPI_CAL_MODE;
wire [4:0] SPI_DN_WEIGHT;
wire [3:0] SPI_ALPHA;
wire [2:0] SPI_MMD_S;
wire [8:0] SPI_MMD_P;
wire [6:0] SPI_FCW_MULTI;
wire [`WI+`WF-1:0] SPI_FCW;
wire SPI_OTWSOURCE;
wire [2:0] SPI_OTWSEL;
wire [`OTW_L-1:0] SPI_CP;
wire [`OTW_L-1:0] SPI_CS;

// MUX CTRL signal
wire FREQLOCK;
wire FLOCK;
wire AFC_CTRL;
wire [1:0] VDACCTRL_OUTP;
wire [1:0] VDACCTRL_OUTN;
wire [8:0] SPI_MMD_P_O;
wire [2:0] SPI_MMD_S_O;
wire [6:0] SPI_FCW_MULTI_O;
wire [`DTC_L-1:0] DCW_DELAY;
wire [2:0] O_MMD_S;
wire [8:0] O_MMD_P;
reg [8:0] O_MMD_P_retimer;
wire [`OTW_L-1:0] AFC_OTWP;
wire [`OTW_L-1:0] AFC_OTWN;
wire [`OTW_L-1:0] FAFC_OTWP;
wire [`OTW_L-1:0] FAFC_OTWN;
wire O_PHESIG_GEN_EN;
wire O_DTC_GAINCAL_EN;
wire O_DN_EN;
wire O_DTC_EN;
wire O_MMD_EN;
wire O_DSM_EN;
wire O_PRECHARGE_EN;
wire O_PFD_EN;
wire O_SPD_EN;
wire O_CP_EN;
wire [2:0] SPI_OTWSEL_O;
wire [`OTW_L-1:0] O_CP;
wire [`OTW_L-1:0] O_CP_N;
wire [`OTW_L-1:0] O_CS;
wire [`OTW_L-1:0] O_CS_N;
wire [`WI+`WF-1:0] SPI_FCW_O;
wire [12:0] KDTC_INT;

wire [12:0] SPI_KDTC_INIT;
wire [4:0] SPI_KA;
wire [2:0] SPI_LO_DIV;
wire SPI_LO_DIV5;
wire [4:0] SPI_LO_PCALI_KI;
wire [4:0] SPI_LO_PCALI_KI_iir;
wire SPI_LO_PCALI_DN_EN;
wire SPI_LO_PHASECAL_EN;
wire LO_PCALI_DONE;
wire SPI_LO_PHASECAL_EN_SEL;
reg LO_PHASECAL_EN_LO;
wire SPI_DSM_BOOTMODE;
wire [2:0] SPI_SYS_EDGE_SEL;

// digital analog interact signal
wire [6:0] LOOP_TEMP_CODE;
wire [8:0] LOOP_BINARY_OUT;

// LOOP internal signal
wire REFDTC;
wire CKVD;
real VSMP;
real VREFSIG;
wire PHE_SIG;
reg PHE_SIG2;
real IPFD;
real ISSPD;
real VCTRL;

wire [1:0] LO_STATE;
wire LO_I;
wire LO_Q;

// VCO otw cali
wire SPI_OTWCALI_EN;

// vcxo ref
// wire REF;
reg REF;
// vco clk
wire CKV;
wire CKD2;

reg sys_en;
reg sys_ref;

// VCXO	U_VCXO (.VOUT(REF));

initial begin
	sys_en = 0;
	LO_PHASECAL_EN_LO = 1;
	sys_ref = 0;
	#10e-6;
	// sys_en = 0;
	forever begin
		#10e-6;
		sys_ref = ~sys_ref;
	end
end

initial REF = 1'b0;
always #(1/fref/2) REF = ~REF;

// BBPD
always @ (posedge CKVD) begin
	PHE_SIG2 <= REFDTC;
end

LOGEN_MIS #(.dcmis(50), .pmis(0), .fref(fref), .fcwlo(fcwlo_cut)) U_LOGEN ( .CKV(CKV), .REF(REF), .LO_DIV(SPI_LO_DIV), .LO_I(LO_I), .LO_Q(LO_Q), .LO_STATE(LO_STATE) );

// wire [3:0] TCOTW_INT;
// wire TCOTW_DSM;
// VCO_PN	U_VCO ( .VCTRL(VCTRL), .DCTRL(O_CP), .VOUT(CKV) );
VCO_PN	U_VCO ( .VCTRL(VCTRL), .DCTRL(O_CP), .VOUT(CKV), .DCTRLTC(4'd0), .DCTRLTCDSM(1'd0));
prediv	U_prediv2 (.CKV(CKV), .SEL(1'b0), .CKD2(CKD2), .CKVCNT());

MMD	U_MMD ( .NARST(SPI_NARST), .CKV(CKD2), .DIVNUM(O_MMD_P), .CKVD(CKVD) );
// MMD ctrl word retimer
always @(posedge CKVD) begin
	O_MMD_P_retimer <= O_MMD_P;
end

// test sianle DCWOUT
wire [`DTC_L-1:0] DCWOUT;
DCWSMP 	U_DCWSMP ( .SPI_NARST(SPI_NARST), .REFDTC(CKVD), .DCWIN(DCW_DELAY), .LOOP_TEMP_CODE(LOOP_TEMP_CODE), .LOOP_BINARY_OUT(LOOP_BINARY_OUT), .DCWOUT(DCWOUT) );

DTC U_DTC ( .DTCDCW(DCWOUT), .CKIN(REF), .CKOUT(REFDTC) );

PD_TOP 	U_PD ( .EN_PFD	(O_PFD_EN), .EN_SSPD(O_SPD_EN), .NRST_PFD(SPI_NARST), .PRECHARGE(O_PRECHARGE_EN), .REF_DTC(~REFDTC), .VREF(0.5), .FBCKVD(~CKVD), .VSMP(VSMP), .IPFD(IPFD), .ISSPD(ISSPD), .VOUT(VCTRL) );

wire VDAC_RST;
assign VDAC_RST = ~( O_PHESIG_GEN_EN & (~(AFC_CTRL)) );
V_DAC U_DAC ( .RESET(VDAC_RST), .EN(VDACCTRL_OUTP[0]), .IN(VDACCTRL_OUTN[1]), .DACCLK(CKVD), .DELAYSW(4'b0100), .VSMP(VSMP), .VREFSIG(VREFSIG), .PHE_SIG(PHE_SIG) );

SAR_CTRL 	U_SAR_CTRL (
.SPI_AFC_EN		(SPI_AFC_EN),
.SPI_NARST		(SPI_NARST),
.REF			(REF),
.CKVD			(CKVD),
.SPI_FCW_MULTI_O(SPI_FCW_MULTI_O),
.SPI_FCW_O		(SPI_FCW_O[`WI+`WF-1:`WF-8]),
.SPI_MMD_P_O	(SPI_MMD_P_O),
.AFC_OTWP		(AFC_OTWP),
.AFC_OTWN		(AFC_OTWN),
.FREQLOCK		(FREQLOCK),
.AFC_CTRL		(AFC_CTRL)
);

DIGLOOP U0_DIGLOOP (.*, .SYNC_EN(sys_en), .SYNC_REF(sys_ref), .VCTEST(2'b10), .SPI_OTWCALI_STEPSEL(2'd0) );

reg TCEN;
initial begin
	TCEN = 0;
	#30e-6;
	TCEN = 0;
end

// TCDIG u0_TCDIG ( .NARST(SPI_NARST), .TCEN(TCEN), .REFCLK(REF), .VCOCLK(CKV), .TCKIS(4'd12), .TCKPS(4'd4), .TCOTW_INT(TCOTW_INT), .TCOTW_FRAC(), .TCOTWDSM(TCOTW_DSM), .VCTRL(VCTRL) );


SPI_PLOCK 		U_SPI (
.SPI_NARST		(SPI_NARST),
.SPI_CONFIG		(SPI_CONFIG),
.SPI_CTRL		(SPI_CTRL),
.SPI_PLL_EN		(SPI_PLL_EN),
.SPI_PHESIG_GEN_EN	(SPI_PHESIG_GEN_EN),
.SPI_DTC_GAINCAL_EN	(SPI_DTC_GAINCAL_EN),
.SPI_DTC_EN		(SPI_DTC_EN),
.SPI_MMD_EN		(SPI_MMD_EN),
.SPI_DSM_EN		(SPI_DSM_EN),
.SPI_DN_EN		(SPI_DN_EN),
.SPI_DN_S		(SPI_DN_S),
.SPI_TDCRESNORM	(), 
.SPI_DN_WEIGHT	(SPI_DN_WEIGHT),
.SPI_SPD_EN		(SPI_SPD_EN),
.SPI_PFD_EN		(SPI_PFD_EN),
.SPI_CP_EN		(SPI_CP_EN),
.SPI_PRECHARGE_EN	(SPI_PRECHARGE_EN),
.SPI_AFC_EN		(SPI_AFC_EN),
.SPI_FAFC_EN	(),
.SPI_ALPHA		(SPI_ALPHA),
.SPI_CAL_MODE	(SPI_CAL_MODE),
.SPI_MMD_S		(SPI_MMD_S),
.SPI_MMD_P		(SPI_MMD_P),
.SPI_FCW_MULTI	(SPI_FCW_MULTI),
.SPI_FAFC_FMULTI(),
.SPI_FCW		(SPI_FCW),
.SPI_OTWSOURCE	(SPI_OTWSOURCE),
.SPI_OTWSEL	(SPI_OTWSEL),
.SPI_CP	(SPI_CP),
.SPI_CS	(SPI_CS),
.SPI_EDGESEL (),
.SPI_MMDRSTSEL (),
.SPI_PFDRSTSEL (),
.SPI_AUXMMD_SEL (),
.SPI_FCW_MGN (),
.SPI_DIGRST	(),
.SPI_PDS_EN (),
.SPI_KDTCA_INIT (SPI_KDTC_INIT),
.SPI_KDTCB_INIT (),
.SPI_KDTCC_INIT (),
.SPI_KA	(SPI_KA),
.SPI_KB	(),
.SPI_KC	(),
.SPI_CALIORDER (),
.SPI_PSEC (),
.SPI_SECSEL_TEST (),
.SPI_REGSEL_TEST (),
.SPI_LO_PHASECAL_EN	(SPI_LO_PHASECAL_EN),
.SPI_LO_DIV (SPI_LO_DIV),
.SPI_LO_DIV5 (SPI_LO_DIV5),
.SPI_LO_PCALI_KI (SPI_LO_PCALI_KI),
.SPI_LO_PCALI_KI_iir (SPI_LO_PCALI_KI_iir),
.SPI_LO_PCALI_DN_EN (SPI_LO_PCALI_DN_EN),
.SPI_SNPCNTTDC_EN (),
.SPI_CNTPREDIV_EN (),
.SPI_DSM_BOOTMODE (SPI_DSM_BOOTMODE),
.SPI_SYS_EDGE_SEL (SPI_SYS_EDGE_SEL),
.SPI_LO_PHASECAL_EN_SEL (SPI_LO_PHASECAL_EN_SEL),
.SPI_OTWCALI_EN (SPI_OTWCALI_EN)
);

// test
integer fp1;
real ref_pos;
real loi_pos;
real ref_pos_last;
real loi_pos_last;
real dphase;
real loi_phase, loi_phase_dly1, loi_phase_dly2, loi_phase_dly3;
real dig_phase, dig_phase_d;
reg sys_ref_d1, sys_ref_d2, sys_ref_d3, sys_ref_d4;
wire sys_ctrl_temp;
initial begin
	fp1 = $fopen("ref_lo_phase.txt");
end

assign dig_phase_d = $unsigned(U0_DIGLOOP.U0_DTCMMDCTRL.U0_DTCMMDCTRL_PHASESYNC.PACCUM_s) * (2.0**(-26)) * 0.2 * 360;

always @ (posedge REF) begin
	ref_pos_last = ref_pos;
	ref_pos = $realtime;
end

always @ (posedge LO_I) begin
	loi_pos_last = loi_pos;
	loi_pos = $realtime;
	loi_phase = (-((loi_pos - ref_pos))*(fref*fcwlo_cut*360));
	loi_phase = ((loi_phase/360) - $floor(loi_phase/360))*360;
	
	// loi_phase_dly1 = loi_phase;
	// dphase = loi_phase_dly1 - dig_phase_d;
	// dphase = ((dphase/360) - $floor(dphase/360))*360;
	// $fstrobe(fp1, "%3.13e %3.13e", ref_pos, loi_pos);
end

always @ (posedge REF) begin
	loi_phase_dly3 = loi_phase_dly2;
	loi_phase_dly2 = loi_phase_dly1;
	loi_phase_dly1 = loi_phase;
	
	dphase = loi_phase_dly2 - dig_phase_d;
	dphase = ((dphase/360) - $floor(dphase/360))*360;
	$fstrobe(fp1, "%3.13e %3.13e", ref_pos, loi_pos);
end

assign sys_ctrl_temp = sys_ref_d1 & (~sys_ref_d2);
always @ (posedge CKVD) begin
	sys_ref_d1 <= sys_ref;
	sys_ref_d2 <= sys_ref_d1;
	sys_ref_d3 <= sys_ref_d2;
	sys_ref_d4 <= sys_ref_d3;
	
	if (sys_ctrl_temp == 1'b1) begin
		dig_phase <= 0;
	end else begin
		dig_phase <= (((dig_phase+fcwlo_cut*360)/360) - $floor(((dig_phase+fcwlo_cut*360)/360)))*360;
	end
end

// initial begin
	// $display("Use SDF back-annotation for simulation!");
	// $sdf_annotate("../sdf/DCWSMP.sdf", U_DCWSMP);
	// $sdf_annotate("../sdf/DTCMMD_CTRL.sdf", U_DTCMMD_CTRL);
	// $sdf_annotate("../sdf/SSPLL_LOOP_PART.sdf", U_SSPLL_LOOP_PART);
// end

endmodule