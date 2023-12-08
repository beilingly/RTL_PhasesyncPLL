module VPAC (
NRST,
CKR,
CKV,
RVK
);

input NRST;
input CKR;
input CKV;
output [6:0] RVK;

wire [4:0] sum;
reg [6:2] RVi;
reg [3:1] RVid;
reg [6:2] RVi_reg;
reg [3:1] RVid_reg;

// CKV divider by 4
reg ckvdivr1;
reg ckvdivr2;
wire CKVD4;

assign CKVD4 = ckvdivr2;
always @ (negedge NRST or posedge CKV) begin
	if (!NRST) begin
		ckvdivr1 <= 0;
		ckvdivr2 <= 0;
	end else begin
		ckvdivr1 <= ~ckvdivr2;
		ckvdivr2 <= ckvdivr1;
	end
end

// MSB adder
assign sum = RVi + 1;

always @ (negedge NRST or posedge CKVD4) begin
	if (!NRST) RVi <= 0;
	else RVi <= sum;
end

// LSB cnt
always @ (negedge NRST or posedge CKV) begin
	if (!NRST) RVid <= 0;
	else RVid <= {RVid[2:1], RVi[2]};
end

// synchronous sample
always @ (negedge NRST or posedge CKR) begin
	if (!NRST) begin
		RVi_reg <= 0;
		RVid_reg <= 0;
	end else begin
		RVi_reg <= RVi;
		RVid_reg <= RVid;
	end
end

// encoder
assign RVK[6:2] = RVi_reg;
assign RVK[0] = (~(RVid_reg[3]^RVi_reg[2])) | (RVid_reg[2]^RVid_reg[1]);
assign RVK[1] = ~(RVid_reg[2]^RVi_reg[2]);

endmodule