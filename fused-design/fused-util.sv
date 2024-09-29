`include "define.sv"

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
                `CONFIG_FP16: Lv1_shift[lv1_j] = DIFF[lv1_j*10+1:lv1_j*10];
                `CONFIG_BF16: Lv1_shift[lv1_j] = DIFF[lv1_j*10+1:lv1_j*10];
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
assign Lv2_shift[1] = CONFIG_FP == `CONFIG_FP16 || CONFIG_FP == `CONFIG_BF16 ? DIFF[11:10] : DIFF[3:2];

logic [11:0] Lv2_Res [1:0];
logic [2:0] Lv2_GRS [1:0];

genvar lv2_i;
generate
    for(lv2_i = 0; lv2_i < 2; lv2_i = lv2_i + 1) begin
        always_comb begin
            case (Lv1_shift[lv2_i])
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
            OUT_GRS[0] = BigDiff_FP8_E4M3[0] && DIFF[ 3] ? 3'b001 : Lv1_GRS[0];
            OUT_GRS[1] = BigDiff_FP8_E4M3[1] && DIFF[ 8] ? 3'b001 : Lv1_GRS[1];
            OUT_GRS[2] = BigDiff_FP8_E4M3[2] && DIFF[13] ? 3'b001 : Lv1_GRS[2];
            OUT_GRS[3] = BigDiff_FP8_E4M3[3] && DIFF[18] ? 3'b001 : Lv1_GRS[3];
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