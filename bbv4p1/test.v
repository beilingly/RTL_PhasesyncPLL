module test;


reg signed [2:0] a_signed; // -4~3
reg [2:0] c;

initial begin
    a_signed = -3'd2;
    if (a_signed > 3'sh6 && 1<0) begin
        $display("a_signed=%b", a_signed);
    end
    c = a_signed>>>$unsigned(1'b1);
    $display("%b", c);
end

endmodule