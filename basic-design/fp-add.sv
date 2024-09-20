`include "util.sv"
`include "../fused-design/define.sv"

module fp_add #(
    parameter FP_WIDTH      = 32,
    parameter EXP_WIDTH     = 8,
    parameter MAN_WIDTH     = 23
)(
    input logic [FP_WIDTH-1:0] IN1,
    input logic [FP_WIDTH-1:0] IN2,
    input logic [`ROUND_TYPE_WIDTH-1:0] ROUND_TYPE,

    output logic [FP_WIDTH-1:0] OUT
);

wire                 IN1_SIG = IN1[FP_WIDTH-1];
wire [EXP_WIDTH-1:0] IN1_EXP = IN1[EXP_WIDTH+MAN_WIDTH-1:MAN_WIDTH];
wire [MAN_WIDTH:0]   IN1_MAN = {1'b1, IN1[MAN_WIDTH-1:0]};

wire                 IN2_SIG = IN2[FP_WIDTH-1];
wire [EXP_WIDTH-1:0] IN2_EXP = IN2[EXP_WIDTH+MAN_WIDTH-1:MAN_WIDTH];
wire [MAN_WIDTH:0]   IN2_MAN = {1'b1, IN2[MAN_WIDTH-1:0]};

wire               IN_EXP_CMP = IN1_EXP >= IN2_EXP;
wire [EXP_WIDTH:0] IN_EXP_SUB_pre = {1'b0, IN1_EXP} + ~{1'b0, IN2_EXP};
wire [EXP_WIDTH:0] IN_EXP_SUB_12 = IN_EXP_SUB_pre + 'b1;
wire [EXP_WIDTH:0] IN_EXP_SUB_21 = ~IN_EXP_SUB_pre;

// wire [MAN_WIDTH+1:0] MAN_DIFF   = {1'b0, IN1_MAN} + ~{1'b0, IN2_MAN} + 'b1;
wire [EXP_WIDTH-1:0] EXP_DIFF   = IN_EXP_CMP ? IN_EXP_SUB_12[EXP_WIDTH-1:0] : IN_EXP_SUB_21[EXP_WIDTH-1:0];
wire                IN1_Larger  = IN_EXP_CMP;
wire                Larger_SIG  = IN1_Larger ? IN1_SIG : IN2_SIG;
wire [EXP_WIDTH-1:0] Larger_EXP = IN1_Larger ? IN1_EXP : IN2_EXP;
wire [MAN_WIDTH:0]  Larger_MAN  = IN1_Larger ? IN1_MAN : IN2_MAN;
wire [MAN_WIDTH:0]  Smaller_MAN = IN1_Larger ? IN2_MAN : IN1_MAN;

///////// far path
logic [MAN_WIDTH+3:0] Shifted_Small;
Shifter shifter(.IN(Smaller_MAN), .DIFF(EXP_DIFF), .OUT(Shifted_Small));

wire [MAN_WIDTH+4:0] Far_Res_Pre = (IN1_SIG ^ IN2_SIG 
                                        ? ({1'b1, ~Shifted_Small[MAN_WIDTH+3:3], Shifted_Small[2:0]} + 4'b1000) 
                                        : {1'b0, Shifted_Small}) 
                                    + {1'b0, Larger_MAN, 3'b0};

// round control {
logic choose_plus_1;
logic [MAN_WIDTH:0] Far_MAN;
logic [EXP_WIDTH:0] Far_EXP;
always_comb begin
    case(ROUND_TYPE)
        `ROUND_RTNE: begin
            choose_plus_1 = Far_Res_Pre[2] && (Far_Res_Pre[1] || Far_Res_Pre[0] || Far_Res_Pre[3]);
        end
        `ROUND_RTNA: begin
            choose_plus_1 = Far_Res_Pre[2];
        end
        `ROUND_UPWARD: begin
            choose_plus_1 = |Far_Res_Pre[2:0] && Larger_SIG; 
        end
        `ROUND_DOWNWARD: begin
            choose_plus_1 = |Far_Res_Pre[2:0] && !Larger_SIG; 
        end
        default: begin
            choose_plus_1 = 1'b0;
        end
    endcase
end
assign Far_MAN = (Far_Res_Pre[MAN_WIDTH+4] ? Far_Res_Pre[MAN_WIDTH+4:4] : (Far_Res_Pre[MAN_WIDTH+3] ? Far_Res_Pre[MAN_WIDTH+3:3] : Far_Res_Pre[MAN_WIDTH+2:2])) + choose_plus_1;
assign Far_EXP = {1'b0, Larger_EXP} 
                + Far_Res_Pre[MAN_WIDTH+4] 
                - (Far_Res_Pre[MAN_WIDTH+4] || Far_Res_Pre[MAN_WIDTH+3] ? 1'b0 : 1'b1); // +1 calculate
// }


///////// near path
wire [MAN_WIDTH+1:0] Y = |EXP_DIFF ? {1'b0, Smaller_MAN} : {Smaller_MAN, 1'b0} ;
wire [MAN_WIDTH+2:0] nY= ~{1'b0, Y};

wire [MAN_WIDTH+2:0] Sub_Res = {1'b0, Larger_MAN, 1'b0} + nY + 'b1;

logic [3:0] Shift_Num [2:0];
LZA_fp32 #(25) lza(.IN1({Larger_MAN, 1'b0}), .IN2(Y), .Shift_Num(Shift_Num));

// Level shifter
logic [MAN_WIDTH+1:0] Shifted_Near [2:0];
logic [EXP_WIDTH-1:0] EXP_ADJUST [2:0];
always_comb begin
    case(Shift_Num[2])
        4'b0001: begin
            Shifted_Near[2] = Sub_Res[MAN_WIDTH+1:0];
            EXP_ADJUST[2] = 'd0;
        end
        default: begin
            Shifted_Near[2] = {Sub_Res[MAN_WIDTH-15:0], 16'b0};
            EXP_ADJUST[2] = 'd16;
        end
    endcase
end

always_comb begin
    case(Shift_Num[1])
        4'b0001: begin
            Shifted_Near[1] = Shifted_Near[2];
            EXP_ADJUST[1] = 'd0;
        end
        4'b0010: begin
            Shifted_Near[1] = {Shifted_Near[2][MAN_WIDTH-3:0], 4'b0};
            EXP_ADJUST[1] = 'd4;
        end
        4'b0100: begin
            Shifted_Near[1] = {Shifted_Near[2][MAN_WIDTH-7:0], 8'b0};
            EXP_ADJUST[1] = 'd8;
        end
        4'b1000: begin
            Shifted_Near[1] = {Shifted_Near[2][MAN_WIDTH-11:0], 12'b0};
            EXP_ADJUST[1] = 'd12;
        end
    endcase
end

always_comb begin
    case(Shift_Num[0])
        4'b0001: begin
            Shifted_Near[0] = Shifted_Near[1];
            EXP_ADJUST[0] = 'd0;
        end
        4'b0010: begin
            Shifted_Near[0] = {Shifted_Near[1][MAN_WIDTH:0], 1'b0};
            EXP_ADJUST[0] = 'd1;
        end
        4'b0100: begin
            Shifted_Near[0] = {Shifted_Near[1][MAN_WIDTH-1:0], 2'b0};
            EXP_ADJUST[0] = 'd2;
        end
        4'b1000: begin
            Shifted_Near[0] = {Shifted_Near[1][MAN_WIDTH-2:0], 3'b0};
            EXP_ADJUST[0] = 'd3;
        end
    endcase
end

wire [MAN_WIDTH:0] Near_MAN = Shifted_Near[0][MAN_WIDTH+1] ? Shifted_Near[0][MAN_WIDTH+1:1] : Shifted_Near[0][MAN_WIDTH:0];
wire [EXP_WIDTH:0] Near_EXP = {1'b0, Larger_EXP} 
                                    + ~(EXP_ADJUST[2] + EXP_ADJUST[1] + EXP_ADJUST[0]) 
                                    // + 'd1
                                    + Shifted_Near[0][MAN_WIDTH+1];


////////// final result choose
// $assert(Near_MAN[MAN_WIDTH]);
// $assert(Fear_MAN[MAN_WIDTH]);

wire choose_near = (IN1_SIG ^ IN2_SIG) && ~(|EXP_DIFF[EXP_WIDTH-1:1]);
wire [MAN_WIDTH:0] Res_MAN = choose_near ? Near_MAN : Far_MAN;
wire [EXP_WIDTH-1:0] Res_EXP = choose_near ? Near_EXP[EXP_WIDTH-1:0] : Far_EXP[EXP_WIDTH-1:0];

assign OUT = {Larger_SIG, Res_EXP, Res_MAN[MAN_WIDTH-1:0]};
endmodule