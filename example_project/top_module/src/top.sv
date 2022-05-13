module top (
    input logic clock,
    input logic resetp,
    input logic [7:0] din,
    output logic [7:0] dout
);


logic z;

some_module some_module_inst (
    .a(din[0]),
    .b(din[1]),
    .z(z)
);

always @ (posedge clock) begin
    dout <= din;
    dout[0] <= z;
end

endmodule
