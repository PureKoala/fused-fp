// `include "../basic-design/util.sv"
 `include "define.sv"

//all input data should be right aligned
//all output data would be left aligned(every ouput MSB is mul result MSB)

module fp_mul_8_16_32 #(
    parameter WIDTH = 24
)
(
    input wire [WIDTH-1:0] IN1,
    input wire [WIDTH-1:0] IN2,
    input wire [`CONFIG_WIDTH-1:0] CONFIG_FP,

    output wire [3:0] OUT_NormBits,
    output wire [WIDTH-1:0] OUT
);
    
wire [11:0] Res_6x6 [3:0];
wire [13:0] Res_7x7 [1:0];
wire [23:0] Res_12x12 [1:0];
wire [25:0] Res_13x13;
wire [47:0] Res_24x24;

// used function
function int level_num(input int init, input int L_rank);
    begin
        integer res;
        for(int i=0; i<=L_rank; i=i+1) begin
            if(i==0) 
                res = init;
            else
                res = res - $floor(res / 3);
        end
        return res;    
    end
endfunction

// generate 4 6x6 booth multiplier
genvar mul6x6, mul6x6_booth;
generate
    for(mul6x6=0; mul6x6<4; mul6x6=mul6x6+1) begin: mul6x6_gen
        wire [8:0] r16_booth_6x6 [8:0];
        Radix16_Booth_Encoder #(6) booth_6x6_i (
            .Multiplicand(IN1[mul6x6*6+:6]),
            .Multiplicand_Encoded(r16_booth_6x6)
        );

        wire [8:0] Multiplier = {2'b0, IN2[mul6x6*6+:6], 1'b0};
        
        wire [9:0] boothRes_6x6 [1:0];
        for(mul6x6_booth=0; mul6x6_booth<2; mul6x6_booth=mul6x6_booth+1) begin: boothRes_6x6_gen
            Radix16_Booth_Sel #(6) booth_sel_6x6_i (
                .Multiplicand_encoded(r16_booth_6x6),
                .Multiplier(Multiplier[mul6x6_booth*4+:5]),
                .PartialProduct(boothRes_6x6[mul6x6_booth])
            );
        end

        assign Res_6x6[mul6x6] = {{2{boothRes_6x6[0][9]}}, boothRes_6x6[0]} 
                                + {boothRes_6x6[1], 4'b0};
    end
endgenerate

// generate 2 7x7 booth multiplier
genvar mul7x7, mul7x7_booth;
generate
    for(mul7x7 = 0; mul7x7 < 2; mul7x7 = mul7x7+1) begin: mul7x7_gen
        wire [6:0] mul7x7_num1 = IN1[mul7x7*2*6+:6] + IN1[(mul7x7*2*6+6)+:6];
        wire [6:0] mul7x7_num2 = IN2[mul7x7*2*6+:6] + IN2[(mul7x7*2*6+6)+:6];

        wire [9:0] r16_booth_7x7 [8:0];
        Radix16_Booth_Encoder #(7) booth_7x7_i (
            .Multiplicand(mul7x7_num1),
            .Multiplicand_Encoded(r16_booth_7x7)
        );

        wire [8:0] Multiplier = {1'b0, mul7x7_num2, 1'b0};
        
        wire [10:0] boothRes_7x7 [1:0];
        for(mul7x7_booth=0; mul7x7_booth<2; mul7x7_booth=mul7x7_booth+1) begin: boothRes_7x7_gen
            Radix16_Booth_Sel #(7) booth_sel_7x7_i (
                .Multiplicand_encoded(r16_booth_7x7),
                .Multiplier(Multiplier[mul7x7_booth*4+:5]),
                .PartialProduct(boothRes_7x7[mul7x7_booth])
            );
        end

        assign Res_7x7[mul7x7] = {{3{boothRes_7x7[0][10]}}, boothRes_7x7[0]} 
                                + {boothRes_7x7[1], 4'b0};
    end
endgenerate

// generate 2 12x12 mul result
genvar mul12x12_res;
generate 
    for(mul12x12_res=0; mul12x12_res<2; mul12x12_res=mul12x12_res+1) begin: mul12x12_res_gen
        wire [11:0] z0_12x12 = Res_6x6[mul12x12_res*2];
        wire [11:0] z2_12x12 = Res_6x6[mul12x12_res*2+1];
        

        wire [13:0] z0_plus_z2_12x12 = z0_12x12 + z2_12x12;
        wire [13:0] z1_12x12 = Res_7x7[mul12x12_res] + ~z0_plus_z2_12x12 + 1'b1;

        assign Res_12x12[mul12x12_res] = {z2_12x12, z0_12x12} 
                                        + {z1_12x12, 6'b0};
    end
endgenerate

// 13x13 mul result
wire [12:0] mul13x13_num1 = IN1[23:12] + IN1[11:0];
wire [12:0] mul13x13_num2 = IN2[23:12] + IN2[11:0];

wire [15:0] r16_booth_13x13 [8:0];
Radix16_Booth_Encoder #(13) booth_13x13_i (
    .Multiplicand(mul13x13_num1),
    .Multiplicand_Encoded(r16_booth_13x13)
);

wire [16:0] Multiplier = {3'b0, mul13x13_num2, 1'b0};

wire [16:0] boothRes_13x13 [3:0];
wire [25:0] levelRes_13x13 [2:0][3:0];

genvar mul13x13_booth, mul13x13_csa;
generate
    for(mul13x13_booth=0; mul13x13_booth<4; mul13x13_booth=mul13x13_booth+1) begin: boothRes_13x13_gen
        Radix16_Booth_Sel #(13) booth_sel_13x13_i (
            .Multiplicand_encoded(r16_booth_13x13),
            .Multiplier(Multiplier[mul13x13_booth*4+:5]),
            .PartialProduct(boothRes_13x13[mul13x13_booth])
        );

        assign levelRes_13x13[0][mul13x13_booth] = 
                        (mul13x13_booth==0) ? {!boothRes_13x13[mul13x13_booth][16], {4{boothRes_13x13[mul13x13_booth][16]}}, boothRes_13x13[mul13x13_booth]}
                               : ((mul13x13_booth == 3) ? {boothRes_13x13[mul13x13_booth], {mul13x13_booth*4{1'b0}}}
                               : {{3{1'b1}}, !boothRes_13x13[mul13x13_booth][16], boothRes_13x13[mul13x13_booth], {mul13x13_booth*4{1'b0}}});

    end

    for(mul13x13_csa=0; mul13x13_csa<2; mul13x13_csa=mul13x13_csa+1) begin: mul13x13_csa_gen
        localparam num1 = level_num(4, mul13x13_csa);
        localparam num2 = level_num(4, mul13x13_csa+1);
        CSA_Layer #(num1, num2, 26) csa_layer(
            .IN(levelRes_13x13[mul13x13_csa][num1-1:0]),
            .OUT(levelRes_13x13[mul13x13_csa+1][num2-1:0])
        );
    end
endgenerate

assign Res_13x13 = levelRes_13x13[2][0] + levelRes_13x13[2][1];

// cal final 24x24 mul result
wire [23:0] z0_24x24 = Res_12x12[0];
wire [23:0] z2_24x24 = Res_12x12[1];

wire [25:0] z0_plus_z2_24x24 = z0_24x24 + z2_24x24;
wire [25:0] z1_24x24 = Res_13x13 + ~z0_plus_z2_24x24 + 1'b1;

assign Res_24x24 = {z2_24x24, z0_24x24}
                    + {z1_24x24, 12'b0};


// decide output result accourding to the config bits

/// result without type upgrade
wire [3:0] NormBit_FP32     = {3'b0, Res_24x24[47]};
wire [3:0] NormBit_FP16     = {2'b0, Res_12x12[1][21], Res_12x12[0][21]};
// wire [3:0] NormBit_TF32     = NormBit_FP16;
wire [3:0] NormBit_BF16     = {2'b0, Res_12x12[1][15], Res_12x12[0][15]};
wire [3:0] NormBit_FP8_E4M3 = {Res_6x6[3][7], Res_6x6[2][7], Res_6x6[1][7], Res_6x6[0][7]};
wire [3:0] NormBit_FP8_E5M2 = {Res_6x6[3][5], Res_6x6[2][5], Res_6x6[1][5], Res_6x6[0][5]};

wire [23:0] Res_FP32        = NormBit_FP32[0] ? Res_24x24[47-:24] : Res_24x24[46-:24];
wire [23:0] Res_FP16        = { (NormBit_FP16[1] ? Res_12x12[1][21-:11] : Res_12x12[1][20-:11]), 
                                1'b0, 
                                (NormBit_FP16[0] ? Res_12x12[0][21-:11] : Res_12x12[0][20-:11]),
                                1'b0};
wire [23:0] Res_TF32        = Res_FP16;
wire [23:0] Res_BF16        = { 12'b0,
                                (NormBit_BF16[0] ? Res_12x12[0][15-:8] : Res_12x12[0][14-:8]),
                                4'b0};
wire [23:0] Res_FP8_E4M3    = { (NormBit_FP8_E4M3[3] ? Res_6x6[3][7-:4] : Res_6x6[3][6-:4]),
                                8'b0,
                                (NormBit_FP8_E4M3[2] ? Res_6x6[2][7-:4] : Res_6x6[2][6-:4]),
                                8'b0,
                                (NormBit_FP8_E4M3[1] ? Res_6x6[1][7-:4] : Res_6x6[1][6-:4]),
                                8'b0,
                                (NormBit_FP8_E4M3[0] ? Res_6x6[0][7-:4] : Res_6x6[0][6-:4]),
                                8'b0};
wire [23:0] Res_FP8_E5M2    = { (NormBit_FP8_E5M2[3] ? Res_6x6[3][5-:3] : Res_6x6[3][4-:3]),
                                9'b0,
                                (NormBit_FP8_E5M2[2] ? Res_6x6[2][5-:3] : Res_6x6[2][4-:3]),
                                9'b0,
                                (NormBit_FP8_E5M2[1] ? Res_6x6[1][5-:3] : Res_6x6[1][4-:3]),
                                9'b0,
                                (NormBit_FP8_E5M2[0] ? Res_6x6[0][5-:3] : Res_6x6[0][4-:3]),
                                9'b0};

logic [23:0] Configed_OUT;
always_comb begin
    case(CONFIG_FP)
        `CONFIG_FP32:       Configed_OUT = Res_FP32;
        `CONFIG_FP16:       Configed_OUT = Res_FP16;
        `CONFIG_TF32:       Configed_OUT = Res_TF32;
        `CONFIG_BF16:       Configed_OUT = Res_BF16;
        `CONFIG_FP8_E4M3:   Configed_OUT = Res_FP8_E4M3;
        `CONFIG_FP8_E5M2:   Configed_OUT = Res_FP8_E5M2;
        default:            Configed_OUT = 'd0;
    endcase
end

assign OUT = Configed_OUT;
    
endmodule