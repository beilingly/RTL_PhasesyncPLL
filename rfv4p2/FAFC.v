// word width define
`define WI 9
`define WF 16
`define OTW_L 9
// -------------------------------------------------------
// Module Name: FAFC
// Function: fast auto freq-ctrl
// Author: Yang Yumeng Date: 4/6 2022
// Version: v1p0
// -------------------------------------------------------
module FAFC (
// input
SPI_NARST,
SPI_FAFC_EN,
REF,
CNT7BIT,
TDCCODE,
SPI_AUXMMD_SEL_O,
SPI_FCW_O,
SPI_FCW_MGN_O,
SPI_FAFC_FMULTI_O,
SPI_TDCRESNORM_O,
// output
FAFC_OTWP,
FAFC_OTWN,
FREQLOCK2,
FAFC_CTRL,
NRST2,
MMDNRST_FAFC,
QN1S,
QN2S,
QP1S,
QP2S
);

// io declaration
input SPI_FAFC_EN;
input SPI_NARST;
input REF;
input [6:0] CNT7BIT;
input [5:0] TDCCODE;
input SPI_AUXMMD_SEL_O;
input [`WI+`WF-1:0] SPI_FCW_O;
input [7:0] SPI_FCW_MGN_O;
input [4:0] SPI_FAFC_FMULTI_O;
input [`WF-1:0] SPI_TDCRESNORM_O; // TDC_res_norm = Tres/(Tref)/M

output [`OTW_L-1:0] FAFC_OTWP;
output [`OTW_L-1:0] FAFC_OTWN;
output reg FREQLOCK2;
output reg FAFC_CTRL;
output MMDNRST_FAFC;
output reg [7:2] QN1S;
output reg [7:2] QN2S;
output reg [7:2] QP1S;
output reg [7:2] QP2S;

// internal signal
wire NRST;
wire NRST1;
output wire NRST2;
reg NRST2_dff;
wire NRST1_pre;
reg FAFC_CTRL_in;
reg [6:0] phv_smp;
wire [6:0] phvcnt;
wire [12:0] phvcnt_sum; // 500M/40M<=16 7bit + 6bit
reg [12:0] phvcnt_sum_smp;
wire [5:0] tdcnum;
reg [5:0] tdcnum_smp [0:31];
wire [5:0] tdccnt; // signed
wire tdccnt_sign;
wire [5+`WF:0] tdccnt_norm;
// wire [5+`WF:0] diva;
wire [4:0] divb;
// wire [5+`WF:0] quo;
// wire [5+`WF:0] rem;
wire [5+`WF:0] tdccalc;

reg [4:0] refcnt;
reg [4:0] refcnt_max;

reg [3:0] poscnt; // label for sar adjust position
reg sar_win;
wire sar_assert; // assert sar logic
wire comp; // compare fv to fcw
reg [`OTW_L-1:0] sarcode;
reg [`OTW_L-1:0] sarcode_dff;
wire [12+`WF:0] fcw_measure;
wire [12+`WF:0] SPI_FCW_O_ext;

wire [`WI+`WF-1:0] fcw_margin;
wire [`WI-1:0] FCW_I;

reg MMDNRST_reg;

genvar geni;

// TDC decoder
// TDCDECODER U0_TDCDECODER (
// .IN64BIT(TDCCODE),
// .OUT6BIT(tdcnum)
// );
assign tdcnum = TDCCODE;

// VPAC CNT
assign fcw_margin = SPI_FCW_O + (SPI_FCW_MGN_O<<8); // SPI_FCW_MGN_O*fref = (kdco/2)/x, x=2->mgn=kdco/fref/4
assign SPI_FCW_O_ext = fcw_margin * divb;
assign fcw_measure = (phvcnt_sum<<SPI_AUXMMD_SEL_O) * tdccalc;
assign comp = (fcw_measure >= SPI_FCW_O_ext)? 1'b1: 1'b0;

assign phvcnt_sum = phvcnt_sum_smp + phvcnt;
assign phvcnt = CNT7BIT - phv_smp;
assign tdccnt_sign = (tdcnum <= tdcnum_smp[divb]);
assign tdccnt = tdccnt_sign? (tdcnum_smp[divb] - tdcnum): (tdcnum - tdcnum_smp[divb]);
USWI1WF16SHIFT #(.width_int(`WF), .width_frac(6)) U0_TDCCODENORM_PRO ( .PRO(tdccnt_norm), .MULTIAI(SPI_TDCRESNORM_O), .MULTIBF(tdccnt) );
// assign diva = tdccnt_norm;
assign divb = (SPI_FAFC_FMULTI_O-1);
// USWI16DIV #(.WI(6+`WF)) U0_DIV ( .DIVA(diva), .DIVB(divb), .QUO(quo), .REM(rem) );
// assign tdccalc = (1'b1 << `WF) + (tdccnt_sign? quo: (~quo+1'b1));
assign tdccalc = (1'b1 << `WF) + (tdccnt_sign? tdccnt_norm: (~tdccnt_norm+1'b1));

always @ (posedge REF or negedge NRST) begin
	if (!NRST) begin
		phv_smp <= 0;
		phvcnt_sum_smp <= 0;
	end else if (SPI_FAFC_EN) begin
		phv_smp <= CNT7BIT;
		phvcnt_sum_smp <= (sar_win&(refcnt==0))? 0: phvcnt_sum;
	end
end

always @ (posedge REF or negedge NRST) begin
	if (!NRST) begin
		tdcnum_smp[0] <= 0;
		tdcnum_smp[1] <= 0;
	end else if (SPI_FAFC_EN) begin
		tdcnum_smp[0] <= 0;
		tdcnum_smp[1] <= tdcnum;
	end
end

generate
	for (geni=2; geni<=31; geni=geni+1) begin
		always @ (posedge REF or negedge NRST) begin
			if (!NRST) begin
				tdcnum_smp[geni] <= 0;
			end else if (SPI_FAFC_EN) begin
				tdcnum_smp[geni] <= tdcnum_smp[geni-1];
			end
		end
	end
endgenerate


// LOOP EN
// FREQCLOCK asserted if SAR logic is done
always @ (posedge REF) begin
	NRST2_dff <= NRST2;
end

assign NRST1_pre = ~((~NRST2)&NRST2_dff);

always @ (posedge REF or negedge NRST1_pre) begin
	if (!NRST1_pre) begin
		// disable loop
		FAFC_CTRL <= 1'b0;
	end else if (SPI_FAFC_EN) begin
		if (FREQLOCK2) begin
			FAFC_CTRL <= 1'b0;
		end else begin
			FAFC_CTRL <= ((poscnt==`OTW_L-1)&(refcnt == refcnt_max-1))? 1'b0: 1'b1;
		end
	end
end

always @ (posedge REF or negedge NRST2) begin
	if (!NRST2) begin
		// disable loop
		FAFC_CTRL_in <= 1'b0;
		FREQLOCK2 <= 1'b0;
	end else if (SPI_FAFC_EN) begin
		if (FREQLOCK2) begin
			FAFC_CTRL_in <= 1'b0;
			FREQLOCK2 <= FREQLOCK2;
		end else begin
			FAFC_CTRL_in <= 1'b1;
			FREQLOCK2 <= ((poscnt==`OTW_L-1)&(refcnt == refcnt_max-1))? 1'b1: 1'b0;
		end
	end
end

// SAR
// update sar adjustment position
assign FAFC_OTWP = sarcode_dff;
assign FAFC_OTWN = ~sarcode_dff;

assign sar_assert = sar_win & (refcnt == refcnt_max-1);
always @ (posedge REF or negedge NRST2) begin
	if (!NRST2) begin
		refcnt_max <= 50; 
		refcnt <= 0;
		poscnt <= 0;
		sar_win <= 0;
	end else if (SPI_FAFC_EN) begin
		refcnt_max <= SPI_FAFC_FMULTI_O; 
		if (refcnt == refcnt_max-1) begin 
			refcnt <= 0;
			poscnt <= (poscnt<`OTW_L)? (poscnt + 1): poscnt;
			sar_win <= (poscnt>=`OTW_L-1)? 1'b0: 1'b1;
		end else begin
			refcnt <= FAFC_CTRL_in? refcnt + 1: 0;
			sar_win <= (poscnt>=`OTW_L)? 1'b0: 1'b1;
		end
	end
end

always @ (posedge REF or negedge NRST2) begin
	if (!NRST2) begin 
		sarcode_dff <= (1'b1 << (`OTW_L-1));
	end else if (SPI_FAFC_EN) begin
		if (sar_assert) sarcode_dff <= sarcode;
		else sarcode_dff <= sarcode_dff;
	end
end

always @* begin
	if (sar_assert) begin
		if (poscnt<(`OTW_L-1)) begin
			if (comp) sarcode = sarcode_dff - (1'b1<<(`OTW_L-poscnt-2));
			else sarcode = sarcode_dff + (1'b1<<(`OTW_L-poscnt-2));
		end else begin
			if (comp) sarcode = sarcode_dff - 1'b1;
			else sarcode = sarcode_dff;
		end
	end else begin
		sarcode = 0;
	end
end

SYNCRSTGEN U0_SYNCRST ( .CLK (REF), .NARST (SPI_NARST), .NRST (NRST), .NRST1(NRST1), .NRST2(NRST2) );

always @ (posedge REF or negedge NRST) begin
	if (!NRST) MMDNRST_reg <= 1'b1;
	else MMDNRST_reg <= ((poscnt==`OTW_L-1)&(refcnt == refcnt_max-1))? 1'b0: 1'b1;
end

assign MMDNRST_FAFC = SPI_FAFC_EN? MMDNRST_reg: SPI_NARST;

// MMD rst initial
assign FCW_I = SPI_FCW_O[`WI+`WF-1:`WF];

always @ (posedge REF or negedge NRST) begin
	if (!NRST) begin
		QN1S <= 6'b111111;
		QN2S <= 6'b000000;
		QP1S <= 6'b000000;
		QP2S <= 6'b111111;
	end else begin
		if (SPI_FAFC_EN) begin
			if (FCW_I <= 32) begin
				QN1S <= 6'b000011;
				QN2S <= 6'b011100;
				QP1S <= 6'b100010;
				QP2S <= 6'b000100;
			end else if (FCW_I <= 64) begin
				QN1S <= 6'b000110;
				QN2S <= 6'b000000;
				QP1S <= 6'b110101;
				QP2S <= 6'b001000;
			end else if (FCW_I <= 128) begin
				QN1S <= 6'b001100;
				QN2S <= 6'b000000;
				QP1S <= 6'b101011;
				QP2S <= 6'b010000;
			end else begin
				QN1S <= 6'b011000;
				QN2S <= 6'b000000;
				QP1S <= 6'b010111;
				QP2S <= 6'b100000;
			end
		end else begin
			QN1S <= 6'b111111;
			QN2S <= 6'b000000;
			QP1S <= 6'b000000;
			QP2S <= 6'b111111;
		end
	end
end

endmodule