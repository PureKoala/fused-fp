`include "fp-mul-8-16-32.sv"
`include "define.sv"

// Basic Data Alignment Requirement
// This design can only calculate 1 TF32 at one time & TF32 should be aligned to Left (Input[31] = Sign of TF32) 
// Other formats can fully fill Input Data Width

module FpMul_32to8 (
    input wire [31:0] IN1,
    input wire [31:0] IN2,
    input wire [`CONFIG_WIDTH-1:0] CONFIG_FP,

    output [31:0] OUT
);

// Calculate the man Mul Res
wire [23:0] MAN1_FP32 = {1'b1, IN1[22:0]};
wire [23:0] MAN2_FP32 = {1'b1, IN2[22:0]};

wire [23:0] MAN1_TF32 = {'d0, 1'b1, IN1[22-:10]};
wire [23:0] MAN2_TF32 = {'d0, 1'b1, IN2[22-:10]};

wire [23:0] MAN1_FP16 = {1'b0, 1'b1, IN1[25:16], 1'b0, 1'b1, IN1[9:0]};
wire [23:0] MAN2_FP16 = {1'b0, 1'b1, IN2[25:16], 1'b0, 1'b1, IN2[9:0]};

wire [23:0] MAN1_BF16 = {4'b0, 1'b1, IN1[22:16], 4'b0, 1'b1, IN1[6:0]};
wire [23:0] MAN2_BF16 = {4'b0, 1'b1, IN2[22:16], 4'b0, 1'b1, IN2[6:0]};

wire [23:0] MAN1_FP8_E4M3 = {   2'b0, 1'b1, IN1[26:24], 2'b0, 1'b1, IN1[18:16], 
                                2'b0, 1'b1, IN1[10:8],  2'b0, 1'b1, IN1[2:0]  };
wire [23:0] MAN2_FP8_E4M3 = {   2'b0, 1'b1, IN2[26:24], 2'b0, 1'b1, IN2[18:16],
                                2'b0, 1'b1, IN2[10:8],  2'b0, 1'b1, IN2[2:0]  };

wire [23:0] MAN1_FP8_E5M2 = {   3'b0, 1'b1, IN1[15:14], 3'b0, 1'b1, IN1[17:16],
                                3'b0, 1'b1, IN1[9:8],   3'b0, 1'b1, IN1[1:0]  };
wire [23:0] MAN2_FP8_E5M2 = {   3'b0, 1'b1, IN2[15:14], 3'b0, 1'b1, IN2[17:16],
                                3'b0, 1'b1, IN2[9:8],   3'b0, 1'b1, IN2[1:0]  };

logic [23:0] MAN1_Eff, MAN2_Eff;
always_comb begin
    case(CONFIG_FP)
        `CONFIG_FP32: begin
            MAN1_Eff = MAN1_FP32;
            MAN2_Eff = MAN2_FP32;
        end
        `CONFIG_FP16: begin
            MAN1_Eff = MAN1_FP16;
            MAN2_Eff = MAN2_FP16;
        end
        `CONFIG_TF32: begin
            MAN1_Eff = MAN1_TF32;
            MAN2_Eff = MAN2_TF32;
        end
        `CONFIG_BF16: begin
            MAN1_Eff = MAN1_BF16;
            MAN2_Eff = MAN2_BF16;
        end
        `CONFIG_FP8_E4M3: begin
            MAN1_Eff = MAN1_FP8_E4M3;
            MAN2_Eff = MAN2_FP8_E4M3;
        end
        `CONFIG_FP8_E5M2: begin
            MAN1_Eff = MAN1_FP8_E5M2;
            MAN2_Eff = MAN2_FP8_E5M2;
        end
        default: begin
            MAN1_Eff = 'd0;
            MAN2_Eff = 'd0;
        end
    endcase
end

wire [23:0] MulRES_MAN;
wire [ 3:0] MulRES_NormBits;
fp_mul_8_16_32 fp_mul_inst(
    .IN1(MAN1_Eff),
    .IN2(MAN2_Eff),
    .CONFIG_FP(CONFIG_FP),
    .OUT_NormBits(MulRES_NormBits),
    .OUT(MulRES_MAN)
);

// Calculate the exp Mul Res
wire [7:0]  RES_EXP_FP32_TF32 = IN1[30-:8] + IN2[30-:8] - 8'd127 + MulRES_NormBits[0];
wire [31:0] Res_FP32 = {IN1[31] ^ IN2[31], RES_EXP_FP32_TF32, MulRES_MAN[22-:23]};
wire [31:0] Res_TF32 = {IN1[31] ^ IN2[31], RES_EXP_FP32_TF32, MulRES_MAN[10-:10], 13'b0};

wire [4:0]  RES_EXP_FP16_0 = IN1[14-:5] + IN2[14-:5] - 5'd15 + MulRES_NormBits[0];
wire [4:0]  RES_EXP_FP16_1 = IN1[30-:5] + IN2[30-:5] - 5'd15 + MulRES_NormBits[1];
wire [31:0] Res_FP16 = {IN1[31] ^ IN2[31], RES_EXP_FP16_1, MulRES_MAN[22-:10],
                        IN1[15] ^ IN2[15], RES_EXP_FP16_0, MulRES_MAN[10-:10]};

wire [7:0]  RES_EXP_BF16_0 = IN1[14-:8] + IN2[14-:8] - 8'd127 + MulRES_NormBits[0];
wire [7:0]  RES_EXP_BF16_1 = IN1[30-:8] + IN2[30-:8] - 8'd127 + MulRES_NormBits[1];
wire [31:0] Res_BF16 = {IN1[31] ^ IN2[31], RES_EXP_BF16_1, MulRES_MAN[22-:7],
                        IN1[15] ^ IN2[15], RES_EXP_BF16_0, MulRES_MAN[10-:7]};

wire [3:0]  RES_EXP_FP8_E4M3_0 = IN1[6-:4] + IN2[6-:4] - 4'd7 + MulRES_NormBits[0];
wire [3:0]  RES_EXP_FP8_E4M3_1 = IN1[14-:4] + IN2[14-:4] - 4'd7 + MulRES_NormBits[1];
wire [3:0]  RES_EXP_FP8_E4M3_2 = IN1[22-:4] + IN2[22-:4] - 4'd7 + MulRES_NormBits[2];
wire [3:0]  RES_EXP_FP8_E4M3_3 = IN1[30-:4] + IN2[30-:4] - 4'd7 + MulRES_NormBits[3];
wire [31:0] Res_FP8_E4M3 = {IN1[31] ^ IN2[31], RES_EXP_FP8_E4M3_3, MulRES_MAN[22-:3],
                            IN1[23] ^ IN2[23], RES_EXP_FP8_E4M3_2, MulRES_MAN[16-:3],
                            IN1[15] ^ IN2[15], RES_EXP_FP8_E4M3_1, MulRES_MAN[10-:3],
                            IN1[ 7] ^ IN2[ 7], RES_EXP_FP8_E4M3_0, MulRES_MAN[ 4-:3]};

wire [4:0]  RES_EXP_FP8_E5M2_0 = IN1[6-:5] + IN2[6-:5] - 5'd15 + MulRES_NormBits[0];
wire [4:0]  RES_EXP_FP8_E5M2_1 = IN1[14-:5] + IN2[14-:5] - 5'd15 + MulRES_NormBits[1];
wire [4:0]  RES_EXP_FP8_E5M2_2 = IN1[22-:5] + IN2[22-:5] - 5'd15 + MulRES_NormBits[2];
wire [4:0]  RES_EXP_FP8_E5M2_3 = IN1[30-:5] + IN2[30-:5] - 5'd15 + MulRES_NormBits[3];
wire [31:0] Res_FP8_E5M2 = {IN1[31] ^ IN2[31], RES_EXP_FP8_E5M2_3, MulRES_MAN[22-:2],
                            IN1[23] ^ IN2[23], RES_EXP_FP8_E5M2_2, MulRES_MAN[16-:2],
                            IN1[15] ^ IN2[15], RES_EXP_FP8_E5M2_1, MulRES_MAN[10-:2],
                            IN1[ 7] ^ IN2[ 7], RES_EXP_FP8_E5M2_0, MulRES_MAN[ 4-:2]};

logic [31:0] Configed_OUT;
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