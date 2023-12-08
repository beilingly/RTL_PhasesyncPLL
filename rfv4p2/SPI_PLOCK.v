`timescale 1ns / 1ps

// word width define
`define WI 9
`define WF 26
`define OTW_L 9
`define DTC_L 12

module SPI_PLOCK (
SPI_NARST,
SPI_CONFIG,
SPI_CTRL,
SPI_PLL_EN,
SPI_PHESIG_GEN_EN,
SPI_DTC_GAINCAL_EN,
SPI_CAL_MODE,
SPI_DTC_EN,
SPI_MMD_EN,
SPI_DSM_EN,
SPI_DN_EN,
SPI_DN_S,
SPI_TDCRESNORM,
SPI_DN_WEIGHT,
SPI_SPD_EN,
SPI_PFD_EN,
SPI_CP_EN,
SPI_PRECHARGE_EN,
SPI_AFC_EN,
SPI_FAFC_EN,
// GAINCAL_MODE,
SPI_ALPHA,
SPI_MMD_P,
SPI_MMD_S,
SPI_FCW_MULTI,
SPI_FAFC_FMULTI,
SPI_FCW,
SPI_OTWSOURCE,
SPI_OTWSEL,
SPI_CP,
SPI_CS,
SPI_EDGESEL,
SPI_MMDRSTSEL,
SPI_PFDRSTSEL,
SPI_AUXMMD_SEL,
SPI_FCW_MGN,
SPI_DIGRST,
SPI_PDS_EN,
SPI_KDTCA_INIT,
SPI_KDTCB_INIT,
SPI_KDTCC_INIT,
SPI_KA,
SPI_KB,
SPI_KC,
SPI_CALIORDER,
SPI_PSEC,
SPI_SECSEL_TEST,
SPI_REGSEL_TEST,
SPI_LO_PHASECAL_EN,
SPI_LO_DIV,
SPI_LO_PCALI_KI,
SPI_LO_PCALI_KI_iir,
SPI_LO_PCALI_DN_EN,
SPI_SNPCNTTDC_EN,
SPI_CNTPREDIV_EN,
SPI_DSM_BOOTMODE,
SPI_SYS_EDGE_SEL,
SPI_LO_PHASECAL_EN_SEL,
SPI_OTWCALI_EN
);

// io
output reg SPI_NARST;
output reg SPI_CONFIG;
output reg SPI_CTRL;
output reg SPI_PLL_EN;
output reg SPI_PHESIG_GEN_EN;
output reg SPI_DTC_GAINCAL_EN;
output reg SPI_CAL_MODE;
output reg SPI_DTC_EN;
output reg SPI_MMD_EN;
output reg SPI_DSM_EN;
output reg SPI_DN_EN;
output reg [1:0] SPI_DN_S;
output reg [15:0] SPI_TDCRESNORM;
output reg [4:0] SPI_DN_WEIGHT; // default is 12
output reg SPI_SPD_EN;
output reg SPI_PFD_EN;
output reg SPI_CP_EN;
output reg SPI_PRECHARGE_EN;
output reg SPI_AFC_EN;
output reg SPI_FAFC_EN;
// output GAINCAL_MODE;
output reg [3:0] SPI_ALPHA;
output reg [8:0] SPI_MMD_P;
output reg [2:0] SPI_MMD_S;
output reg [6:0] SPI_FCW_MULTI;
output reg [4:0] SPI_FAFC_FMULTI;
output reg [`WI+`WF-1:0] SPI_FCW;
output reg SPI_OTWSOURCE;
output reg [2:0] SPI_OTWSEL;
output reg [`OTW_L-1:0] SPI_CP;
output reg [`OTW_L-1:0] SPI_CS;
output reg SPI_EDGESEL;
output reg SPI_MMDRSTSEL;
output reg SPI_PFDRSTSEL;
output reg SPI_AUXMMD_SEL;
output reg [7:0] SPI_FCW_MGN;
output reg SPI_DIGRST;

output reg SPI_PDS_EN;
output reg [12:0] SPI_KDTCA_INIT;
output reg [12:0] SPI_KDTCB_INIT;
output reg [12:0] SPI_KDTCC_INIT;
output reg [4:0] SPI_KA;
output reg [4:0] SPI_KB;
output reg [4:0] SPI_KC;
output reg [2:0] SPI_CALIORDER;
output reg [2:0] SPI_PSEC;
output reg [1:0] SPI_SECSEL_TEST;
output reg [3:0] SPI_REGSEL_TEST;
output reg SPI_LO_PHASECAL_EN;
output reg [2:0] SPI_LO_DIV;
output reg [4:0] SPI_LO_PCALI_KI;
output reg [4:0] SPI_LO_PCALI_KI_iir;
output reg SPI_LO_PCALI_DN_EN;
output reg SPI_SNPCNTTDC_EN;
output reg SPI_CNTPREDIV_EN;
output reg SPI_DSM_BOOTMODE;
output reg [2:0] SPI_SYS_EDGE_SEL;
output reg SPI_LO_PHASECAL_EN_SEL;
output reg SPI_OTWCALI_EN;

parameter real fref = 100e6;
// parameter real fcw = 51;
// parameter real fcw = 50.125;
parameter real fcw = 50.132;

initial begin
	#2;
	SPI_CONFIG = 0;
	SPI_NARST = 1;

	#2; // get the ctrl right for loop
	SPI_CTRL = 1;
	
	#2; // disable all parts in the loop
	SPI_PLL_EN = 0;
	SPI_AFC_EN = 0;
	SPI_FAFC_EN = 0;
	SPI_PHESIG_GEN_EN = 0;
	SPI_DTC_GAINCAL_EN = 0;
	SPI_CAL_MODE = 0;
	SPI_DTC_EN = 0;
	SPI_MMD_EN = 0;
	SPI_DSM_EN = 0;
	SPI_DN_EN = 0;
	SPI_DN_S = 2'b00;
	SPI_SPD_EN = 0;
	SPI_PFD_EN = 0;
	SPI_CP_EN = 0;
	SPI_PRECHARGE_EN = 0;
	SPI_OTWSOURCE = 0; // OTW ctrl by spi-0
	SPI_OTWSEL = 3'b100;
	SPI_EDGESEL = 1'b0;
	SPI_TDCRESNORM = 16'd9; // TDC_res_norm = Tres/(Tref)/(M-1)
	SPI_MMDRSTSEL = 1'b1;
	SPI_PFDRSTSEL = 1'b1;
	SPI_AUXMMD_SEL = 1'b1;
	SPI_FCW_MGN = 8'd4; // SPI_FCW_MGN_O*fref = (kdco/2)/x, x=2->mgn=kdco/fref/4
	SPI_DIGRST = 1'b0; // power up -- 0; dig ctrl freq jump -- 1
	SPI_PDS_EN = 1'b0;
	SPI_LO_PCALI_DN_EN = 1'b0;
	SPI_LO_PHASECAL_EN = 1'b0;
	SPI_SNPCNTTDC_EN = 1'b0;
	SPI_CNTPREDIV_EN = 1'b0;
	SPI_DSM_BOOTMODE = 1'b0;
	SPI_SYS_EDGE_SEL = 3'd1;
	SPI_LO_PHASECAL_EN_SEL = 0;
	SPI_OTWCALI_EN = 0;
	
	#2; // loop parameters setting
	SPI_ALPHA = 4'b1110;
	SPI_KDTCA_INIT = 13'd0;
	SPI_KDTCB_INIT = 1.0/(fcw*fref)/500e-15*1.0;
	SPI_KDTCC_INIT = 1.0/(fcw*fref)/500e-15*1.0;
	SPI_KA = -5'd8;
	SPI_KB = -5'd8;
	SPI_KC = -5'd8;
	SPI_CALIORDER = 3'b011;
	SPI_PSEC = 3'd4; // 1 segment
	SPI_SECSEL_TEST = 2'b10; // LUTB
	SPI_REGSEL_TEST = 4'd0;
	SPI_LO_DIV = 3'd0; // prediv2 * 2 = div4
	SPI_LO_PCALI_KI = 0; // -16~15
	SPI_LO_PCALI_KI_iir = 0; // 0~31
	SPI_DSM_BOOTMODE = 1'b0; // mode 0: normal; mode 1: fractional fcw send to DSM untill system ref trigger
	SPI_SYS_EDGE_SEL = 3'd1;
	SPI_LO_PHASECAL_EN_SEL = 0;
	
	SPI_DN_WEIGHT = 12;
	SPI_MMD_P = 50; 
	SPI_MMD_S = 4;
	SPI_FCW_MULTI = 7'd50;
	SPI_FAFC_FMULTI = 4'd8; // 80M
	SPI_FCW = fcw*(2.0**`WF);
	SPI_CP = 9'd60;
	SPI_CS = 9'd60;

	#2; // loop ctrl setting
	// PFDCP frac(MMD+DTC+DSM)
	SPI_PRECHARGE_EN = 0; // stop precharge
	SPI_PHESIG_GEN_EN = 1'b1;
	SPI_DTC_GAINCAL_EN = 1'b0;
	SPI_CAL_MODE = 1'b0; // from strARM
	SPI_DTC_EN = 1'b1;
	SPI_MMD_EN = 1'b1;
	SPI_DSM_EN = 1'b1;
	SPI_DN_EN = 1'b0;
	SPI_DN_S = 2'b00;
	SPI_SPD_EN = 1'b0;
	SPI_PFD_EN = 1'b1;
	SPI_CP_EN = 1'b1;
	SPI_LO_PCALI_DN_EN = 1'b1;
	SPI_LO_PHASECAL_EN = 1'b0;
	
	// #2; // loop ctrl setting
	// // SPDGM frac(MMD+DTC+DSM)
	// SPI_PRECHARGE_EN = 0; // stop precharge
	// SPI_PHESIG_GEN_EN = 1'b1;
	// SPI_DTC_GAINCAL_EN = 1'b1;
	// SPI_CAL_MODE = 1'b1; // from VDAC
	// SPI_DTC_EN = 1'b1;
	// SPI_MMD_EN = 1'b1;
	// SPI_DSM_EN = 1'b1;
	// SPI_DN_EN = 1'b0;
	// SPI_DN_S = 2'b10;
	// SPI_SPD_EN = 1'b1;
	// SPI_PFD_EN = 1'b0;
	// SPI_CP_EN = 1'b0;
	
	#2;
	SPI_NARST = 0;
	#20;
	SPI_NARST = 1;

	#5; // release ctrl right of loop except AFC
	SPI_CTRL = 0;
	#2; // enable pll
	SPI_PLL_EN = 1;
	SPI_AFC_EN = 0;
	SPI_FAFC_EN = 1;
	
	// load in parameter
	#2;
	SPI_NARST = 0;
	#20;
	SPI_NARST = 1;
	#1000; // 1us

	// SPI_DIGRST = 1'b1;
	// // load in parameter
	// #2;
	// SPI_NARST = 0;
	// #200;
	// SPI_NARST = 1;
	// #1000; // 1us
	
	// SPI_PHESIG_GEN_EN = 1'b1;
	// SPI_DTC_GAINCAL_EN = 1'b1;
	// SPI_CAL_MODE = 1'b0;
	// SPI_DTC_EN = 1'b1;
	// SPI_MMD_EN = 1'b1;
	// SPI_DSM_EN = 1'b1;
	// SPI_DN_EN = 1'b0;
	// SPI_DN_S = 2'b00;
	// SPI_SPD_EN = 1'b0;
	// SPI_PFD_EN = 1'b1;
	// SPI_CP_EN = 1'b1;	
	// #2;
	// SPI_CONFIG = 1;
	// #20;
	// SPI_CONFIG = 0;

	#20000; // 20us
	// SPI_LO_PHASECAL_EN = 1'b1;
	// #2;
	// SPI_CONFIG = 1;
	// #20;
	// SPI_CONFIG = 0;
	// #150000; // 100us
	// SPI_LO_PCALI_KI = -8; // -16~15
	// SPI_LO_PCALI_KI_iir = 3; // 0~31
	// #2;
	// SPI_CONFIG = 1;
	// #20;
	// SPI_CONFIG = 0;
	SPI_OTWCALI_EN = 1;
	#13000;
	SPI_OTWCALI_EN = 0;
	#10000;
	SPI_OTWCALI_EN = 1;
end

endmodule