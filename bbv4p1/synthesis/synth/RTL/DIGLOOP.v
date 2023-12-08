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
SPI_PLL_EN, SPI_CTRL, AFC_CTRL, FREQLOCK,
SPI_PHESIG_GEN_EN, SPI_DTC_GAINCAL_EN, SPI_DTC_EN, SPI_MMD_EN, SPI_DSM_EN, SPI_DN_EN, SPI_SPD_EN, SPI_PFD_EN, SPI_CP_EN, SPI_PRECHARGE_EN,
SPI_FCW, SPI_KDTC_INIT, SPI_KA, SPI_ALPHA, SPI_DN_WEIGHT, SPI_CAL_MODE,

SPI_CP, SPI_CS, SPI_OTWSOURCE, SPI_OTWSEL,

SPI_FCW_MULTI, SPI_MMD_P, SPI_MMD_S,
AFC_OTWP, AFC_OTWN,

PHE_SIG, PHE_SIG2,

LO_STATE, SPI_LO_DIV, SPI_LO_DIV5, SPI_LO_PCALI_KI, SPI_LO_PCALI_KI_iir, SPI_LO_PCALI_DN_EN, SPI_LO_PHASECAL_EN,
// output
O_PHESIG_GEN_EN, O_DTC_GAINCAL_EN, O_DN_EN, O_DTC_EN, O_MMD_EN, O_DSM_EN, O_PRECHARGE_EN, O_PFD_EN, O_CP_EN, O_SPD_EN,
O_MMD_P, O_MMD_S, DCW_DELAY, VDACCTRL_OUTP, VDACCTRL_OUTN,
SPI_FCW_O, SPI_MMD_P_O, SPI_MMD_S_O, SPI_FCW_MULTI_O,
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
input FREQLOCK;
input [9-1:0] AFC_OTWP;
input [9-1:0] AFC_OTWN;

input SPI_CTRL;				// en signal ctrl right to spi
input SPI_PHESIG_GEN_EN;
input SPI_DTC_GAINCAL_EN;
input SPI_DTC_EN;
input SPI_MMD_EN;
input SPI_DSM_EN;
input SPI_DN_EN;
input SPI_SPD_EN;
input SPI_PFD_EN;
input SPI_CP_EN;
input SPI_PRECHARGE_EN;
input [12:0] SPI_KDTC_INIT;
input [4:0] SPI_KA;
input [3:0] SPI_ALPHA;
input [4:0] SPI_DN_WEIGHT;
input SPI_CAL_MODE;
input [9-1:0] SPI_CP;
input [9-1:0] SPI_CS;
input SPI_OTWSOURCE; // determin otw controlled by afc or spi
input [2:0]  SPI_OTWSEL;

input [6:0] SPI_FCW_MULTI;
input [8:0] SPI_MMD_P;
input [2:0] SPI_MMD_S;

input SPI_LO_PHASECAL_EN;
input [2:0] SPI_LO_DIV;
input SPI_LO_DIV5;
input [4:0] SPI_LO_PCALI_KI;
input [4:0] SPI_LO_PCALI_KI_iir;
input SPI_LO_PCALI_DN_EN;
input [1:0] LO_STATE;

// DTC MMD CTRL
wire NRST;
wire NRST1;
wire NRST2;
wire inrst;

reg [12:0] SPI_KDTC_INIT_O;
reg [4:0] SPI_KA_O;
reg [3:0] SPI_ALPHA_O;
reg [4:0] SPI_DN_WEIGHT_O;
reg SPI_OTWSOURCE_O;
reg [9-1:0] SPI_CP_O;
reg [9-1:0] SPI_CS_O;
reg SPI_CAL_MODE_O;
reg [2:0] SPI_LO_DIV_O;
reg SPI_LO_DIV5_O;
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
output O_PRECHARGE_EN;
output O_PFD_EN;
output O_CP_EN;
output O_SPD_EN;

// output to spi reg
output [12:0] KDTC_INT;
output FLOCK;
output LO_PCALI_DONE;

// input register
reg conf_reg;
wire conf_win;

assign conf_win = conf_reg;

assign inrst = NRST;

always @ (posedge CKVD or negedge inrst) begin
	if (!inrst) begin
		conf_reg <= 1'b1;
	end else if (SPI_CONFIG) conf_reg <= 1'b1;
	else conf_reg <= 1'b0;
end

assign FLOCK = FREQLOCK;

always @ (posedge CKVD or negedge NRST) begin
	if (!NRST) begin
		// spi ctrl init
		SPI_FCW_O		<= SPI_FCW;
		SPI_KA_O 		<= SPI_KA;
		SPI_ALPHA_O		<= SPI_ALPHA;
		SPI_KDTC_INIT_O <= SPI_KDTC_INIT;
		SPI_DN_WEIGHT_O <= SPI_DN_WEIGHT;
		SPI_OTWSOURCE_O	<= SPI_OTWSOURCE;
		SPI_OTWSEL_O	<= SPI_OTWSEL;
		SPI_CP_O		<= SPI_CP;
		SPI_CS_O		<= SPI_CS;
		SPI_MMD_P_O		<= SPI_MMD_P;
		SPI_MMD_S_O		<= SPI_MMD_S;
		SPI_FCW_MULTI_O	<= SPI_FCW_MULTI;
		SPI_CAL_MODE_O	<= SPI_CAL_MODE;
		SPI_LO_DIV_O		<= SPI_LO_DIV;
		SPI_LO_DIV5_O		<= SPI_LO_DIV5;
		SPI_LO_PCALI_KI_O	<= SPI_LO_PCALI_KI;
		SPI_LO_PCALI_KI_iir_O	<= SPI_LO_PCALI_KI_iir;
		SPI_LO_PCALI_DN_EN_O<= SPI_LO_PCALI_DN_EN;
		SPI_LO_PHASECAL_EN_O<= SPI_LO_PHASECAL_EN;
	end else if (conf_win) begin
		SPI_FCW_O		<= SPI_FCW;
		SPI_KA_O 		<= SPI_KA;
		SPI_ALPHA_O		<= SPI_ALPHA;
		SPI_KDTC_INIT_O <= SPI_KDTC_INIT;
		SPI_DN_WEIGHT_O <= SPI_DN_WEIGHT;
		SPI_OTWSOURCE_O	<= SPI_OTWSOURCE;
		SPI_OTWSEL_O	<= SPI_OTWSEL;
		SPI_CP_O		<= SPI_CP;
		SPI_CS_O		<= SPI_CS;
		SPI_MMD_P_O		<= SPI_MMD_P;
		SPI_MMD_S_O		<= SPI_MMD_S;
		SPI_FCW_MULTI_O	<= SPI_FCW_MULTI;
		SPI_CAL_MODE_O	<= SPI_CAL_MODE;
		SPI_LO_DIV_O		<= SPI_LO_DIV;
		SPI_LO_DIV5_O		<= SPI_LO_DIV5;
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
.SPI_MMD_P          (SPI_MMD_P_O        ),
.SPI_MMD_S          (SPI_MMD_S_O        ),
.AFC_OTWP           (AFC_OTWP           ),
.AFC_OTWN           (AFC_OTWN           ),
.SPI_CTRL           (SPI_CTRL           ),
.SPI_PHESIG_GEN_EN 	(SPI_PHESIG_GEN_EN ),
.SPI_DTC_GAINCAL_EN (SPI_DTC_GAINCAL_EN ),
.SPI_DTC_EN         (SPI_DTC_EN         ),
.SPI_MMD_EN         (SPI_MMD_EN         ),
.SPI_DSM_EN         (SPI_DSM_EN         ),
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
.O_CS_N            	(O_CS_N            	)
);

DTCMMD_CTRL U0_DTCMMDCTRL(
.NRST			(inrst				),
.DSM_EN			(O_DSM_EN			),
.DN_EN			(O_DN_EN			),
.DN_WEIGHT		(SPI_DN_WEIGHT_O	),
.MMD_EN			(O_MMD_EN			),
.DTC_EN			(O_DTC_EN			),
.GAC_EN			(O_DTC_GAINCAL_EN	),
.SYS_REF		(SYNC_REF			),
.SYS_EN			(SYNC_EN			),
.FCW			(SPI_FCW_O			),
.CKVD			(CKVD				),
.KDTC_INIT		(SPI_KDTC_INIT_O	),
.KA				(SPI_KA_O			),
.PHE_SIG		(PHE_SIG			),
.PHE_SIG2		(PHE_SIG2			),
.GAC_MODE		(SPI_CAL_MODE_O		),
.MMD_S_DFF		(MMD_S				),
.MMD_P_DFF		(MMD_DCW			),
.DCW_DELAY		(DCW_DELAY			),
.KDTC_INT		(KDTC_INT			),
.LO_PHASECAL_EN	(SPI_LO_PHASECAL_EN_O),
.LO_DIV			(SPI_LO_DIV_O		),
.LO_DIV5		(SPI_LO_DIV5_O		),
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
