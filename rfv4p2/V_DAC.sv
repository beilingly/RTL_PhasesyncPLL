`timescale 1s / 1fs

module V_DAC (
RESET,
EN,
IN,
DACCLK,
DELAYSW,
VSMP,
VREFSIG,
PHE_SIG
);

input RESET;
input EN;
input IN;
input DACCLK;
input [3:0] DELAYSW;
input var real VSMP;
output real VREFSIG;
output PHE_SIG;

parameter real deltav = 2e-3;
parameter real deltav_up = 2e-3;
parameter real deltav_dn = 2e-3;

wire temp;

// generate PHE_SIG
assign temp = (VSMP>VREFSIG)? 1'b1: 1'b0;
assign #2e-9 PHE_SIG = temp;
// assign PHE_SIG = (VSMP>0.5)? 1'b1: 1'b0;

always @ (posedge DACCLK or posedge RESET) begin
	if (RESET) VREFSIG <= 0.9;
	else begin
		case (IN)
			// take mismatch into consideration
			2'b1: VREFSIG <= EN? (VREFSIG + deltav_up): VREFSIG;
			2'b0: VREFSIG <= EN? (VREFSIG - deltav_dn): VREFSIG;
			default: VREFSIG <= VREFSIG;
		endcase
	end
end

endmodule