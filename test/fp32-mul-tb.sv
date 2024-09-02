// `include "../basic-design/fp-mul.sv"
`timescale 1ns/1ps

module fp32_multiplier_tb;

  // 定义时钟周期
  parameter CLK_PERIOD = 10;

  // 定义输入和输出信号
  reg clk;
  reg [31:0] a;
  reg [31:0] b;
  wire [31:0] product;

  // 实例化乘法器模块
  fp_mul uut (
    // .clk(clk),
    .IN1(a),
    .IN2(b),
    .OUT(product)
  );

  // 时钟生成器
  always #CLK_PERIOD clk = ~clk;

  // 测试平台初始化
  initial begin
    clk = 0;
    a = 0;
    b = 0;

    // 测试开始
    $dumpfile("fp32-mul.vcd");
    $dumpvars(0, fp32_multiplier_tb);
    $display("Starting FP32 multiplier testbench...");

    // 正常浮点数测试
    a = 32'h3F800000; // 1.0
    b = 32'h40400000; // 2.0
    #CLK_PERIOD;
    if (product !== 32'h40800000) begin // 2.0
      $display("FAILED: 1.0 * 2.0 != 2.0");
    end else begin
      $display("PASSED: 1.0 * 2.0 == 2.0");
    end

    a = 32'h40400000; // 2.0
    b = 32'h3F800000; // 1.0
    #CLK_PERIOD;
    if (product !== 32'h40800000) begin // 2.0
      $display("FAILED: 2.0 * 1.0 != 2.0");
    end else begin
      $display("PASSED: 2.0 * 1.0 == 2.0");
    end

    a = 32'h40400000; // 2.0
    b = 32'h40400000; // 2.0
    #CLK_PERIOD;
    if (product !== 32'h40C00000) begin // 4.0
      $display("FAILED: 2.0 * 2.0 != 4.0");
    end else begin
      $display("PASSED: 2.0 * 2.0 == 4.0");
    end

    a = 32'h3F800000; // 1.0
    b = 32'hBF800000; // -1.0
    #CLK_PERIOD;
    if (product !== 32'hBF800000) begin // -1.0
      $display("FAILED: 1.0 * -1.0 != -1.0");
    end else begin
      $display("PASSED: 1.0 * -1.0 == -1.0");
    end

    a = 32'h40400000; // 2.0
    b = 32'hBF800000; // -1.0
    #CLK_PERIOD;
    if (product !== 32'hBF800000) begin // -2.0
      $display("FAILED: 2.0 * -1.0 != -2.0");
    end else begin
      $display("PASSED: 2.0 * -1.0 == -2.0");
    end

    // 结束测试
    $display("FP32 multiplier testbench completed.");
    $finish;
  end

endmodule
