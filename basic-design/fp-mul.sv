`include "util.sv"

module fp_mul #(
    parameter FP_WIDTH  = 32,
    parameter EXP_WIDTH = 8,
    parameter MAN_WIDTH = 23,  // up [(23+1+1)/4] = 7 Booth Encoder
    parameter n_boothMul = 7,
    parameter n_Level = 4
)(
    input logic [FP_WIDTH-1:0] IN1,
    input logic [FP_WIDTH-1:0] IN2,
    output logic [FP_WIDTH-1:0] OUT
);


//localparam n_boothMul = 7;//$ceil((MAN_WIDTH + 2)/4);
//localparam  n_Level   = 4;//$ceil($clog2((MAN_WIDTH + 2)/4) / $clog2(3/2));

wire [MAN_WIDTH*2+5:0] Level_Res [n_Level:0][n_boothMul-1:0];

wire [MAN_WIDTH:0]      A_MAN_full;
assign A_MAN_full = {1'b1, IN1[MAN_WIDTH-1:0]};

wire [n_boothMul*4:0] B_MAN_ext;
assign B_MAN_ext = {4'b0, 1'b1, IN2[MAN_WIDTH-1:0], 1'b0};

wire [MAN_WIDTH+4:0] booth_Res [n_boothMul-1:0];

// generate partial products
genvar i;
generate
    for(i=0; i<n_boothMul; i=i+1) begin
        Radix16_Booth boothMul(
            .Multiplicand(A_MAN_full),
            .Multiplier(B_MAN_ext[4*i+:5]),
            .PartialProduct(booth_Res[i])
        );

        assign Level_Res[0][i] = (i==0) ? {!booth_Res[i][MAN_WIDTH+4], {4{booth_Res[i][MAN_WIDTH+4]}}, booth_Res[i]}
                               : ((i == n_boothMul - 1) ? {booth_Res[i], {i*4{1'b0}}}
                               : {{3{1'b1}}, !booth_Res[i][MAN_WIDTH+4], booth_Res[i], {i*4{1'b0}}});

        // if(i == 0)
        //     assign Level_Res[0][i] = {!booth_Res[i][MAN_WIDTH+4], {4{booth_Res[i][MAN_WIDTH+4]}}, booth_Res[i]};
        // else if(i == n_boothMul - 1)
        //     assign Level_Res[0][i] = {booth_Res[i][MAN_WIDTH:0], {i*4{1'b0}}};
        // else
        //     assign Level_Res[0][i] = {{3{1'b1}}, !booth_Res[i][MAN_WIDTH+4], booth_Res[i], {i*4{1'b0}}};
    end
endgenerate

// CSA Tree
function int level_num(input int init, input int L_rank);
    integer res;
    for(int i=0; i<=L_rank; i=i+1) begin
        if(i==0) 
            res = init;
        else
            res = res - $floor(res / 3);
    end
    return res;    
endfunction

logic [MAN_WIDTH*2+5:0] MAN_MUL_RES;
genvar j;
generate
    for(j=0;j<n_Level;j=j+1) begin
        localparam num1 = level_num(n_boothMul, j);
        localparam num2 = level_num(n_boothMul, j+1);
        // $display("Layer: %d, num1: %d, num2: %d", j, num1, num2);
        CSA_Layer #(num1, num2, 2*MAN_WIDTH+6) csa_layer(
            .IN(Level_Res[j][num1-1:0]),
            .OUT(Level_Res[j+1][num2-1:0])
        );
    end
endgenerate

assign MAN_MUL_RES = Level_Res[n_Level][0] + Level_Res[n_Level][1];

logic [EXP_WIDTH-1:0] EXP_MUL_RES;
assign EXP_MUL_RES = IN1[MAN_WIDTH+EXP_WIDTH-1:MAN_WIDTH] 
                        + IN2[MAN_WIDTH+EXP_WIDTH-1:MAN_WIDTH]
                        + {1'b1, {(EXP_WIDTH-2){1'b0}}, 1'b1}
                        + MAN_MUL_RES[MAN_WIDTH*2+1];

assign OUT = {IN1[FP_WIDTH-1] ^ IN2[FP_WIDTH-1], EXP_MUL_RES, 
                (MAN_MUL_RES[MAN_WIDTH*2+1] ? MAN_MUL_RES[MAN_WIDTH*2:MAN_WIDTH+1] : MAN_MUL_RES[MAN_WIDTH*2-1:MAN_WIDTH])};

endmodule