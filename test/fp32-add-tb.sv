`include "../basic-design/fp-add.sv"
`include "../fused-design/define.sv"
`timescale 1ns/1ps

module fp32_adder_tb;

  // 定义时钟周期
  parameter CLK_PERIOD = 10;

  // 定义输入和输出信�????
  reg clk;
  reg [31:0] a;
  reg [31:0] b;
  wire [31:0] product;

  // 实例化乘法器模块
  fp_add uut (
    // .clk(clk),
    .IN1(a),
    .IN2(b),
    .ROUND_TYPE(`ROUND_RTNE),
    .OUT(product)
  );

  // 时钟生成�????
  always #CLK_PERIOD clk = ~clk;

  // 测试平台初始�????
  initial begin
    clk = 0;
    a = 0;
    b = 0;

    // 测试�????�????
    $dumpfile("fp32-add.vcd");
    $dumpvars(0, fp32_adder_tb);
    $display("Starting FP32 adder testbench...");

    // 正常浮点数测�????
    a = 32'hBF91EB85; // -1.14
    b = 32'h75CABCBD; // 5.14e32
    #CLK_PERIOD;
    if (product !== 32'h75CABCBD) begin // 5.14e32
      $display("FAILED: -1.14 + 5.14e32 != 5.14e32");
    end else begin
      $display("PASSED: -1.14 + 5.14e32 == 5.14e32");
    end
    
    a = 32'h3FC00000; // 1.5
    b = 32'h3FC00000; // 1.5
    #CLK_PERIOD;
    if (product !== 32'h40400000) begin // 3.0
      $display("FAILED: 1.5 + 1.5 != 3.0");
    end else begin
      $display("PASSED: 1.5 + 1.5 == 3.0");
    end

    a = 32'h40000000; // 2.0
    b = 32'h3F800000; // 1.0
    #CLK_PERIOD;
    if (product !== 32'h40400000) begin // 3.0
      $display("FAILED: 2.0 + 1.0 != 3.0");
    end else begin
      $display("PASSED: 2.0 + 1.0 == 3.0");
    end

    a = 32'h40000000; // 2.0
    b = 32'h40000000; // 2.0
    #CLK_PERIOD;
    if (product !== 32'h40800000) begin // 4.0
      $display("FAILED: 2.0 + 2.0 != 4.0");
    end else begin
      $display("PASSED: 2.0 + 2.0 == 4.0");
    end

    // a = 32'h3F800000; // 1.0
    // b = 32'hBF800000; // -1.0
    // #CLK_PERIOD;
    // if (product !== 32'h2F800000) begin // 0.0
    //   $display("FAILED: 1.0 * -1.0 != 0.0");
    // end else begin
    //   $display("PASSED: 1.0 * -1.0 == 0.0");
    // end

    a = 32'h40000000; // 2.0
    b = 32'hBF800000; // -1.0
    #CLK_PERIOD;
    if (product !== 32'h3F800000) begin // 1.0
      $display("FAILED: 2.0 + -1.0 != 1.0");
    end else begin
      $display("PASSED: 2.0 + -1.0 == 1.0");
    end
    
    a = 32'h3ed00000; // 0.40625
b = 32'h40200000; // 2.5
#CLK_PERIOD;
if (product !== 32'h403a0000) begin // 2.90625
$display("FAILED: 0.40625 + 2.5 != 2.90625");
end else begin
$display("PASSED: 0.40625 + 2.5 == 2.90625");
end
a = 32'h40200000; // 2.5
b = 32'h3ed00000; // 0.40625
#CLK_PERIOD;
if (product !== 32'h403a0000) begin // 2.90625
$display("FAILED: 2.5 + 0.40625 != 2.90625");
end else begin
$display("PASSED: 2.5 + 0.40625 == 2.90625");
end
a = 32'h46900000; // 18432.0
b = 32'h48700000; // 245760.0
#CLK_PERIOD;
if (product !== 32'h48810000) begin // 264192.0
$display("FAILED: 18432.0 + 245760.0 != 264192.0");
end else begin
$display("PASSED: 18432.0 + 245760.0 == 264192.0");
end
a = 32'h48700000; // 245760.0
b = 32'h46900000; // 18432.0
#CLK_PERIOD;
if (product !== 32'h48810000) begin // 264192.0
$display("FAILED: 245760.0 + 18432.0 != 264192.0");
end else begin
$display("PASSED: 245760.0 + 18432.0 == 264192.0");
end
a = 32'hbeb00000; // -0.34375
b = 32'h40000000; // 2.0
#CLK_PERIOD;
if (product !== 32'h3fd40000) begin // 1.65625
$display("FAILED: -0.34375 + 2.0 != 1.65625");
end else begin
$display("PASSED: -0.34375 + 2.0 == 1.65625");
end
a = 32'h40000000; // 2.0
b = 32'hbeb00000; // -0.34375
#CLK_PERIOD;
if (product !== 32'h3fd40000) begin // 1.65625
$display("FAILED: 2.0 + -0.34375 != 1.65625");
end else begin
$display("PASSED: 2.0 + -0.34375 == 1.65625");
end
a = 32'hbdf00000; // -0.1171875
b = 32'h3f900000; // 1.125
#CLK_PERIOD;
if (product !== 32'h3f810000) begin // 1.0078125
$display("FAILED: -0.1171875 + 1.125 != 1.0078125");
end else begin
$display("PASSED: -0.1171875 + 1.125 == 1.0078125");
end
a = 32'h3f900000; // 1.125
b = 32'hbdf00000; // -0.1171875
#CLK_PERIOD;
if (product !== 32'h3f810000) begin // 1.0078125
$display("FAILED: 1.125 + -0.1171875 != 1.0078125");
end else begin
$display("PASSED: 1.125 + -0.1171875 == 1.0078125");
end
a = 32'hbfe00000; // -1.75
b = 32'h3ff00000; // 1.875
#CLK_PERIOD;
if (product !== 32'h3e000000) begin // 0.125
$display("FAILED: -1.75 + 1.875 != 0.125");
end else begin
$display("PASSED: -1.75 + 1.875 == 0.125");
end
a = 32'h3ff00000; // 1.875
b = 32'hbfe00000; // -1.75
#CLK_PERIOD;
if (product !== 32'h3e000000) begin // 0.125
$display("FAILED: 1.875 + -1.75 != 0.125");
end else begin
$display("PASSED: 1.875 + -1.75 == 0.125");
end
a = 32'hbf700000; // -0.9375
b = 32'h3f800000; // 1.0
#CLK_PERIOD;
if (product !== 32'h3d800000) begin // 0.0625
$display("FAILED: -0.9375 + 1.0 != 0.0625");
end else begin
$display("PASSED: -0.9375 + 1.0 == 0.0625");
end
a = 32'h3f800000; // 1.0
b = 32'hbf700000; // -0.9375
#CLK_PERIOD;
if (product !== 32'h3d800000) begin // 0.0625
$display("FAILED: 1.0 + -0.9375 == 0.0625");
end else begin
$display("PASSED: 1.0 + -0.9375 == 0.0625");
end
a = 32'hbf100000; // -0.5625
b = 32'h3fd00000; // 1.625
#CLK_PERIOD;
if (product !== 32'h3f880000) begin // 1.0625
$display("FAILED: -0.5625 + 1.625 != 1.0625");
end else begin
$display("PASSED: -0.5625 + 1.625 == 1.0625");
end
a = 32'h3fd00000; // 1.625
b = 32'hbf100000; // -0.5625
#CLK_PERIOD;
if (product !== 32'h3f880000) begin // 1.0625
$display("FAILED: 1.625 + -0.5625 != 1.0625");
end else begin
$display("PASSED: 1.625 + -0.5625 == 1.0625");
end
a = 32'hbfa00000; // -1.25
b = 32'h3f800000; // 1.0
#CLK_PERIOD;
if (product !== 32'hbe800000) begin // -0.25
$display("FAILED: -1.25 + 1.0 != -0.25");
end else begin
$display("PASSED: -1.25 + 1.0 == -0.25");
end
a = 32'h3f800000; // 1.0
b = 32'hbfa00000; // -1.25
#CLK_PERIOD;
if (product !== 32'hbe800000) begin // -0.25
$display("FAILED: 1.0 + -1.25 != -0.25");
end else begin
$display("PASSED: 1.0 + -1.25 == -0.25");
end


    // 结束测试
    $display("FP32 adder testbench completed.");
    $finish;
  end

endmodule
