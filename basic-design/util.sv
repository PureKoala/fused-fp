module CSA #(
    parameter WIDTH = 7
)(
    input logic [WIDTH-1:0] A,
    input logic [WIDTH-1:0] B,
    input logic [WIDTH-1:0] C,
    input logic PLUS_ONE,

    output logic [WIDTH-1:0] SUM,
    output logic [WIDTH-1:0] CARRY
);

assign SUM = (A ^ B) ^ C;

logic [WIDTH-1:0] carry_inner;
assign carry_inner = (A & B) | (A & C) | (B & C);

assign CARRY = {carry_inner[WIDTH-2:0], PLUS_ONE}; 

endmodule


module CSA_Layer #(
    parameter NUM = 7,
    parameter WIDTH = 7,
    parameter CSAed_NUM = $floor(NUM * 2 / 3),
    parameter Non_CSAed_NUM = NUM - 3 * $floor(NUM / 3)
)(
    input logic [WIDTH-1:0] IN [NUM-1:0],

    output logic [WIDTH-1:0] OUT [CSAed_NUM + Non_CSAed_NUM-1:0]
);

genvar i;
generate
    for(i=0;i<NUM;i=i+3) begin
        if(i+2>=NUM) begin
            assign OUT[i*2/3] = IN[i];
            if(i+1 < NUM) begin
                assign OUT[i*2/3+1] = IN[i+1];
            end
        end else begin
            CSA #(WIDTH) CSA_tree(
                .A(IN[i]),
                .B(IN[i+1]),
                .C(IN[i+2]),
                .PLUS_ONE(1'b0),

                .SUM(OUT[i*2/3]),
                .CARRY(OUT[i*2/3+1])
            );
        end
    end
endgenerate
endmodule


module Radix16_Booth #(
    parameter WIDTH = 24
)(
    input logic [WIDTH-1:0] Multiplicand,
    input logic [4:0] Multiplier,

    output logic [WIDTH+3:0] PartialProduct
);

logic [WIDTH+3:0] X7_sum;
logic [WIDTH+3:0] X7_carry;

logic [WIDTH+3:0] X1 = Multiplicand;
logic [WIDTH+3:0] X2 = Multiplicand << 1;
logic [WIDTH+3:0] X3 = X1 + X2;
logic [WIDTH+3:0] X4 = Multiplicand << 2;
logic [WIDTH+3:0] X5 = X1 + X4;
logic [WIDTH+3:0] X6 = X3 << 1;
logic [WIDTH+3:0] X7= X7_sum + X7_carry;
logic [WIDTH+3:0] X8 = Multiplicand << 3;


CSA #(WIDTH+4) X7_csa(
    .A(X1),
    .B(X2),
    .C(X4),
    .PLUS_ONE(1'b0),

    .SUM(X7_sum),
    .CARRY(X7_carry)
);

logic [3:0] L1_sel;
logic [1:0] L2_sel;
logic       L3_sel;

always_comb begin
    case(Multiplier[4:0])
        5'b00000, 5'b11111: begin // 0
            L1_sel = 4'b0000;
            L2_sel = 2'b00;
            L3_sel = 1'b0;
        end
        5'b00001, 5'b00010, 5'b11110, 5'b11101: begin  // 1
            L1_sel = 4'b0001;
            L2_sel = 2'b00;
            L3_sel = 1'b0;
        end
        5'b00011, 5'b00100, 5'b11100, 5'b11011: begin // 2
            L1_sel = 4'b0000;
            L2_sel = 2'b01;
            L3_sel = 1'b0;
        end
        5'b00110, 5'b00101, 5'b11001, 5'b11010: begin // 3
            L1_sel = 4'b0010;
            L2_sel = 2'b01;
            L3_sel = 1'b0;
        end
        5'b00111, 5'b01000, 5'b11000, 5'b10111: begin // 4
            L1_sel = 4'b0000;
            L2_sel = 2'b00;
            L3_sel = 1'b1;
        end
        5'b01001, 5'b01010, 5'b10110, 5'b10101: begin // 5
            L1_sel = 4'b0100;
            L2_sel = 2'b00;
            L3_sel = 1'b1;
        end
        5'b01011, 5'b01100, 5'b10011, 5'b10100: begin // 6
            L1_sel = 4'b0000;
            L2_sel = 2'b10;
            L3_sel = 1'b1;
        end
        5'b00110, 5'b00101, 5'b11001, 5'b11010: begin // 7 not used here, just for default
            L1_sel = 4'b0000;
            L2_sel = 2'b00;
            L3_sel = 1'b0;
        end
        5'b10000, 5'b01111: begin // 8
            L1_sel = 4'b1000;
            L2_sel = 2'b10;
            L3_sel = 1'b1;
        end
    endcase
end

logic [WIDTH+3:0] L1_0 = L1_sel[0] ? X1 : 'b0;
logic [WIDTH+3:0] L1_1 = L1_sel[1] ? X3 :  X2;
logic [WIDTH+3:0] L1_2 = L1_sel[2] ? X5 :  X4;
logic [WIDTH+3:0] L1_3 = L1_sel[3] ? X8 :  X6;

logic [WIDTH+3:0] L2_0 = L2_sel[0] ? L1_1 : L1_0;
logic [WIDTH+3:0] L2_1 = L2_sel[1] ? L1_3 : L1_2;

logic [WIDTH+3:0] L3_0 = L3_sel    ? L2_1 : L2_0;

logic Mux_Res = ((Multiplier == 5'b00110) || (Multiplier == 5'b00101) || (Multiplier == 5'b11001) || (Multiplier == 5'b11010)) ? X7 : L3_0;

assign PartialProduct = (Multiplier[4] ^ Mux_Res) + Multiplier[4];

endmodule


module Shifter #(
    parameter WIDTH = 24,
    parameter MAXDIFF = 256
)(
    input  logic [WIDTH-1:0] IN,
    input  logic [$clog2(MAXDIFF)-1:0] DIFF,

    output logic [WIDTH+2:0] OUT
);

logic [WIDTH+1:0] IN_GR = {IN, 2'b0};
logic BigDiff = DIFF >= WIDTH;

// level 1
logic [WIDTH+1:0] L1S0 = IN_GR;
logic [WIDTH+1:0] L1S1 = {1'b0, IN_GR[WIDTH-1:1]};
logic [WIDTH+1:0] L1S2 = {2'b0, IN_GR[WIDTH-1:2]};
logic [WIDTH+1:0] L1S3 = {3'b0, IN_GR[WIDTH-1:3]};

logic [WIDTH+1:0] Lv1_Res;
logic Sticky_Lv1;

always_comb begin
    case (DIFF[1:0])
        2'b00: begin
            Lv1_Res = L1S0;
            Sticky_Lv1 = 1'b0;
        end
        2'b01: begin
            Lv1_Res = L1S1;
            Sticky_Lv1 = IN_GR[0];
        end
        2'b10: begin
            Lv1_Res = L1S2;
            Sticky_Lv1 = |IN_GR[1:0];
        end
        2'b11: begin
            Lv1_Res = L1S3;
            Sticky_Lv1 = |IN_GR[2:0];
        end
        default: begin
            Lv1_Res = 'b0;
            Sticky_Lv1 = 'b0;
        end
    endcase
end

// level 2
logic [WIDTH+1:0] L2S0 = Lv1_Res;
logic [WIDTH+1:0] L2S4 = {4'b0, Lv1_Res[WIDTH-1:4]};
logic [WIDTH+1:0] L2S8 = {8'b0, Lv1_Res[WIDTH-1:8]};
logic [WIDTH+1:0] L2S12 = {12'b0, Lv1_Res[WIDTH-1:12]};

logic [WIDTH+1:0] Lv2_Res;
logic Sticky_Lv2;

always_comb begin
    case (DIFF[3:2])
        2'b00: begin
            Lv2_Res = L2S0;
            Sticky_Lv2 = 1'b0;
        end
        2'b01: begin
            Lv2_Res = L2S4;
            Sticky_Lv2 = |Lv1_Res[3:0];
        end
        2'b10: begin
            Lv2_Res = L2S8;
            Sticky_Lv2 = |Lv1_Res[7:0];
        end
        2'b11: begin
            Lv2_Res = L2S12;
            Sticky_Lv2 = |Lv1_Res[11:0];
        end
    endcase
end

// level 2
logic [WIDTH+1:0] L3S0 = Lv2_Res;
logic [WIDTH+1:0] L3S16 = {16'b0, Lv2_Res[WIDTH-1:16]};
`ifdef FP64
logic [WIDTH+1:0] L3S32 = {32'b0, Lv2_Res[WIDTH-1:32]};
logic [WIDTH+1:0] L3S48 = {48'b0, Lv2_Res[WIDTH-1:48]};
`endif

logic [WIDTH+1:0] Lv3_Res;
logic Sticky_Lv3;

always_comb begin
    case (DIFF[5:4])
        2'b00: begin
            Lv3_Res = L3S0;
            Sticky_Lv3 = 1'b0;
        end
        2'b01: begin
            Lv3_Res = L3S16;
            Sticky_Lv3 = |Lv2_Res[15:0];
        end
`ifdef FP64
        2'b10: begin
            Lv3_Res = L3S32;
            Sticky_Lv3 = |Lv2_Res[31:0];
        end
        2'b11: begin
            Lv3_Res = L3S48;
            Sticky_Lv3 = |Lv2_Res[47:0];
        end
`endif
    endcase
end

// output port
logic Sticky = BigDiff ? 1'b1 : Sticky_Lv1 | Sticky_Lv2 | Sticky_Lv3;
assign OUT = {Lv3_Res, Sticky};

endmodule



module LZA_fp32 #(
    parameter WIDTH = 24
)(
    input logic [WIDTH-1:0] IN1,
    input logic [WIDTH-1:0] IN2,

    output logic [3:0] Shift_Num [2:0]
);

logic [WIDTH-1:0] f1 = IN1 ^ IN2;
logic [WIDTH-1:0] f2 = IN1 || (!IN2);
logic [WIDTH-1:0] f  = f1 & {f2[WIDTH-2:0], 1'b1};

// LV1: shift 16 / 0
logic [15:0] f_lv2;
always_comb begin
    if(|f[WIDTH-1 -: 16]) begin
        Shift_Num[2] = 4'b0001;
        f_lv2 = f[WIDTH-1 -: 16];
    end
    else begin
        Shift_Num[2] = 4'b0010;
        f_lv2 = {f[0 +: (WIDTH-16)], {(32-WIDTH){1'b0}}};
    end
end

// LV2: shift 12 / 8 / 4 / 0
logic [3:0] f_lv3;
always_comb begin
    if(|f_lv2[15:12]) begin
        Shift_Num[1] = 4'b0001;
        f_lv3 = f_lv2[15:12];
    end
    else if(|f_lv2[11:8]) begin
        Shift_Num[1] = 4'b0010;
        f_lv3 = f_lv2[11:8];
    end
    else if(|f_lv2[7:4]) begin
        Shift_Num[1] = 4'b0100;
        f_lv3 = f_lv2[7:4];
    end    
    else begin
        Shift_Num[1] = 4'b1000;
        f_lv3 = f_lv2[3:0];
    end
end

// LV3: shift 3 / 2 / 1 / 0
always_comb begin
    if(f_lv3[3]) begin
        Shift_Num[0] = 4'b0001;
    end
    else if(f_lv3[2]) begin
        Shift_Num[0] = 4'b0010;
    end
    else if(f_lv3[1]) begin
        Shift_Num[0] = 4'b0100;
    end    
    else begin
        Shift_Num[0] = 4'b1000;
    end
end

endmodule