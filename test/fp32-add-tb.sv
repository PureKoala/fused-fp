`include "../basic-design/fp-add.sv"
`include "../fused-design/define.sv"
`timescale 1ns/1ps

module fp32_adder_tb;

  // 定义时钟周期
  parameter CLK_PERIOD = 10;

  // 定义输入和输出信�???
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

  // 时钟生成�???
  always #CLK_PERIOD clk = ~clk;

  // 测试平台初始�???
  initial begin
    clk = 0;
    a = 0;
    b = 0;

    // 测试�???�???
    $dumpfile("fp32-add.vcd");
    $dumpvars(0, fp32_adder_tb);
    $display("Starting FP32 adder testbench...");

    // 正常浮点数测�???
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

    // 结束测试
    $display("FP32 adder testbench completed.");
    $finish;
  end

endmodule
