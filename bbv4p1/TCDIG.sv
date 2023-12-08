// temperature compensation sv model

module TCDIG (
NARST,
TCEN,
REFCLK,
VCOCLK,
TCKIS,
TCKPS,
TCOTW_INT,
TCOTW_FRAC,
TCOTWDSM,
VCTRL
);

input real VCTRL;
input NARST;
input REFCLK;
input VCOCLK;
input [3:0] TCKIS; // shift right 16 bits
input [3:0] TCKPS;
input TCEN;
output reg [3:0] TCOTW_INT; // temperature compensation otw
output reg [15:0] TCOTW_FRAC; // fractional part of temperature compensation otw for dsm
output TCOTWDSM; // temperature compensation lsb otw quantization by DSM

reg signed [4+16-1:0] dlf_out;
reg signed [4+16-1:0] dlf_out_iir;
wire REFDIV1024;
wire nrst;
// analog realize --------------------------------------------------------------

// vctrl comperator
reg comp_high;
reg comp_low;

always @ (posedge REFDIV1024 or negedge nrst) begin
	if (!nrst) begin
		comp_high <= 0;
		comp_low <= 0;
	end else begin
		comp_high <= (VCTRL > 0.9 + 0.01)? 1: 0;
		comp_low <= (VCTRL < 0.9 - 0.01)? 1: 0;
	end
end

// dsm pre-divider
reg [1:0] cnt4;
wire VCODIV4;

always @(posedge VCOCLK or negedge nrst) begin
	if (!nrst) begin
		cnt4 <= 0;
	end else begin
		cnt4 <= cnt4 + 1;
	end
end

assign VCODIV4 = cnt4[1];

// MASH-1 DSM
reg dsm_out;
reg [15:0] dsm_sum;

always @(posedge VCODIV4 or negedge nrst) begin
	if (!nrst) begin
		dsm_out <= 0;
		dsm_sum <= 0;
	end else begin
		{dsm_out, dsm_sum} <= dsm_sum + TCOTW_FRAC;
	end
end

assign TCOTWDSM = dsm_out;

// digital realize --------------------------------------------------------------

// async generate and sync release nrst
SYNCRSTGEN U0_TCDIG_SYNCRSTGEN ( .CLK (REFCLK), .NARST (NARST), .NRST (nrst), .NRST1 (), .NRST2 () );

// divide 100MHz fref to 100kHz
reg [5:0] cnt1024;

always @(posedge REFCLK or negedge nrst) begin
	if (!nrst) begin
		cnt1024 <= 0;
	end else if (TCEN) begin
		cnt1024 <= cnt1024 + 1;
	end
end

assign REFDIV1024 = cnt1024[5];

// map comperate result to -1/0/1
reg signed [1:0] comp_value;

always @(posedge REFDIV1024 or negedge nrst) begin
	if (!nrst) begin
		comp_value <= 0;
	end else if (TCEN) begin
		case ({comp_high, comp_low})
			2'b00: comp_value <= 2'b00;
			2'b01: comp_value <= 2'b11; // frequency higher than threshold
			2'b10: comp_value <= 2'b01; // frequency lower then threshold
			2'b11: comp_value <= 2'b00;
		endcase
	end else begin
		comp_value <= 0;
	end
end

// dlf
wire [4+16-1:0] dlf_prop;
wire [4+16-1:0] dlf_inte;
reg signed [4+16-1:0] dlf_inte_sum_reg;

assign dlf_prop = (comp_value <<< 16) >>> TCKPS;
assign dlf_inte = (comp_value <<< 16) >>> TCKIS;

always @(posedge REFDIV1024 or negedge nrst) begin
	if (!nrst) begin
		dlf_inte_sum_reg <= 0;
		dlf_out <= 0;
		dlf_out_iir <= 0;
		TCOTW_INT <= 8;
		TCOTW_FRAC <= 0;
	end else if (TCEN) begin
		if (dlf_inte_sum_reg>20'sh90000 && dlf_inte_sum_reg<20'sh60000) begin// -7<dlf_inte_sum_reg<6
			dlf_inte_sum_reg <= dlf_inte_sum_reg + dlf_inte;
		end else begin
			if (dlf_inte_sum_reg<=20'sh90000) dlf_inte_sum_reg <= 20'sh90000; // -7
			else dlf_inte_sum_reg <= 20'sh60000; // 6
		end
		dlf_out <= dlf_inte_sum_reg + dlf_prop;
		dlf_out_iir <= (dlf_out >>> 8) + dlf_out_iir - (dlf_out_iir >>> 8);
		TCOTW_INT <= {~dlf_out_iir[4+16-1], dlf_out_iir[4+16-2:16]};
		TCOTW_FRAC <= dlf_out_iir[15:0];
	end
end

endmodule