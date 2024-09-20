`define CONFIG_WIDTH 4

`define CONFIG_FP64 4'b0001
`define CONFIG_FP32 4'b0010
`define CONFIG_TF32 4'b0011
`define CONFIG_FP16 4'b0100
`define CONFIG_BF16 4'b0101
`define CONFIG_FP8_E4M3 4'b0110
`define CONFIG_FP8_E5M2 4'b0111

///////////////////////////////
`define ROUND_TYPE_WIDTH 3

`define ROUND_RTNE      3'b000 // round to nearest, ties to even
`define ROUND_RTNA      3'b001 // round to nearest, ties away from zero
`define ROUND_INWARD    3'b010 // round to zero
`define ROUND_UPWARD    3'b011 // round to +∞
`define ROUND_DOWNWARD  3'b100 // round to -∞