// word width define
`define DTC_L 12

//**************************************************************
// DCW SAMPLER
// sample dcw at REFDTC negedge
//**************************************************************
module DCWSMP (
SPI_NARST,
REFDTC,
DCWIN,
LOOP_TEMP_CODE,
LOOP_BINARY_OUT,
DCWOUT // test signal
);

input SPI_NARST;
input REFDTC;
input [`DTC_L-1:0] DCWIN;
output reg [6:0] LOOP_TEMP_CODE;
output reg [8:0] LOOP_BINARY_OUT;
output reg [`DTC_L-1:0] DCWOUT; // test signal

// SYNC NRST
wire sync_nrst;
SYNCRSTGEN_N U_SYNC_NRST ( .CLK(REFDTC), .NARST(SPI_NARST), .NRST(sync_nrst), .NRST1(), .NRST2() );

always @ (negedge REFDTC or negedge sync_nrst) begin
	if (!sync_nrst) begin
		LOOP_TEMP_CODE <= 7'd0;
		LOOP_BINARY_OUT <= 9'd0;
		DCWOUT <= 0;
	end else begin
		LOOP_TEMP_CODE <= (DCWIN[11:9]==3'd0 ) ? 7'b0000000 :(
					  (DCWIN[11:9]==3'd1 ) ? 7'b0000001 :(
					  (DCWIN[11:9]==3'd2 ) ? 7'b0000011 :(
					  (DCWIN[11:9]==3'd3 ) ? 7'b0000111 :(
					  (DCWIN[11:9]==3'd4 ) ? 7'b0001111 :(
					  (DCWIN[11:9]==3'd5 ) ? 7'b0011111 :(
					  (DCWIN[11:9]==3'd6 ) ? 7'b0111111 :(
					  (DCWIN[11:9]==3'd7 ) ? 7'b1111111 :(
						7'b0000000 
						))))))));
		LOOP_BINARY_OUT <= DCWIN[8:0];
		DCWOUT <= DCWIN;
	end
end

endmodule
