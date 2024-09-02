module int_add #(
    parameter WIDTH = 8
)
(
    input  wire [WIDTH-1 : 0] A,
    input  wire [WIDTH-1 : 0] B,
    output wire [WIDTH-1 : 0] C
);

assign C = A[WIDTH-1] == B[WIDTH-1] ? A+B : (A + ~B + 'b1);

endmodule