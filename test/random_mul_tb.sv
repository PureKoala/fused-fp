`timescale 1ns / 1ps

module tb_fp32_multiplier;

    // 输入和输出
    reg [31:0] a, b;
    wire [31:0] product;
    real a_real, b_real, product_real, expected_product;

    // 实例化乘法器模块
    fp32_multiplier uut (
        .a(a),
        .b(b),
        .product(product)
    );

    // 任务：将FP32转换为real
    task fp32_to_real(input [31:0] fp32, output real r);
        r = $bitstoshortreal(fp32);
    endtask

    // 任务：将real转换为FP32
    task real_to_fp32(input real r, output [31:0] fp32);
        fp32 = $realtobits(r);
    endtask

    // 测试过程
    initial begin
        // 初始化随机数种子
        $urandom(seed);

        // 测试循环
        repeat (1000) begin
            // 随机生成两个FP32数
            a = $urandom();
            b = $urandom();

            // 将FP32转换为real进行乘法
            fp32_to_real(a, a_real);
            fp32_to_real(b, b_real);
            expected_product = a_real * b_real;

            // 将预期结果转换为FP32
            real_to_fp32(expected_product, expected_product);

            // 等待乘法器完成计算
            #10;

            // 检查结果是否匹配（允许一定的误差）
            if (product !== expected_product && ($bitstoreal(product) - expected_product) > 1e-6) begin
                $display("Mismatch found: a=%h, b=%h, expected=%h, got=%h", a, b, expected_product, product);
                $finish;
            end
        end

        $display("All tests passed successfully.");
        $finish;
    end

endmodule
