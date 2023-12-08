`timescale 1s / 1fs

// word width define
`define WI 9
`define WF 26
`define WFPHASE 16
`define OTW_L 9
`define DTC_L 12


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

PHE_SIG, PHE_SIG2,

LO_STATE, SPI_LO_DIV, SPI_LO_PCALI_KI, SPI_LO_PCALI_KI_iir, SPI_LO_PCALI_DN_EN, SPI_LO_PHASECAL_EN,
// output
O_PHESIG_GEN_EN, O_DTC_GAINCAL_EN, O_DN_EN, O_DTC_EN, O_MMD_EN, O_DSM_EN, O_PDS_EN, O_PRECHARGE_EN, O_PFD_EN, O_CP_EN, O_SPD_EN, O_SNPCNTTDC_EN, O_CNTPREDIV_EN,
O_MMD_P, O_MMD_S, DCW_DELAY, VDACCTRL_OUTP, VDACCTRL_OUTN,
SPI_FCW_O, SPI_MMD_P_O, SPI_MMD_S_O, SPI_FCW_MULTI_O, SPI_FAFC_FMULTI_O, SPI_TDCRESNORM_O, SPI_AUXMMD_SEL_O, SPI_FCW_MGN_O,
O_CP, O_CS, O_CP_N, O_CS_N, SPI_OTWSEL_O,
KDTC_INT, FLOCK, LO_PCALI_DONE
);

// rst
input SPI_NARST;
input SYNC_EN;
input SYNC_REF;

// CLK
input CKVD;
input SPI_CONFIG;
input [9+26-1:0] SPI_FCW;
input PHE_SIG;
input PHE_SIG2;
output reg [9+26-1:0] SPI_FCW_O;

input SPI_PLL_EN;			// all enable signal canbe disable

input AFC_CTRL;				// en signal ctrl right to afc
input FAFC_CTRL;
input SPI_DIGRST;
input SPI_AFC_EN;
input SPI_FAFC_EN;
input FREQLOCK;
input FREQLOCK2;
input [9-1:0] AFC_OTWP;
input [9-1:0] AFC_OTWN;
input [9-1:0] FAFC_OTWP;
input [9-1:0] FAFC_OTWN;

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
input [9-1:0] SPI_CP;
input [9-1:0] SPI_CS;
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
reg [9-1:0] SPI_CP_O;
reg [9-1:0] SPI_CS_O;
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
output [9-1:0] O_CP;
output [9-1:0] O_CS;
output [9-1:0] O_CP_N;
output [9-1:0] O_CS_N;
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
.O_CNTPREDIV_EN		(O_CNTPREDIV_EN		)
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
.LO_DIV			(SPI_LO_DIV_O		),
.LO_STATE		(LO_STATE			),
.LO_PCALI_KI	(SPI_LO_PCALI_KI_O	),
.LO_PCALI_KI_iir(SPI_LO_PCALI_KI_iir_O	),
.LO_PCALI_DN_EN	(SPI_LO_PCALI_DN_EN_O),
.LO_PCALI_DONE 	(LO_PCALI_DONE)
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
