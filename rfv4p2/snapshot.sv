module snapshot (
CKV,
FREF,
EDGESEL,
CKVS,
CKR,
CKR_CNT
);

input CKV;
input FREF;
input EDGESEL;
output reg CKVS;
output CKR;
output CKR_CNT;

reg ckr_reg1;
reg ckr_reg2;
reg ckr_reg3;
reg ckr_reg4;
reg CKVENB;
wire CK;

assign CKR = ckr_reg3;
assign CKR_CNT = EDGESEL? ckr_reg3: ckr_reg4;

always @ (negedge FREF or posedge CK) begin
	if (!FREF) begin
		ckr_reg1 <= 0;
		ckr_reg2 <= 0;
		ckr_reg3 <= 0;
	end else begin
		ckr_reg1 <= 1;
		ckr_reg2 <= ckr_reg1;
		ckr_reg3 <= ckr_reg2;
	end
end

always @ (negedge FREF or negedge CK) begin
	if (!FREF) ckr_reg4 <= 0;
	else ckr_reg4 <= ckr_reg3;
end


assign CK = CKVENB|CKV|ckr_reg4;

always @ (negedge FREF or posedge FREF) begin
	if (!FREF) CKVENB <= 1;
	else CKVENB <= 0;
end

always @ (negedge FREF or posedge CK) begin
	if (!FREF) CKVS <= 0;
	else CKVS <= CK;
end

endmodule