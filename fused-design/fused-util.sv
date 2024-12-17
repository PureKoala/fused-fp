`include "define.sv"

module rounding (
    input  logic IN_SIG,
    input  logic [3:0] IN,
    input  logic [`ROUND_TYPE_WIDTH-1:0] ROUND_TYPE,

    output logic OUT
);

always_comb begin
    case(ROUND_TYPE)
        `ROUND_RTNE: begin
            OUT = IN[2] && (IN[1] || IN[0] || IN[3]);
        end
        `ROUND_RTNA: begin
            OUT = IN[2];
        end
        `ROUND_UPWARD: begin
            OUT = |IN[2:0] && IN_SIG; 
        end
        `ROUND_DOWNWARD: begin
            OUT = |IN[2:0] && !IN_SIG; 
        end
        default: begin
            OUT = 1'b0;
        end
    endcase
end
endmodule

// =======================================================================================================
// =======================================================================================================
// =======================================================================================================

module Shifter_Fp32to8 (
    input logic [23:0] IN,
    input logic [19:0] DIFF,
    input logic [`CONFIG_WIDTH-1:0] CONFIG_FP,

    output logic [24:0] OUT,
    output logic [2:0] OUT_GRS [3:0]
);

// CONFIG_FP32
logic [2:0] GRS_FP32; // GRS = Guard, Round, Sticky
logic [2:0] GRS_FP16 [1:0];
logic [2:0] GRS_BF16 [1:0];
logic [2:0] GRS_FP8_E4M3 [3:0];
logic [2:0] GRS_FP8_E5M2 [3:0];

wire BigDiff_FP32 = (DIFF[7:0] >= (`FP32_MAN_WIDTH + 1'b1));
wire [1:0] BigDiff_FP16 = { (DIFF[14:10] >= (`FP16_MAN_WIDTH + 1'b1)),
                            (DIFF[ 4: 0] >= (`FP16_MAN_WIDTH + 1'b1))};
wire [1:0] BigDiff_BF16 = { (DIFF[17:10] >= (`BF16_MAN_WIDTH + 1'b1)),
                            (DIFF[ 7: 0] >= (`BF16_MAN_WIDTH + 1'b1))};
wire [3:0] BigDiff_FP8_E4M3 = { (DIFF[18:15] >= (`FP8_E4M3_MAN_WIDTH + 1'b1)),
                                (DIFF[13:10] >= (`FP8_E4M3_MAN_WIDTH + 1'b1)),
                                (DIFF[ 8: 5] >= (`FP8_E4M3_MAN_WIDTH + 1'b1)),
                                (DIFF[ 3: 0] >= (`FP8_E4M3_MAN_WIDTH + 1'b1))};
wire [3:0] BigDiff_FP8_E5M2 = { (DIFF[19:15] >= (`FP8_E5M2_MAN_WIDTH + 1'b1)),
                                (DIFF[14:10] >= (`FP8_E5M2_MAN_WIDTH + 1'b1)),
                                (DIFF[ 9: 5] >= (`FP8_E5M2_MAN_WIDTH + 1'b1)),
                                (DIFF[ 4: 0] >= (`FP8_E5M2_MAN_WIDTH + 1'b1))};



// level 1
wire [2:0] Lv1_pass = (CONFIG_FP == `CONFIG_FP8_E4M3 || CONFIG_FP == `CONFIG_FP8_E5M2) ? 3'b0 
                        : ((CONFIG_FP == `CONFIG_FP16) ? 3'b101
                        : ((CONFIG_FP == `CONFIG_BF16) ? 3'b101
                        : 3'b111));
logic [5:0] Lv1_data [3:0];
logic [2:0] Lv1_pass_data [2:0];
logic [1:0] Lv1_shift [3:0];

logic [5:0] Lv1_Res [3:0];
logic [2:0] Lv1_GRS [3:0];

genvar lv1_i, lv1_j;
generate
    for (lv1_i = 0; lv1_i < 3; lv1_i = lv1_i + 1) begin
        assign Lv1_pass_data[lv1_i] = Lv1_pass[lv1_i] ? {IN[(lv1_i+1)*6+2:(lv1_i+1)*6]} : 'd0;
    end

    for(lv1_j = 0; lv1_j < 4; lv1_j = lv1_j + 1) begin
        assign Lv1_data[lv1_j] = IN[lv1_j*6 +: 6];
        always_comb begin
            case(CONFIG_FP)
                `CONFIG_FP16: Lv1_shift[lv1_j] = lv1_j < 2 ? DIFF[1:0] : DIFF[11:10];
                `CONFIG_BF16: Lv1_shift[lv1_j] = lv1_j < 2 ? DIFF[1:0] : DIFF[11:10];
                `CONFIG_FP8_E4M3: Lv1_shift[lv1_j] = DIFF[lv1_j*5+1:lv1_j*5];
                `CONFIG_FP8_E5M2: Lv1_shift[lv1_j] = DIFF[lv1_j*5+1:lv1_j*5];
                default: Lv1_shift[lv1_j] = DIFF[1:0];
            endcase
        end
        always_comb begin
            case (Lv1_shift[lv1_j])
                2'b00: begin
                    Lv1_Res[lv1_j] = Lv1_data[lv1_j];
                    Lv1_GRS[lv1_j] = 3'b0;
                end
                2'b01: begin
                    Lv1_Res[lv1_j] = {(lv1_j == 3 ? 1'b0 : Lv1_pass_data[lv1_j][0]), Lv1_data[lv1_j][5:1]};
                    Lv1_GRS[lv1_j] = {Lv1_data[lv1_j][0], 2'b0};
                end
                2'b10: begin
                    Lv1_Res[lv1_j] = {(lv1_j == 3 ? 2'b0 : Lv1_pass_data[lv1_j][1:0]), Lv1_data[lv1_j][5:2]};
                    Lv1_GRS[lv1_j] = {Lv1_data[lv1_j][1:0], 1'b0};
                end
                2'b11: begin
                    Lv1_Res[lv1_j] = {(lv1_j == 3 ? 3'b0 : Lv1_pass_data[lv1_j][2:0]), Lv1_data[lv1_j][5:3]};
                    Lv1_GRS[lv1_j] = Lv1_data[lv1_j][2:0];
                end
            endcase
        end
    end
endgenerate

// level 2
logic [11:0] Lv2_data [1:0];
assign Lv2_data[0] = {Lv1_Res[1], Lv1_Res[0]};
assign Lv2_data[1] = {Lv1_Res[3], Lv1_Res[2]};

logic [1:0] Lv2_shift [1:0];
assign Lv2_shift[0] = DIFF[3:2];
assign Lv2_shift[1] = CONFIG_FP == `CONFIG_FP16 || CONFIG_FP == `CONFIG_BF16 ? DIFF[13:12] : DIFF[3:2];

logic [11:0] Lv2_Res [1:0];
logic [2:0]  Lv2_GRS [1:0];

genvar lv2_i;
generate
    for(lv2_i = 0; lv2_i < 2; lv2_i = lv2_i + 1) begin
        always_comb begin
            case (Lv2_shift[lv2_i])
                2'b00: begin
                    Lv2_Res[lv2_i] = Lv2_data[lv2_i];
                    Lv2_GRS[lv2_i] = Lv1_GRS[lv2_i*2];
                end
                2'b01: begin
                    Lv2_Res[lv2_i] = {(lv2_i == 1 ? 4'b0 : Lv2_data[1][3:0]), Lv2_data[lv2_i][11:4]};
                    Lv2_GRS[lv2_i] = {Lv2_data[lv2_i][3:2], |{Lv2_data[lv2_i][1:0], Lv1_GRS[lv2_i*2]}};
                end
                2'b10: begin
                    Lv2_Res[lv2_i] = {(lv2_i == 1 ? 8'b0 : Lv2_data[1][7:0]), Lv2_data[lv2_i][11:8]};
                    Lv2_GRS[lv2_i] = {Lv2_data[lv2_i][7:6], |{Lv2_data[lv2_i][5:0], Lv1_GRS[lv2_i*2]}};
                end
                2'b11: begin
                    Lv2_Res[lv2_i] = lv2_i == 1 ? 12'b0 : Lv2_data[1];
                    Lv2_GRS[lv2_i] = {Lv2_data[lv2_i][11:10], |{Lv2_data[lv2_i][9:0], Lv1_GRS[lv2_i*2]}};
                end
            endcase
        end
    end
endgenerate

// level 3
logic [23:0] Lv3_data;
assign Lv3_data = {Lv2_Res[1], Lv2_Res[0]};

logic [23:0] Lv3_Res;
logic [2:0] Lv3_GRS;

always_comb begin
    case (DIFF[5:4])
        2'b00: begin
            Lv3_Res = Lv3_data;
            Lv3_GRS = Lv2_GRS[0];
        end
        2'b01: begin
            Lv3_Res = {16'b0, Lv3_data[23:16]};
            Lv3_GRS = {Lv3_data[15:14], |{Lv3_data[13:0], Lv2_GRS[0]}};
        end
    endcase
end

// output
always_comb begin
    case (CONFIG_FP)
        `CONFIG_FP32: begin
            OUT = BigDiff_FP32 ? 24'd0 : Lv3_Res;
            OUT_GRS[0] = BigDiff_FP32 && |DIFF[7:5] ? 3'b001 : Lv3_GRS;
            OUT_GRS[1] = 3'b0;
            OUT_GRS[2] = 3'b0;
            OUT_GRS[3] = 3'b0;
        end
        `CONFIG_FP16: begin
            OUT = { (BigDiff_FP16[1] ? 12'b0 : Lv2_Res[1]),
                    (BigDiff_FP16[0] ? 12'b0 : Lv2_Res[0])};
            OUT_GRS[0] = BigDiff_FP16[0] && DIFF[ 4] ? 3'b001 : Lv2_GRS[0];
            OUT_GRS[2] = BigDiff_FP16[1] && DIFF[14] ? 3'b001 : Lv2_GRS[1];
            OUT_GRS[1] = 3'b0;
            OUT_GRS[3] = 3'b0;
        end
        `CONFIG_BF16: begin
            OUT = { (BigDiff_BF16[1] ? 12'b0 : Lv2_Res[1]),
                    (BigDiff_BF16[0] ? 12'b0 : Lv2_Res[0])};
            OUT_GRS[0] = BigDiff_BF16[0] && |DIFF[7:4] ? 3'b001 : Lv2_GRS[0];
            OUT_GRS[2] = BigDiff_BF16[1] && |DIFF[17:14] ? 3'b001 : Lv2_GRS[1];
            OUT_GRS[1] = 3'b0;
            OUT_GRS[3] = 3'b0;
        end
        `CONFIG_FP8_E4M3: begin
            OUT = { (BigDiff_FP8_E4M3[3] ? 6'b0 : Lv1_Res[3]),
                    (BigDiff_FP8_E4M3[2] ? 6'b0 : Lv1_Res[2]),
                    (BigDiff_FP8_E4M3[1] ? 6'b0 : Lv1_Res[1]),
                    (BigDiff_FP8_E4M3[0] ? 6'b0 : Lv1_Res[0])};
            OUT_GRS[0] = BigDiff_FP8_E4M3[0] ? (DIFF[ 3] ? 3'b001 : {Lv1_Res[0][0], Lv1_GRS[0][3:2], |Lv1_GRS[0][1:0]}) : Lv1_GRS[0];
            OUT_GRS[1] = BigDiff_FP8_E4M3[1] ? (DIFF[ 8] ? 3'b001 : {Lv1_Res[1][0], Lv1_GRS[1][3:2], |Lv1_GRS[1][1:0]}) : Lv1_GRS[1];
            OUT_GRS[2] = BigDiff_FP8_E4M3[2] ? (DIFF[13] ? 3'b001 : {Lv1_Res[2][0], Lv1_GRS[2][3:2], |Lv1_GRS[2][1:0]}) : Lv1_GRS[2];
            OUT_GRS[3] = BigDiff_FP8_E4M3[3] ? (DIFF[18] ? 3'b001 : {Lv1_Res[3][0], Lv1_GRS[3][3:2], |Lv1_GRS[3][1:0]}) : Lv1_GRS[3];
        end
        `CONFIG_FP8_E5M2: begin
            OUT = { (BigDiff_FP8_E5M2[3] ? 6'b0 : Lv1_Res[3]),
                    (BigDiff_FP8_E5M2[2] ? 6'b0 : Lv1_Res[2]),
                    (BigDiff_FP8_E5M2[1] ? 6'b0 : Lv1_Res[1]),
                    (BigDiff_FP8_E5M2[0] ? 6'b0 : Lv1_Res[0])};
            OUT_GRS[0] = BigDiff_FP8_E5M2[0] && |DIFF[4:2] ? 3'b001 : Lv1_GRS[0];
            OUT_GRS[1] = BigDiff_FP8_E5M2[1] && |DIFF[9:7] ? 3'b001 : Lv1_GRS[1];
            OUT_GRS[2] = BigDiff_FP8_E5M2[2] && |DIFF[14:12] ? 3'b001 : Lv1_GRS[2];
            OUT_GRS[3] = BigDiff_FP8_E5M2[3] && |DIFF[19:17] ? 3'b001 : Lv1_GRS[3];
        end
    endcase
end

endmodule


// =======================================================================================================
// =======================================================================================================
// =======================================================================================================

module Carry_Bypass_4FarMan (
    input logic [23:0] IN_L,
    input logic [23:0] IN_S,
    input logic [ 2:0] IN_GRS [3:0],
    input logic [ 3:0] IN_SIG,
    input logic [ 3:0] isSUB,
    input logic [`CONFIG_WIDTH-1:0] CONFIG_FP,

    input logic [`ROUND_TYPE_WIDTH-1:0] ROUND_TYPE,

    output logic [1:0] OUT_ExpAdd [3:0], // encoding: 00: -1, 01: 0, 10: +1
    output logic [23:0] OUT
);

logic [5:0] L_Data [3:0];
logic [5:0] S_Data [3:0];
logic [2:0] GRS [3:0];
logic [3:0] C_BP;

genvar init;
generate
    for (init = 0; init < 4; init = init + 1) begin
        assign L_Data[init] = IN_L[init*6 +: 6];
        assign S_Data[init] = isSUB[init] ? ~IN_S[init*6 +: 6] : IN_S[init*6 +: 6];
        assign GRS[init]    = isSUB[init] ? ~IN_GRS[init] : IN_GRS[init];
        assign C_BP[init]   = &(S_Data[init] ^ L_Data[init]);
    end
endgenerate

// determine whether need to add 1 [rounding or inverse+1]
logic [3:0] PLUS_ONE;
logic [3:0] R_GRS [3:0];

genvar i_plus;
generate
    for (i_plus = 0; i_plus < 4; i_plus = i_plus + 1) begin
        logic R_OUT;
        assign R_GRS[i_plus] = {L_Data[i_plus][0] & S_Data[i_plus][0], (GRS[i_plus] + isSUB[i_plus]) & 3'b111};
        
        rounding rounder(.IN_SIG(IN_SIG[i_plus]), .IN(R_GRS[i_plus]), .ROUND_TYPE(ROUND_TYPE), .OUT(R_OUT));
        assign PLUS_ONE[i_plus] = &{isSUB, GRS[i_plus]} ? 1'b1 : R_OUT;
    end
endgenerate


// carry-bypass data adder
logic [6:0] pre_res [3:0]; // result without true sub and round
logic [3:0] bypass_ena;
logic [3:0] bypass_cout;

genvar i_ena, i_pre_res;
generate
    for(i_ena = 0; i_ena < 4; i_ena = i_ena + 1) begin
        always_comb begin
            case(CONFIG_FP)
                `CONFIG_FP32: begin
                    bypass_ena = 4'b1111;
                end
                `CONFIG_FP16, `CONFIG_BF16: begin
                    bypass_ena = 4'b1010;
                end
                `CONFIG_FP8_E4M3, `CONFIG_FP8_E5M2: begin
                    bypass_ena = 4'b0000;
                end
                default: begin
                    bypass_ena = 4'b0000;
                end
            endcase
        end
    end

    for(i_pre_res = 0; i_pre_res < 4; i_pre_res = i_pre_res + 1) begin
        wire cin = i_pre_res == 0 ? PLUS_ONE[0] : (bypass_ena[i_pre_res-1] ? bypass_cout[i_pre_res-1] : PLUS_ONE[i_pre_res]);
        assign pre_res[i_pre_res] = L_Data[i_pre_res] + S_Data[i_pre_res] + cin;
        assign bypass_cout[i_pre_res] = C_BP[i_pre_res] ? cin : pre_res[i_pre_res][6];
    end
endgenerate

// shift for final result
logic [5:0] res [3:0];
logic [1:0] res_expadd [3:0];

genvar i_res;
generate
    for(i_res = 0; i_res < 4; i_res = i_res + 1) begin
        always_comb begin
            case(CONFIG_FP)
                `CONFIG_FP32: begin
                    if (bypass_cout[3]) begin
                        res[i_res] = {i_res == 4 ? 1'b1 : pre_res[i_res+1][0], pre_res[i_res][5:1]};
                        res_expadd[i_res] = 2'b10;
                    end else if (pre_res[3][5]) begin
                        res[i_res] = pre_res[i_res];
                        res_expadd[i_res] = 2'b01;
                    end else begin
                        res[i_res] = {pre_res[i_res][4:0], i_res == 0 ? R_GRS[i_res][2] : pre_res[i_res-1][5]};
                        res_expadd[i_res] = 2'b00;
                    end
                end
                `CONFIG_FP16: begin
                    if (i_res == 0 | i_res == 1) begin
                        if (pre_res[1][5]) begin
                            res[i_res] = {i_res == 1 ? 1'b0 : pre_res[1][0], pre_res[i_res][5:1]};
                            res_expadd[i_res] = 2'b10;
                        end else if (pre_res[1][4]) begin
                            res[i_res] = pre_res[i_res];
                            res_expadd[i_res] = 2'b01;
                        end else begin
                            res[i_res] = {pre_res[i_res][4:0], i_res == 0 ? R_GRS[i_res][2] : pre_res[i_res-1][5]};
                            res_expadd[i_res] = 2'b00;
                        end
                    end else begin
                        if (pre_res[3][5]) begin
                            res[i_res] = {i_res == 3 ? 1'b0 : pre_res[3][0], pre_res[i_res][5:1]};
                            res_expadd[i_res] = 2'b10;
                        end else if (pre_res[3][4]) begin
                            res[i_res] = pre_res[i_res];
                            res_expadd[i_res] = 2'b01;
                        end else begin
                            res[i_res] = {pre_res[i_res][4:0], i_res == 2 ? R_GRS[i_res][2] : pre_res[i_res-1][5]};
                            res_expadd[i_res] = 2'b00;
                        end
                    end
                end
                `CONFIG_BF16: begin
                    if (i_res == 0 | i_res == 1) begin
                        if (pre_res[1][2]) begin
                            res[i_res] = {i_res == 1 ? 1'b0 : pre_res[1][0], pre_res[i_res][7:1]};
                            res_expadd[i_res] = 2'b10;
                        end else if (pre_res[1][1]) begin
                            res[i_res] = pre_res[i_res];
                            res_expadd[i_res] = 2'b01;
                        end else begin
                            res[i_res] = {pre_res[i_res][6:0], i_res == 0 ? R_GRS[i_res][2] : pre_res[i_res-1][7]};
                            res_expadd[i_res] = 2'b00;
                        end
                    end else begin
                        if (pre_res[3][2]) begin
                            res[i_res] = {i_res == 3 ? 1'b0 : pre_res[3][0], pre_res[i_res][7:1]};
                            res_expadd[i_res] = 2'b10;
                        end else if (pre_res[3][1]) begin
                            res[i_res] = pre_res[i_res];
                            res_expadd[i_res] = 2'b01;
                        end else begin
                            res[i_res] = {pre_res[i_res][6:0], i_res == 2 ? R_GRS[i_res][2] : pre_res[i_res-1][7]};
                            res_expadd[i_res] = 2'b00;
                        end
                    end
                end
                `CONFIG_FP8_E4M3: begin
                    if (pre_res[i_res][4]) begin
                        res[i_res] = pre_res[i_res] >> 1;
                        res_expadd[i_res] = 2'b10;
                    end else if (pre_res[i_res][3]) begin
                        res[i_res] = pre_res[i_res];
                        res_expadd[i_res] = 2'b01;
                    end else begin
                        res[i_res] = {pre_res[i_res][2:0], R_GRS[i_res][2]};
                        res_expadd[i_res] = 2'b00;
                    end
                end
                `CONFIG_FP8_E5M2: begin
                    if (pre_res[i_res][3]) begin
                        res[i_res] = pre_res[i_res] >> 1;
                        res_expadd[i_res] = 2'b10;
                    end else if (pre_res[i_res][2]) begin
                        res[i_res] = pre_res[i_res];
                        res_expadd[i_res] = 2'b01;
                    end else begin
                        res[i_res] = {pre_res[i_res][1:0], R_GRS[i_res][2]};
                        res_expadd[i_res] = 2'b00;
                    end
                end
                default: begin
                    res[i_res] = 'b0;
                    res_expadd[i_res] = 2'b00;
                end
            endcase
        end
    end
endgenerate

assign OUT = {res[3], res[2], res[1], res[0]};
assign OUT_ExpAdd = res_expadd;

endmodule

// =======================================================================================================
// =======================================================================================================
// =======================================================================================================

module Carry_Bypass_4FarExp (
    input logic [19:0] IN_Exp,
    input logic [ 1:0] IN_ExpAdd [3:0], // encoding: 00: -1, 01: 0, 10: +1

    input logic [`CONFIG_WIDTH-1:0] CONFIG_FP,

    output logic [19:0] OUT_Exp
);

// carry-bypass enable
logic [2:0] bypass_ena;
genvar i_ena;
generate
    for(i_ena = 0; i_ena < 4; i_ena = i_ena + 1) begin
        always_comb begin
            case(CONFIG_FP)
                `CONFIG_FP32: begin
                    bypass_ena = 3'b111;
                end
                `CONFIG_FP16, `CONFIG_BF16: begin
                    bypass_ena = 3'b101;
                end
                `CONFIG_FP8_E4M3, `CONFIG_FP8_E5M2: begin
                    bypass_ena = 3'b000;
                end
                default: begin
                    bypass_ena = 3'b000;
                end
            endcase
        end
    end
endgenerate

// added data choose
logic [4:0] Exp_Add_Num [3:0];

localparam [19:0] Exp_Add_Num_FP32_1 = 20'b1;
localparam [19:0] Exp_Add_Num_FP32_m1 = {12'b0, {8{1'b1}}};

localparam [19:0] Exp_Add_Num_16_1 = {9'b0, 1'b1, 9'b0, 1'b1};
localparam [19:0] Exp_Add_Num_FP16_m1 = {5'b0, {5{1'b1}}, 5'b0, {5{1'b1}}};
localparam [19:0] Exp_Add_Num_BF16_m1 = {2'b0, {8{1'b1}}, 2'b0, {8{1'b1}}};

localparam [19:0] Exp_Add_Num_8_1 = {4{4'b0, 1'b1}};
localparam [19:0] Exp_Add_Num_FP8_E4M3_m1 = {4{1'b0, 4'b1111}};
localparam [19:0] Exp_Add_Num_FP8_E5M2_m1 = {20{1'b1}};


genvar i_exp;
generate
    for(i_exp = 0; i_exp < 4; i_exp = i_exp + 1) begin
        always_comb begin
            case(CONFIG_FP)
                `CONFIG_FP32: begin
                    if (IN_ExpAdd[0][1]) begin
                        Exp_Add_Num[i_exp] = Exp_Add_Num_FP32_1[i_exp*5 +: 5];
                    end else if (IN_ExpAdd[0][0]) begin
                        Exp_Add_Num[i_exp] = 'b0;
                    end else begin
                        Exp_Add_Num[i_exp] = Exp_Add_Num_FP32_m1[i_exp*5 +: 5];
                    end
                end
                `CONFIG_FP16: begin
                    if (IN_ExpAdd[i_exp][1]) begin
                        Exp_Add_Num[i_exp] = Exp_Add_Num_16_1[i_exp*5 +: 5];
                    end else if (IN_ExpAdd[i_exp][0]) begin
                        Exp_Add_Num[i_exp] = 'b0;
                    end else begin
                        Exp_Add_Num[i_exp] = Exp_Add_Num_FP16_m1[i_exp*5 +: 5];
                    end
                end
                `CONFIG_BF16: begin
                    if (IN_ExpAdd[i_exp][1]) begin
                        Exp_Add_Num[i_exp] = Exp_Add_Num_16_1[i_exp*5 +: 5];
                    end else if (IN_ExpAdd[i_exp][0]) begin
                        Exp_Add_Num[i_exp] = 'b0;
                    end else begin
                        Exp_Add_Num[i_exp] = Exp_Add_Num_BF16_m1[i_exp*5 +: 5];
                    end
                end
                `CONFIG_FP8_E4M3, `CONFIG_FP8_E5M2: begin
                    if (IN_ExpAdd[i_exp][1]) begin
                        Exp_Add_Num[i_exp] = Exp_Add_Num_8_1[i_exp*5 +: 5];
                    end else if (IN_ExpAdd[i_exp][0]) begin
                        Exp_Add_Num[i_exp] = 'b0;
                    end else begin
                        Exp_Add_Num[i_exp] = (CONFIG_FP == `CONFIG_FP8_E4M3) ? Exp_Add_Num_FP8_E4M3_m1[i_exp*5 +: 5] : Exp_Add_Num_FP8_E5M2_m1[i_exp*5 +: 5];
                    end
                end
                default: begin
                    Exp_Add_Num[i_exp] = 5'b0;
                end
            endcase
        end
    end
endgenerate

// carry-propagate signal
logic [3:0] CP; 
genvar i_cp;
generate
    for(i_cp = 0; i_cp < 4; i_cp = i_cp + 1) begin
        assign CP[i_cp] = &(IN_Exp[i_cp*5 +: 5] ^ Exp_Add_Num[i_cp]);
    end
endgenerate

// carry-bypass data adder
logic [5:0] pre_res [3:0];
logic [3:0] bypass_cout;

genvar i_pre_res;
generate
    for(i_pre_res = 0; i_pre_res < 4; i_pre_res = i_pre_res + 1) begin
        wire cin = (i_pre_res > 0) &&  bypass_ena[i_pre_res-1] ? bypass_cout[i_pre_res-1] : 1'b0;
        assign pre_res[i_pre_res] = IN_Exp[i_pre_res*5 +: 5] + Exp_Add_Num[i_pre_res] + cin;
        assign bypass_cout[i_pre_res] = CP[i_pre_res] ? cin : pre_res[i_pre_res][5];
    end
endgenerate

// generate final result
assign OUT_Exp = {pre_res[3][4:0], pre_res[2][4:0], pre_res[1][4:0], pre_res[0][4:0]};

endmodule