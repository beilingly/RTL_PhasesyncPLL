// word width define
`define WI 9
`define WF 8
`define OTW_L 9

// -------------------------------------------------------
// Module Name: SAR_CTRL
// Function: 
// Author: Yang Yumeng Date: 6/27 2021
// Version: v1p0
// -------------------------------------------------------
module SAR_CTRL (
// input
SPI_AFC_EN,
SPI_NARST,
REF,
CKVD,
SPI_MMD_P_O,	// divider num for freq lock
// SPI_MMD_S_O,
SPI_FCW_MULTI_O, // control freq measure resolution (1 for fref)
SPI_FCW_O,
//output
// AFC_MMD_P,
// AFC_MMD_S,
AFC_OTWP,
AFC_OTWN,
FREQLOCK,
// LOOP EN SIGNAL
AFC_CTRL
);

// parameter
parameter integer sampcnt_max = 20;

// io
input SPI_AFC_EN;
input SPI_NARST;
input REF;
input CKVD;
input [8:0] SPI_MMD_P_O;
// input [2:0] SPI_MMD_S_O;
input [6:0] SPI_FCW_MULTI_O; // AFC res = fref / fcw_multi
input [9+8-1:0] SPI_FCW_O;
// output reg [8:0] AFC_MMD_P;
// output reg [2:0] AFC_MMD_S;
output [9-1:0] AFC_OTWP;
output [9-1:0] AFC_OTWN;
output reg FREQLOCK;
// LOOP EN SIGNAL 
output reg AFC_CTRL;

// internal signal
wire sync_nrst;

// OTW
reg [9-1:0] OTW;

reg [9+6-1:0] refcnt; // (maximum: 7000)
// wire [9+6-1:0] refcnt_max; 
reg [9+6-1:0] refcnt_max; 
reg [9+9-1:0] phv;
reg [9+9-1:0] phv_smp;
reg [9+9-1:0] phv_diff;
wire [9+8+9-1:0] phv_diff_ext;
wire signed [9+8+9:0] phv_diff_signed;
// wire [9+8+9-1:0] fcw_ext;
reg [9+8+9-1:0] fcw_ext;
wire signed [9+8+9:0] fcw_signed;
reg sampclk1;
reg sampclk2;
wire sampsig1;
wire sampsig2;
wire sampwin1;
wire sampwin2;
reg [9+9-1:0] phv_dff_pre1;
reg [9+9-1:0] phv_dff_pre2;
wire comp; // compare fv to fcw
reg sar_assert; // assert sar logic
reg range_assert; //assert for calculate deep sweep range
reg [1:0] search_mode; // 1 for coarse search mode, 2 for deep search mode
reg [3:0] poscnt; // label for sar adjust position
reg [9-1:0] sarcode;
reg [9-1:0] sarcode_dff;

reg [1:0] sar_state;
reg [9-1:0] sweep_init;
reg [3:0] rangenum;
reg [1:0] sar_state_dff;
reg [9-1:0] sweep_init_dff;
reg [3:0] rangenum_dff;

reg deep_assert;
reg final_assert;
wire signed [9+8+9:0] fe_cur;
wire [9+8+9-1:0] absfe_cur;
reg [9+8+9-1:0] absfe_done;
reg [9+8+9-1:0] absfe_done_dff;
reg [3:0] propose;
reg [3:0] propose_dff;

reg [3:0] sweepcnt;
reg [9-1:0] deepcode_dff;
reg [9-1:0] deepcode;

reg [9-1:0] otw_sel;

// sync_async_reset U_SYNC_NRST (REF, SPI_NARST, sync_nrst);
SYNCRSTGEN U0_SYNCRST ( .CLK (REF), .NARST (SPI_NARST), .NRST (sync_nrst), .NRST2(), .NRST1() );

// OTW output 
assign AFC_OTWP = OTW;
assign AFC_OTWN = ~OTW;
// MMD output
// assign AFC_MMD = SPI_MMDDIV_O;
// assign AFC_MMD_S = SPI_MMDS_O;

// always @ (posedge REF or negedge sync_nrst) begin
	// if (!sync_nrst) begin
		// AFC_MMD_P <= 100;
		// AFC_MMD_S <= 3'b101;
	// end else begin
		// AFC_MMD_P <= SPI_MMD_P_O;
		// AFC_MMD_S <= SPI_MMD_S_O;
	// end
// end

// LOOP EN
always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst) begin
		// disable loop
		AFC_CTRL <= 1'b0;
	end else if (SPI_AFC_EN) begin
		if (FREQLOCK) begin
			// release the control right
			// (SPI_CTRL_EN=0/1) the control right is given to SPI
			AFC_CTRL <= 1'b0;
		end else begin
			// enable pfd/cp MMD
			AFC_CTRL <= 1'b1;
		end
	end
end

// SAR CTRL begin from here
// FREQCLOCK asserted if SAR logic is done
always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst) FREQLOCK <= 1'b0;
	else if (SPI_AFC_EN) begin
		if (!FREQLOCK) FREQLOCK <= final_assert? 1'b1: 1'b0;
		else FREQLOCK <= FREQLOCK;
	end
end

// select otw signal
always @* begin
	if (sar_assert) begin
		if (range_assert) otw_sel = sweep_init;
		else otw_sel = sarcode;
	end else if (deep_assert) begin
		otw_sel = deepcode;
	end else 
		otw_sel = 0;
end

always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst) OTW <= 1'b1 << (9-1);
	else if (SPI_AFC_EN) begin
		if (sar_assert || deep_assert) OTW <= otw_sel;
		else OTW <= OTW;
	end
end

// // update search mode
always @ (posedge REF) begin
	refcnt_max <= SPI_MMD_P_O * SPI_FCW_MULTI_O;	// MMD basic divN is 100
end

always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst) search_mode <= 2'b00;
	else if (SPI_AFC_EN) begin
		if ((poscnt<9)&&refcnt==sampcnt_max) search_mode <= 2'b01; // init coarse search mode
		else if ((poscnt>=9)&&refcnt==sampcnt_max)search_mode <= 2'b10; // init deep search mode
		else search_mode <= search_mode;
	end
end

// count 0 to 200
always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst)
		refcnt <= refcnt_max+sampcnt_max-5;
	else if (SPI_AFC_EN) begin
		if (refcnt<refcnt_max+sampcnt_max) refcnt <= refcnt+1'b1;
		else refcnt <= 1'b0;
	end
end

// calculate vco frequancy
// counter for ckv
always @ (posedge CKVD or negedge sync_nrst) begin
	if (!sync_nrst)
		phv <= 0;
	else if (SPI_AFC_EN) begin
		phv <= phv + 1'b1;
	end
end

// eliminate metastable state
always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst)
		sampclk1 <= 1'b0;
	else if (SPI_AFC_EN) begin
		if ((refcnt>=sampcnt_max) && (refcnt<(refcnt_max>>1))) sampclk1 <= 1'b1;
		else sampclk1 <= 1'b0;
	end
end

always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst)
		sampclk2 <= 1'b0;
	else if (SPI_AFC_EN) begin
		if ((refcnt<(refcnt_max>>1)) || (refcnt==refcnt_max+sampcnt_max)) sampclk2 <= 1'b1;
		else sampclk2 <= 1'b0;
	end
end

METADFF U_METADFF0 ( .NARST(sync_nrst), .CLKDATA(sampclk1), .CLKSMP(CKVD), .WIN(sampsig1), .EN(SPI_AFC_EN) );
METADFF U_METADFF1 ( .NARST(sync_nrst), .CLKDATA(sampclk2), .CLKSMP(CKVD), .WIN(sampsig2), .EN(SPI_AFC_EN) );

always @ (posedge CKVD or negedge sync_nrst) begin
	if (!sync_nrst) begin
		phv_dff_pre1 <= 0;
		phv_dff_pre2 <= 0;
	end else if (SPI_AFC_EN) begin
		phv_dff_pre1 <= sampsig1? phv: phv_dff_pre1;
		phv_dff_pre2 <= sampsig2? phv: phv_dff_pre2;
	end
end


// phase differential
assign sampwin1 = (refcnt == (sampcnt_max<<1)-1);
assign sampwin2 = (refcnt == sampcnt_max-1);

always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst) begin
		phv_smp <= 0;
		phv_diff <= 0;
	end else if (SPI_AFC_EN) begin
		phv_smp <= sampwin1? phv_dff_pre1: phv_smp;
		phv_diff <= sampwin2? (phv_dff_pre2 - phv_smp): phv_diff;
	end
end


// coarse search logic
// SAR
// update sar adjustment position
always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst) poscnt <= 4'd1;
	else if (SPI_AFC_EN) begin
		if ((search_mode==2'b01)&&(refcnt==sampcnt_max)) poscnt <= poscnt + 1'b1;// 9-1 to 0
		else poscnt <= poscnt;
	end
end

// assign sar_assert = SPI_AFC_EN & (refcnt==8'd200) & (search_mode==2'b01); // race and competition
// assign range_assert = sar_assert & (poscnt==9);
always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst) begin 
		sar_assert <= 1'b0;
		range_assert <= 1'b0;
	end else if (SPI_AFC_EN) begin
		if ((refcnt==(sampcnt_max-1'b1)) && (search_mode==2'b01)) begin
			sar_assert <= 1'b1;
			range_assert <= (poscnt==9)? 1'b1: 1'b0;
		end else begin 
			sar_assert <= 1'b0;
			range_assert <= 1'b0;
		end
	end
end

always @ (posedge REF) begin
	fcw_ext <= SPI_FCW_O * SPI_FCW_MULTI_O;
end
assign phv_diff_ext = {phv_diff, {8{1'b0}}};
assign comp = (phv_diff_ext>=fcw_ext)? 1'b1: 1'b0;

always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst) begin 
		sarcode_dff <= (1'b1 << (9-1));
		sar_state_dff <= 0;
		sweep_init_dff <= 0;
		rangenum_dff <= 0;
	end else if (SPI_AFC_EN) begin
		if (sar_assert) begin
			sarcode_dff <= sarcode;
			if (range_assert) begin
				sar_state_dff <= sar_state;
				sweep_init_dff <= sweep_init;
				rangenum_dff <= rangenum;
			end
		end else sarcode_dff <= sarcode_dff;
	end
end

always @* begin
	if (sar_assert) begin
		if (range_assert) begin // determine deep search mode sweep range
			if (comp) sarcode = sarcode_dff - 1'b1;
			else sarcode = sarcode_dff;
			if (sarcode<5) begin
				sar_state = 2'b00;
				sweep_init = 0;
				rangenum = 6+sarcode;
			end else if (sarcode>({(9){1'b1}}-5)) begin
				sar_state = 2'b10;
				sweep_init = sarcode - 5;
				rangenum = {(9){1'b1}}-sarcode+6;
			end else begin
				sar_state = 2'b01;
				sweep_init = sarcode - 5;
				rangenum = 11;
			end
		end else begin
			if (comp) sarcode = sarcode_dff - (1'b1<<(9-poscnt-1));
			else sarcode = sarcode_dff + (1'b1<<(9-poscnt-1));
			sar_state = 0;
			sweep_init = 0;
			rangenum = 0;
		end
	end else begin
		sarcode = 0;
		sar_state = 0;
		sweep_init = 0;
		rangenum = 0;
	end
end


// deep search logic
always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst) begin 
		deep_assert <= 1'b0;
		final_assert <= 1'b0;
	end else if (SPI_AFC_EN) begin
		if ((refcnt==(sampcnt_max-1'b1))&&((sweepcnt>=1)&&(sweepcnt<=rangenum_dff))) begin 
			deep_assert <= 1'b1;
			if (sweepcnt==rangenum_dff) final_assert <= 1'b1;
			else final_assert <= 1'b0;
		end else begin 
			deep_assert <= 1'b0;
			final_assert <= 1'b0;
		end 
	end
end

assign phv_diff_signed = {1'b0, phv_diff_ext};
assign fcw_signed = {1'b0, fcw_ext};
assign fe_cur = phv_diff_signed - fcw_signed;
assign absfe_cur = fe_cur[9+8+8]? (~fe_cur+1'b1): fe_cur;

// count for sweep
always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst) sweepcnt <= 0;
	else if (SPI_AFC_EN) begin
		if (range_assert) sweepcnt <= 1;
		else if ((refcnt==sampcnt_max)&&(search_mode==2'b10)&&(sweepcnt<=rangenum_dff)) sweepcnt <= sweepcnt + 1'b1;
		else sweepcnt <= sweepcnt;
	end
end

always @ (posedge REF or negedge sync_nrst) begin
	if (!sync_nrst) begin
		deepcode_dff <= 0;
		absfe_done_dff <= {(9+8+9){1'b1}};
		propose_dff <= 4'd0;
	end else if (SPI_AFC_EN) begin
		if (range_assert) begin
			deepcode_dff <= 0;
			absfe_done_dff <= {(9+8+9){1'b1}};
			propose_dff <= 4'd0;
		end else begin
			if (deep_assert) begin
				deepcode_dff <= deepcode;
				absfe_done_dff <= absfe_done;
				propose_dff <= propose;
			end else begin
				deepcode_dff <= deepcode_dff;
				absfe_done_dff <= absfe_done_dff;
				propose_dff <= propose_dff;
			end
		end
	end
end

always @* begin
	absfe_done = 0;
	propose = 0;
	deepcode = 0;
	if (deep_assert) begin 
		if (absfe_cur <= absfe_done_dff) begin
			propose = propose_dff + 1'b1;
			absfe_done = absfe_cur;
		end else begin 
			propose = propose_dff;
			absfe_done = absfe_done_dff;
		end
		
		if (final_assert) deepcode = sweep_init_dff + propose - 1'b1;
		else deepcode = sweep_init_dff + sweepcnt;
	end
end

endmodule