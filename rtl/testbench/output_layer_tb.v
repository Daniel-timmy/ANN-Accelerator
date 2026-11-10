`timescale 1ns/1ps

module output_layer_tb;

    localparam INPUT_COUNT = 10;
    localparam DATA_WIDTH = 16;
    localparam ACC_WIDTH = 40;
    localparam OUTPUT_WIDTH = 16;
    localparam TEST_COUNT = 3;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg s_valid = 1'b0;
    wire s_ready;
    reg [INPUT_COUNT*DATA_WIDTH-1:0] s_data = 0;
    wire m_valid;
    reg m_ready = 1'b0;
    wire [OUTPUT_WIDTH-1:0] m_data;

    reg [DATA_WIDTH-1:0] input_samples [0:INPUT_COUNT-1];
    reg signed [DATA_WIDTH-1:0] reference_weights [0:INPUT_COUNT-1];
    reg signed [ACC_WIDTH-1:0] reference_biases [0:0];
    reg signed [ACC_WIDTH-1:0] reference_bias;
    reg signed [ACC_WIDTH-1:0] expected_sum;
    reg [OUTPUT_WIDTH-1:0] expected_output;
    reg signed [32:0] reference_product;
    reg signed [ACC_WIDTH-1:0] scaled_product;

    integer i;
    integer test_idx;
    integer sample_idx;

    always #5 clk = ~clk;

    output_layer dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data(m_data)
    );

    function [15:0] reference_sigmoid;
        input signed [39:0] x;
        reg [39:0] shifted;
        reg [4:0] segment;
        reg [7:0] fraction;
        reg [15:0] y0;
        reg [15:0] y1;
        reg [31:0] interpolation;
        begin
            if (x <= -40'sd524288) begin
                reference_sigmoid = 16'd0;
            end else if (x >= 40'sd524288) begin
                reference_sigmoid = 16'd65535;
            end else begin
                shifted = x + 40'sd524288;
                segment = shifted[20:16];
                fraction = shifted[15:8];

                case (segment)
                    5'd0:  begin y0 = 16'd22;    y1 = 16'd60;    end
                    5'd1:  begin y0 = 16'd60;    y1 = 16'd163;   end
                    5'd2:  begin y0 = 16'd163;   y1 = 16'd442;   end
                    5'd3:  begin y0 = 16'd442;   y1 = 16'd1179;  end
                    5'd4:  begin y0 = 16'd1179;  y1 = 16'd3116;  end
                    5'd5:  begin y0 = 16'd3116;  y1 = 16'd7817;  end
                    5'd6:  begin y0 = 16'd7817;  y1 = 16'd17625; end
                    5'd7:  begin y0 = 16'd17625; y1 = 16'd32768; end
                    5'd8:  begin y0 = 16'd32768; y1 = 16'd47910; end
                    5'd9:  begin y0 = 16'd47910; y1 = 16'd57718; end
                    5'd10: begin y0 = 16'd57718; y1 = 16'd62419; end
                    5'd11: begin y0 = 16'd62419; y1 = 16'd64356; end
                    5'd12: begin y0 = 16'd64356; y1 = 16'd65093; end
                    5'd13: begin y0 = 16'd65093; y1 = 16'd65372; end
                    5'd14: begin y0 = 16'd65372; y1 = 16'd65475; end
                    default: begin y0 = 16'd65475; y1 = 16'd65535; end
                endcase

                interpolation = y0 +
                    (((y1 - y0) * fraction) >> 8);
                reference_sigmoid = interpolation[15:0];
            end
        end
    endfunction

    initial begin
        $readmemh("C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/output_layer_weights.mem", reference_weights);
        $readmemh("C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/output_layer_bias.mem", reference_biases);

        #1;
        for (i = 0; i < INPUT_COUNT; i = i + 1) begin
            if ((^reference_weights[i]) === 1'bx)
                $fatal(1, "Missing or unknown weight at index %0d in output_layer_weights.mem", i);
            if (dut.weights[i] !== reference_weights[i])
                $fatal(1, "DUT/reference weight mismatch at index %0d", i);
        end

        if ((^reference_biases[0]) === 1'bx)
            $fatal(1, "Missing or unknown bias in output_layer_bias.mem");
        if (dut.biases[0] !== reference_biases[0])
            $fatal(1, "DUT/reference bias mismatch");
        reference_bias = reference_biases[0];

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        for (test_idx = 0; test_idx < TEST_COUNT; test_idx = test_idx + 1) begin
            for (sample_idx = 0; sample_idx < INPUT_COUNT; sample_idx = sample_idx + 1) begin
                case (test_idx)
                    0: input_samples[sample_idx] = 16'd1000 + (sample_idx * 16'd6500);
                    1: input_samples[sample_idx] = 16'd65535 - (sample_idx * 16'd5500);
                    default: input_samples[sample_idx] =
                        (sample_idx % 2) ? 16'd65535 : 16'd0;
                endcase
                s_data[(sample_idx*DATA_WIDTH) +: DATA_WIDTH] = input_samples[sample_idx];
            end

            expected_sum = reference_bias;
            for (sample_idx = 0; sample_idx < INPUT_COUNT; sample_idx = sample_idx + 1) begin
                reference_product = $signed({1'b0, input_samples[sample_idx]}) *
                    reference_weights[sample_idx];
                scaled_product =
                    $signed({{7{reference_product[32]}}, reference_product}) >>> 8;
                expected_sum = expected_sum + scaled_product;
            end
            expected_output = reference_sigmoid(expected_sum);

            @(negedge clk);
            s_valid = 1'b1;
            while (!s_ready)
                @(negedge clk);
            @(posedge clk);

            @(negedge clk);
            s_valid = 1'b0;
            if (!m_valid)
                $fatal(1, "Test vector %0d: output valid was not asserted", test_idx);
            if (dut.weighted_sum !== expected_sum)
                $fatal(1, "Test vector %0d MAC mismatch: expected %0d, got %0d",
                    test_idx, expected_sum, dut.weighted_sum);
            if (m_data !== expected_output)
                $fatal(1, "Test vector %0d output mismatch: expected %0d, got %0d",
                    test_idx, expected_output, m_data);
            if (s_ready)
                $fatal(1, "Test vector %0d: input ready should deassert while output is stalled",
                    test_idx);

            m_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            m_ready = 1'b0;
            if (m_valid || !s_ready)
                $fatal(1, "Test vector %0d: output handshake did not release the module",
                    test_idx);
        end

        $display("PASS: output_layer MAC sums and sigmoid outputs match the reference model");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Testbench timeout");
    end

endmodule
