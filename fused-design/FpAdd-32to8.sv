`include "define.sv"
`include "fused-util.sv"

module FpMul_32to8(
    input logic [`FP32_WIDTH-1:0] IN1,
    input logic [`FP32_WIDTH-1:0] IN2,
    input wire [`CONFIG_WIDTH-1:0] CONFIG_FP,
    input logic [`ROUND_TYPE_WIDTH-1:0] ROUND_TYPE,

    output [`FP32_WIDTH-1:0] OUT
);

// CONFIG_FP32
wire IN1_SIG_FP32 = IN1[`FP32_WIDTH-1];
wire [`FP32_EXP_WIDTH-1:0] IN1_EXP_FP32 = IN1[`FP32_EXP_WIDTH+`FP32_MAN_WIDTH-1:`FP32_MAN_WIDTH];
wire [`FP32_MAN_WIDTH:0]   IN1_MAN_FP32 = {1'b1, IN1[`FP32_MAN_WIDTH-1:0]};

wire IN2_SIG_FP32 = IN2[`FP32_WIDTH-1];
wire [`FP32_EXP_WIDTH-1:0] IN2_EXP_FP32 = IN2[`FP32_EXP_WIDTH+`FP32_MAN_WIDTH-1:`FP32_MAN_WIDTH];
wire [`FP32_MAN_WIDTH:0]   IN2_MAN_FP32 = {1'b1, IN2[`FP32_MAN_WIDTH-1:0]};

wire IN_EXP_CMP_FP32 = IN1_EXP_FP32 >= IN2_EXP_FP32;
wire [`FP32_EXP_WIDTH:0] IN_EXP_SUB_pre_FP32 = {1'b0, IN1_EXP_FP32} + ~{1'b0, IN2_EXP_FP32};
wire [`FP32_EXP_WIDTH:0] IN_EXP_SUB_12_FP32 = IN_EXP_SUB_pre_FP32 + 'b1;
wire [`FP32_EXP_WIDTH:0] IN_EXP_SUB_21_FP32 = ~IN_EXP_SUB_pre_FP32;
wire [`FP32_EXP_WIDTH-1:0] EXP_DIFF_FP32 = IN_EXP_CMP_FP32 ? IN_EXP_SUB_12_FP32[`FP32_EXP_WIDTH-1:0] : IN_EXP_SUB_21_FP32[`FP32_EXP_WIDTH-1:0];
wire IN1_Larger_FP32 = (IN1_EXP_FP32 > IN2_EXP_FP32) || (IN1_EXP_FP32 == IN2_EXP_FP32 && IN1_MAN_FP32 >= IN2_MAN_FP32) ;
wire Larger_SIG_FP32  = IN1_Larger_FP32 ? IN1_SIG_FP32 : IN2_SIG_FP32;
wire [`FP32_EXP_WIDTH-1:0] Larger_EXP_FP32 = IN1_Larger_FP32 ? IN1_EXP_FP32 : IN2_EXP_FP32;
wire [`FP32_MAN_WIDTH:0]  Larger_MAN_FP32  = IN1_Larger_FP32 ? IN1_MAN_FP32 : IN2_MAN_FP32;
wire [`FP32_MAN_WIDTH:0]  Smaller_MAN_FP32 = IN1_Larger_FP32 ? IN2_MAN_FP32 : IN1_MAN_FP32;

// CONFIG_FP16
wire [`FP16_EXP_WIDTH-1:0] EXP_DIFF_FP16 [1:0];
wire [1:0] Larger_SIG_FP16;
wire [1:0] Smaller_SIG_FP16;
wire [`FP16_EXP_WIDTH-1:0] Larger_EXP_FP16 [1:0];
wire [`FP16_MAN_WIDTH:0]  Larger_MAN_FP16 [1:0];
wire [`FP16_MAN_WIDTH:0]  Smaller_MAN_FP16 [1:0];

genvar fp16_i;
generate
    for (fp16_i = 0; fp16_i < 2; fp16_i = fp16_i + 1) begin
        wire IN1_SIG_FP16 = IN1[`FP16_WIDTH-1+fp16_i*`FP16_WIDTH];
        wire [`FP16_EXP_WIDTH-1:0] IN1_EXP_FP16 = IN1[`FP16_EXP_WIDTH+`FP16_MAN_WIDTH-1+fp16_i*`FP16_WIDTH:`FP16_MAN_WIDTH+fp16_i*`FP16_WIDTH];
        wire [`FP16_MAN_WIDTH:0]   IN1_MAN_FP16 = {1'b1, IN1[`FP16_MAN_WIDTH-1+fp16_i*`FP16_WIDTH:fp16_i*`FP16_WIDTH]};

        wire IN2_SIG_FP16 = IN2[`FP16_WIDTH-1+fp16_i*`FP16_WIDTH];
        wire [`FP16_EXP_WIDTH-1:0] IN2_EXP_FP16 = IN2[`FP16_EXP_WIDTH+`FP16_MAN_WIDTH-1+fp16_i*`FP16_WIDTH:`FP16_MAN_WIDTH+fp16_i*`FP16_WIDTH];
        wire [`FP16_MAN_WIDTH:0]   IN2_MAN_FP16 = {1'b1, IN2[`FP16_MAN_WIDTH-1+fp16_i*`FP16_WIDTH:fp16_i*`FP16_WIDTH]};

        wire IN_EXP_CMP_FP16 = IN1_EXP_FP16 >= IN2_EXP_FP16;
        wire [`FP16_EXP_WIDTH:0] IN_EXP_SUB_pre_FP16 = {1'b0, IN1_EXP_FP16} + ~{1'b0, IN2_EXP_FP16};
        wire [`FP16_EXP_WIDTH:0] IN_EXP_SUB_12_FP16 = IN_EXP_SUB_pre_FP16 + 'b1;
        wire [`FP16_EXP_WIDTH:0] IN_EXP_SUB_21_FP16 = ~IN_EXP_SUB_pre_FP16;
        // wire [`FP16_EXP_WIDTH-1:0] EXP_DIFF_FP16 = IN_EXP_CMP_FP16 ? IN_EXP_SUB_12_FP16[`FP16_EXP_WIDTH-1:0] : IN_EXP_SUB_21_FP16[`FP16_EXP_WIDTH-1:0];
        wire IN1_Larger_FP16 = (IN1_EXP_FP16 > IN2_EXP_FP16) || (IN1_EXP_FP16 == IN2_EXP_FP16 && IN1_MAN_FP16 >= IN2_MAN_FP16);

        assign EXP_DIFF_FP16[fp16_i] = IN_EXP_CMP_FP16 ? IN_EXP_SUB_12_FP16[`FP16_EXP_WIDTH-1:0] : IN_EXP_SUB_21_FP16[`FP16_EXP_WIDTH-1:0];
        assign Larger_SIG_FP16[fp16_i] = IN1_Larger_FP16 ? IN1_SIG_FP16 : IN2_SIG_FP16;.
        assign Smaller_SIG_FP16[fp16_i] = IN1_Larger_FP16 ? IN2_SIG_FP16 : IN1_SIG_FP16;
        assign Larger_EXP_FP16[fp16_i] = IN1_Larger_FP16 ? IN1_EXP_FP16 : IN2_EXP_FP16;
        assign Larger_MAN_FP16[fp16_i] = IN1_Larger_FP16 ? IN1_MAN_FP16 : IN2_MAN_FP16;
        assign Smaller_MAN_FP16[fp16_i] = IN1_Larger_FP16 ? IN2_MAN_FP16 : IN1_MAN_FP16;
    end
endgenerate

// CONFIG_BF16
wire [`BF16_EXP_WIDTH-1:0] EXP_DIFF_BF16 [1:0];
wire [1:0] Larger_SIG_BF16 ;
wire [1:0] Smaller_SIG_BF16 ;
wire [`BF16_EXP_WIDTH-1:0] Larger_EXP_BF16 [1:0];
wire [`BF16_MAN_WIDTH:0]  Larger_MAN_BF16 [1:0];
wire [`BF16_MAN_WIDTH:0]  Smaller_MAN_BF16 [1:0];

genvar bf16_i;
generate
    for (bf16_i = 0; bf16_i < 2; bf16_i = bf16_i + 1) begin
        wire IN1_SIG_BF16 = IN1[`BF16_WIDTH-1+bf16_i*`BF16_WIDTH];
        wire [`BF16_EXP_WIDTH-1:0] IN1_EXP_BF16 = IN1[`BF16_EXP_WIDTH+`BF16_MAN_WIDTH-1+bf16_i*`BF16_WIDTH:`BF16_MAN_WIDTH+bf16_i*`BF16_WIDTH];
        wire [`BF16_MAN_WIDTH:0]   IN1_MAN_BF16 = {1'b1, IN1[`BF16_MAN_WIDTH-1+bf16_i*`BF16_WIDTH:bf16_i*`BF16_WIDTH]};

        wire IN2_SIG_BF16 = IN2[`BF16_WIDTH-1+bf16_i*`BF16_WIDTH];
        wire [`BF16_EXP_WIDTH-1:0] IN2_EXP_BF16 = IN2[`BF16_EXP_WIDTH+`BF16_MAN_WIDTH-1+bf16_i*`BF16_WIDTH:`BF16_MAN_WIDTH+bf16_i*`BF16_WIDTH];
        wire [`BF16_MAN_WIDTH:0]   IN2_MAN_BF16 = {1'b1, IN2[`BF16_MAN_WIDTH-1+bf16_i*`BF16_WIDTH:bf16_i*`BF16_WIDTH]};

        wire IN_EXP_CMP_BF16 = IN1_EXP_BF16 >= IN2_EXP_BF16;
        wire [`BF16_EXP_WIDTH:0] IN_EXP_SUB_pre_BF16 = {1'b0, IN1_EXP_BF16} + ~{1'b0, IN2_EXP_BF16};
        wire [`BF16_EXP_WIDTH:0] IN_EXP_SUB_12_BF16 = IN_EXP_SUB_pre_BF16 + 'b1;
        wire [`BF16_EXP_WIDTH:0] IN_EXP_SUB_21_BF16 = ~IN_EXP_SUB_pre_BF16;
        wire IN1_Larger_BF16 = (IN1_EXP_BF16 > IN2_EXP_BF16) || (IN1_EXP_BF16 == IN2_EXP_BF16 && IN1_MAN_BF16 >= IN2_MAN_BF16);

        assign EXP_DIFF_BF16[bf16_i] = IN_EXP_CMP_BF16 ? IN_EXP_SUB_12_BF16[`BF16_EXP_WIDTH-1:0] : IN_EXP_SUB_21_BF16[`BF16_EXP_WIDTH-1:0];
        assign Larger_SIG_BF16[bf16_i] = IN1_Larger_BF16 ? IN1_SIG_BF16 : IN2_SIG_BF16;
        assign Smaller_SIG_BF16[bf16_i] = IN1_Larger_BF16 ? IN2_SIG_BF16 : IN1_SIG_BF16;
        assign Larger_EXP_BF16[bf16_i] = IN1_Larger_BF16 ? IN1_EXP_BF16 : IN2_EXP_BF16;
        assign Larger_MAN_BF16[bf16_i] = IN1_Larger_BF16 ? IN1_MAN_BF16 : IN2_MAN_BF16;
        assign Smaller_MAN_BF16[bf16_i] = IN1_Larger_BF16 ? IN2_MAN_BF16 : IN1_MAN_BF16;
    end
endgenerate

// CONFIG_FP8_E4M3
wire [`FP8_E4M3_EXP_WIDTH-1:0] EXP_DIFF_FP8_E4M3 [3:0];
wire [3:0] Larger_SIG_FP8_E4M3;
wire [3:0] Smaller_SIG_FP8_E4M3;
wire [`FP8_E4M3_EXP_WIDTH-1:0] Larger_EXP_FP8_E4M3 [3:0];
wire [`FP8_E4M3_MAN_WIDTH:0]  Larger_MAN_FP8_E4M3  [3:0];
wire [`FP8_E4M3_MAN_WIDTH:0]  Smaller_MAN_FP8_E4M3 [3:0];

genvar fp8_e4m3_i;
generate
    for (fp8_e4m3_i = 0; fp8_e4m3_i < 4; fp8_e4m3_i = fp8_e4m3_i + 1) begin
        wire IN1_SIG_FP8_E4M3 = IN1[`FP8_WIDTH-1+fp8_e4m3_i*`FP8_WIDTH];
        wire [`FP8_E4M3_EXP_WIDTH-1:0] IN1_EXP_FP8_E4M3 = IN1[`FP8_E4M3_EXP_WIDTH+`FP8_E4M3_MAN_WIDTH-1+fp8_e4m3_i*`FP8_WIDTH:`FP8_E4M3_MAN_WIDTH+fp8_e4m3_i*`FP8_WIDTH];
        wire [`FP8_E4M3_MAN_WIDTH:0]   IN1_MAN_FP8_E4M3 = {1'b1, IN1[`FP8_E4M3_MAN_WIDTH-1+fp8_e4m3_i*`FP8_WIDTH:fp8_e4m3_i*`FP8_WIDTH]};

        wire IN2_SIG_FP8_E4M3 = IN2[`FP8_WIDTH-1+fp8_e4m3_i*`FP8_WIDTH];
        wire [`FP8_E4M3_EXP_WIDTH-1:0] IN2_EXP_FP8_E4M3 = IN2[`FP8_E4M3_EXP_WIDTH+`FP8_E4M3_MAN_WIDTH-1+fp8_e4m3_i*`FP8_WIDTH:`FP8_E4M3_MAN_WIDTH+fp8_e4m3_i*`FP8_WIDTH];
        wire [`FP8_E4M3_MAN_WIDTH:0]   IN2_MAN_FP8_E4M3 = {1'b1, IN2[`FP8_E4M3_MAN_WIDTH-1+fp8_e4m3_i*`FP8_WIDTH:fp8_e4m3_i*`FP8_WIDTH]};

        wire IN_EXP_CMP_FP8_E4M3 = IN1_EXP_FP8_E4M3 >= IN2_EXP_FP8_E4M3;
        wire [`FP8_E4M3_EXP_WIDTH:0] IN_EXP_SUB_pre_FP8_E4M3 = {1'b0, IN1_EXP_FP8_E4M3} + ~{1'b0, IN2_EXP_FP8_E4M3};
        wire [`FP8_E4M3_EXP_WIDTH:0] IN_EXP_SUB_12_FP8_E4M3 = IN_EXP_SUB_pre_FP8_E4M3 + 1'b1;
        wire [`FP8_E4M3_EXP_WIDTH:0] IN_EXP_SUB_21_FP8_E4M3 = ~IN_EXP_SUB_pre_FP8_E4M3;
        wire IN1_Larger_FP8_E4M3 = (IN1_EXP_FP8_E4M3 > IN2_EXP_FP8_E4M3) || (IN1_EXP_FP8_E4M3 == IN2_EXP_FP8_E4M3 && IN1_MAN_FP8_E4M3 >= IN2_MAN_FP8_E4M3);
        
        assign EXP_DIFF_FP8_E4M3[fp8_e4m3_i] = IN_EXP_CMP_FP8_E4M3 ? IN_EXP_SUB_12_FP8_E4M3[`FP8_E4M3_EXP_WIDTH:0] : IN_EXP_SUB_21_FP8_E4M3[`FP8_E4M3_EXP_WIDTH:0];
        assign Larger_SIG_FP8_E4M3[fp8_e4m3_i] = IN1_Larger_FP8_E4M3 ? IN1_SIG_FP8_E4M3 : IN2_SIG_FP8_E4M3;
        assign Smaller_SIG_FP8_E4M3[fp8_e4m3_i] = IN1_Larger_FP8_E4M3 ? IN2_SIG_FP8_E4M3 : IN1_SIG_FP8_E4M3;
        assign Larger_EXP_FP8_E4M3[fp8_e4m3_i] = IN1_Larger_FP8_E4M3 ? IN1_EXP_FP8_E4M3 : IN2_EXP_FP8_E4M3;
        assign Larger_MAN_FP8_E4M3[fp8_e4m3_i] = IN1_Larger_FP8_E4M3 ? IN1_MAN_FP8_E4M3 : IN2_MAN_FP8_E4M3;
        assign Smaller_MAN_FP8_E4M3[fp8_e4m3_i] = IN1_Larger_FP8_E4M3 ? IN2_MAN_FP8_E4M3 : IN1_MAN_FP8_E4M3;
    end
endgenerate

// CONFIG_FP8_E5M2
wire [`FP8_E5M2_EXP_WIDTH:0] EXP_DIFF_FP8_E5M2 [3:0];
wire [3:0] Larger_SIG_FP8_E5M2;
wire [3:0] Smaller_SIG_FP8_E5M2;
wire [`FP8_E5M2_EXP_WIDTH-1:0] Larger_EXP_FP8_E5M2 [3:0];
wire [`FP8_E5M2_MAN_WIDTH:0]  Larger_MAN_FP8_E5M2  [3:0];
wire [`FP8_E5M2_MAN_WIDTH:0]  Smaller_MAN_FP8_E5M2 [3:0];

genvar fp8_e5m2_i;
generate
    for (fp8_e5m2_i = 0; fp8_e5m2_i < 4; fp8_e5m2_i = fp8_e5m2_i + 1) begin
        wire IN1_SIG_FP8_E5M2 = IN1[`FP8_WIDTH-1+fp8_e5m2_i*`FP8_WIDTH];
        wire [`FP8_E5M2_EXP_WIDTH-1:0] IN1_EXP_FP8_E5M2 = IN1[`FP8_E5M2_EXP_WIDTH+`FP8_E5M2_MAN_WIDTH-1+fp8_e5m2_i*`FP8_WIDTH:`FP8_E5M2_MAN_WIDTH+fp8_e5m2_i*`FP8_WIDTH];
        wire [`FP8_E5M2_MAN_WIDTH:0]   IN1_MAN_FP8_E5M2 = {1'b1, IN1[`FP8_E5M2_MAN_WIDTH-1+fp8_e5m2_i*`FP8_WIDTH:fp8_e5m2_i*`FP8_WIDTH]};

        wire IN2_SIG_FP8_E5M2 = IN2[`FP8_WIDTH-1+fp8_e5m2_i*`FP8_WIDTH];
        wire [`FP8_E5M2_EXP_WIDTH-1:0] IN2_EXP_FP8_E5M2 = IN2[`FP8_E5M2_EXP_WIDTH+`FP8_E5M2_MAN_WIDTH-1+fp8_e5m2_i*`FP8_WIDTH:`FP8_E5M2_MAN_WIDTH+fp8_e5m2_i*`FP8_WIDTH];
        wire [`FP8_E5M2_MAN_WIDTH:0]   IN2_MAN_FP8_E5M2 = {1'b1, IN2[`FP8_E5M2_MAN_WIDTH-1+fp8_e5m2_i*`FP8_WIDTH:fp8_e5m2_i*`FP8_WIDTH]};

        wire IN_EXP_CMP_FP8_E5M2 = IN1_EXP_FP8_E5M2 >= IN2_EXP_FP8_E5M2;
        wire [`FP8_E5M2_EXP_WIDTH:0] IN_EXP_SUB_pre_FP8_E5M2 = {1'b0, IN1_EXP_FP8_E5M2} + ~{1'b0, IN2_EXP_FP8_E5M2};
        wire [`FP8_E5M2_EXP_WIDTH:0] IN_EXP_SUB_12_FP8_E5M2 = IN_EXP_SUB_pre_FP8_E5M2 + 1'b1;
        wire [`FP8_E5M2_EXP_WIDTH:0] IN_EXP_SUB_21_FP8_E5M2 = ~IN_EXP_SUB_pre_FP8_E5M2;
        wire IN1_Larger_FP8_E5M2 = (IN1_EXP_FP8_E5M2 > IN2_EXP_FP8_E5M2) || (IN1_EXP_FP8_E5M2 == IN2_EXP_FP8_E5M2 && IN1_MAN_FP8_E5M2 >= IN2_MAN_FP8_E5M2);
        
        assign EXP_DIFF_FP8_E5M2[fp8_e5m2_i] = IN_EXP_CMP_FP8_E5M2 ? IN_EXP_SUB_12_FP8_E5M2[`FP8_E5M2_EXP_WIDTH:0] : IN_EXP_SUB_21_FP8_E5M2[`FP8_E5M2_EXP_WIDTH:0];
        assign Larger_SIG_FP8_E5M2[fp8_e5m2_i] = IN1_Larger_FP8_E5M2 ? IN1_SIG_FP8_E5M2 : IN2_SIG_FP8_E5M2;
        assign Smaller_SIG_FP8_E5M2[fp8_e5m2_i] = IN1_Larger_FP8_E5M2 ? IN2_SIG_FP8_E5M2 : IN1_SIG_FP8_E5M2;
        assign Larger_EXP_FP8_E5M2[fp8_e5m2_i] = IN1_Larger_FP8_E5M2 ? IN1_EXP_FP8_E5M2 : IN2_EXP_FP8_E5M2;
        assign Larger_MAN_FP8_E5M2[fp8_e5m2_i] = IN1_Larger_FP8_E5M2 ? IN1_MAN_FP8_E5M2 : IN2_MAN_FP8_E5M2;
        assign Smaller_MAN_FP8_E5M2[fp8_e5m2_i] = IN1_Larger_FP8_E5M2 ? IN2_MAN_FP8_E5M2 : IN1_MAN_FP8_E5M2;
    end
endgenerate

// From config to data
logic [19:0] EXP_DIFF;
logic [3:0]  Larger_SIG;
logic [3:0]  Smaller_SIG;
logic [19:0] Larger_EXP;
logic [23:0] Larger_MAN;
logic [23:0] Smaller_MAN;


always_comb begin
    case(CONFIG_FP)
        `CONFIG_FP16: begin
            EXP_DIFF = {5'b0, EXP_DIFF_FP16[1], 5'b0, EXP_DIFF_FP16[0]};
            Larger_SIG = {1'b0, Larger_SIG_FP16[1], 1'b0, Larger_SIG_FP16[0]};
            Smaller_SIG = {1'b0, Smaller_SIG_FP16[1], 1'b0, Smaller_SIG_FP16[0]};
            Larger_EXP = {5'b0, Larger_EXP_FP16[1], 5'b0, Larger_EXP_FP16[0]};
            Larger_MAN = {1'b0, Larger_MAN_FP16[1], 1'b0, Larger_MAN_FP16[0]};
            Smaller_MAN = {1'b0, Smaller_MAN_FP16[1], 1'b0, Smaller_MAN_FP16[0]};
        end
        `CONFIG_BF16: begin
            EXP_DIFF = {2'b0, EXP_DIFF_BF16[1], 2'b0, EXP_DIFF_BF16[0]};
            Larger_SIG = {1'b0, Larger_SIG_BF16[1], 1'b0, Larger_SIG_BF16[0]};
            Smaller_SIG = {1'b0, Smaller_SIG_BF16[1], 1'b0, Smaller_SIG_BF16[0]};
            Larger_EXP = {2'b0, Larger_EXP_BF16[1], 2'b0, Larger_EXP_BF16[0]};
            Larger_MAN = {4'b0, Larger_MAN_BF16[1], 4'b0, Larger_MAN_BF16[0]};
            Smaller_MAN = {4'b0, Smaller_MAN_BF16[1], 4'b0, Smaller_MAN_BF16[0]};
        end
        `CONFIG_FP8_E4M3: begin
            EXP_DIFF = {1'b0, EXP_DIFF_FP8_E4M3[3], 1'b0, EXP_DIFF_FP8_E4M3[2], 1'b0, EXP_DIFF_FP8_E4M3[1], 1'b0, EXP_DIFF_FP8_E4M3[0]};
            Larger_SIG = Larger_SIG_FP8_E4M3;
            Smaller_SIG = Smaller_SIG_FP8_E4M3;
            Larger_EXP = {1'b0, Larger_EXP_FP8_E4M3[3], 1'b0, Larger_EXP_FP8_E4M3[2], 1'b0, Larger_EXP_FP8_E4M3[1], 1'b0, Larger_EXP_FP8_E4M3[0]};
            Larger_MAN = {2'b0, Larger_MAN_FP8_E4M3[3], 2'b0, Larger_MAN_FP8_E4M3[2], 2'b0, Larger_MAN_FP8_E4M3[1], 2'b0, Larger_MAN_FP8_E4M3[0]};
            Smaller_MAN = {2'b0, Smaller_MAN_FP8_E4M3[3], 2'b0, Smaller_MAN_FP8_E4M3[2], 2'b0, Smaller_MAN_FP8_E4M3[1], 2'b0, Smaller_MAN_FP8_E4M3[0]};
        end
        `CONFIG_FP8_E5M2: begin
            EXP_DIFF = {EXP_DIFF_FP8_E5M2[3], EXP_DIFF_FP8_E5M2[2], EXP_DIFF_FP8_E5M2[1], EXP_DIFF_FP8_E5M2[0]};
            Larger_SIG = Larger_SIG_FP8_E5M2;
            Smaller_SIG = Smaller_SIG_FP8_E5M2;
            Larger_EXP = {Larger_EXP_FP8_E5M2[3], Larger_EXP_FP8_E5M2[2], Larger_EXP_FP8_E5M2[1], Larger_EXP_FP8_E5M2[0]};
            Larger_MAN = {3'b0, Larger_MAN_FP8_E5M2[3], 3'b0, Larger_MAN_FP8_E5M2[2], 3'b0, Larger_MAN_FP8_E5M2[1], 3'b0, Larger_MAN_FP8_E5M2[0]};
            Smaller_MAN = {3'b0, Smaller_MAN_FP8_E5M2[3], 3'b0, Smaller_MAN_FP8_E5M2[2], 3'b0, Smaller_MAN_FP8_E5M2[1], 3'b0, Smaller_MAN_FP8_E5M2[0]};
        end
        default: begin
            EXP_DIFF = {12'b0, EXP_DIFF_FP32};
            Larger_SIG = {3'b0, Larger_SIG_FP32};
            Smaller_SIG = {3'b0, Smaller_SIG_FP32};
            Larger_EXP = {12'b0, Larger_EXP_FP32};
            Larger_MAN = Larger_MAN_FP32;
            Smaller_MAN = Smaller_MAN_FP32;
        end
    endcase  
end

// =============================== far path ===============================
logic [23:0] Shifted_Small;
logic [2:0] GRS [3:0];
Shifter_Fp32to8 shifter(
    .IN(Smaller_MAN),
    .DIFF(EXP_DIFF),
    .CONFIG_FP(CONFIG_FP),

    .OUT(Shifted_Small),
    .OUT_GRS(GRS)
);

logic [1:0] Far_ExpAdd [3:0];
logic [23:0] Far_MAN;
logic [19:0] Far_EXP;

Carry_Bypass_4FarMan carry_bypass_man(
    .IN_L(Larger_MAN),
    .IN_S(Shifted_Small),
    .IN_GRS(GRS),
    .CONFIG_FP(CONFIG_FP),
    .ROUND_TYPE(ROUND_TYPE),
    .IN_SIG(Larger_SIG),
    .isSUB(Larger_SIG ^ Smaller_SIG),

    .OUT(Far_MAN),
    .OUT_ExpAdd(Far_ExpAdd)
);

Carry_Bypass_4FarExp carry_bypass_exp(
    .IN_EXP(Larger_EXP),
    .IN_ExpAdd(Far_ExpAdd),
    .CONFIG_FP(CONFIG_FP),

    .OUT_Exp(Far_EXP)
);

// =============================== near path ===============================











endmodule