`timescale 1ns/1ps

module layer1_tb;

    localparam INPUT_COUNT = 20;
    localparam NEURON_COUNT = 10;
    localparam DATA_WIDTH = 16;
    localparam ACC_WIDTH = 40;
    localparam OUTPUT_WIDTH = 16;
    localparam TEST_SET_COUNT = 5;
    localparam INPUT_FILE = "C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/X_test.mem";
    localparam LAYER1_WEIGHT_FILE = "C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/layer1_weights.mem";
    localparam LAYER1_BIAS_FILE = "C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/layer1_bias.mem";

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg s_valid = 1'b0;
    wire s_ready;
    reg signed [DATA_WIDTH-1:0] s_data = 0;
    wire m_valid;
    reg m_ready = 1'b0;
    wire [NEURON_COUNT*OUTPUT_WIDTH-1:0] m_data;


    reg signed [DATA_WIDTH-1:0] input_samples [0:TEST_SET_COUNT*INPUT_COUNT-1];
    reg signed [DATA_WIDTH-1:0] reference_weights [0:INPUT_COUNT*NEURON_COUNT-1];
    reg signed [(2*DATA_WIDTH)-1:0] reference_biases [0:NEURON_COUNT-1];
    reg signed [ACC_WIDTH-1:0] expected_sum [0:NEURON_COUNT-1];
    reg [OUTPUT_WIDTH-1:0] expected_output [0:NEURON_COUNT-1];
    reg signed [31:0] product;

    integer i;
    integer neuron_idx;
    integer sample_idx;
    integer test_set_idx;

    always #5 clk = ~clk;

    layer1 dut (
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

    function real decode_q16_16;
        input signed [39:0] encoded_value;
        begin
            decode_q16_16 =
                (($itor($signed(encoded_value[39:32])) * 4294967296.0) +
                 ($itor(encoded_value[31:16]) * 65536.0) +
                 $itor(encoded_value[15:0])) / 65536.0;
        end
    endfunction

    initial begin
    
        $readmemh(INPUT_FILE, input_samples);
        $readmemh(LAYER1_WEIGHT_FILE, reference_weights);
        $readmemh(LAYER1_BIAS_FILE, reference_biases);

        for (i = 0; i < TEST_SET_COUNT*INPUT_COUNT; i = i + 1) begin
                if ((^input_samples[i]) === 1'bx)
                    $fatal(1, "Missing or unknown test input at word index %0d in %s",
                        i, INPUT_FILE);
        end
        
        #1;
        for (i = 0; i < INPUT_COUNT*NEURON_COUNT; i = i + 1) begin
            if ((^reference_weights[i]) === 1'bx)
                $fatal(1, "Missing or unknown weight at index %0d in layer1_weights.mem", i);
            if (dut.weights[i] !== reference_weights[i])
                $fatal(1, "DUT/reference weight mismatch at index %0d", i);
        end

        for (i = 0; i < NEURON_COUNT; i = i + 1) begin
            if ((^reference_biases[i]) === 1'bx)
                $fatal(1, "Missing or unknown bias at index %0d in layer1_bias.mem", i);
            if (dut.biases[i] !== reference_biases[i])
                $fatal(1, "DUT/reference bias mismatch at index %0d", i);
        end

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        for (test_set_idx = 0; test_set_idx < TEST_SET_COUNT;
             test_set_idx = test_set_idx + 1) begin
            for (neuron_idx = 0; neuron_idx < NEURON_COUNT; neuron_idx = neuron_idx + 1) begin
                expected_sum[neuron_idx] = reference_biases[neuron_idx];
                for (sample_idx = 0; sample_idx < INPUT_COUNT; sample_idx = sample_idx + 1) begin
                    product = input_samples[(test_set_idx*INPUT_COUNT) + sample_idx] *
                        reference_weights[(sample_idx*NEURON_COUNT) + neuron_idx];
                    expected_sum[neuron_idx] = expected_sum[neuron_idx] +
                        {{8{product[31]}}, product};
                end
                expected_output[neuron_idx] = reference_sigmoid(expected_sum[neuron_idx]);
            end

            for (i = 0; i < INPUT_COUNT; i = i + 1) begin
                @(negedge clk);
                s_valid = 1'b1;
                s_data = input_samples[(test_set_idx*INPUT_COUNT) + i];
                while (!s_ready)
                    @(negedge clk);
                @(posedge clk);
            end

            @(negedge clk);
            s_valid = 1'b0;

            wait (m_valid);
            for (neuron_idx = 0; neuron_idx < NEURON_COUNT; neuron_idx = neuron_idx + 1) begin
                if (dut.neuron_sum[neuron_idx] !== expected_sum[neuron_idx])
                    $fatal(1, "Test set %0d neuron %0d MAC mismatch: expected %0d, got %0d",
                        test_set_idx, neuron_idx, expected_sum[neuron_idx], dut.neuron_sum[neuron_idx]);
                if (m_data[(neuron_idx*OUTPUT_WIDTH) +: OUTPUT_WIDTH] !== expected_output[neuron_idx])
                    $fatal(1, "Test set %0d neuron %0d output mismatch: expected %0d, got %0d",
                        test_set_idx, neuron_idx, expected_output[neuron_idx],
                        m_data[(neuron_idx*OUTPUT_WIDTH) +: OUTPUT_WIDTH]);
                $display("Test set %0d, neuron %0d output: %0d (Q0.16 = %0.6f)",
                    test_set_idx, neuron_idx,
                    m_data[(neuron_idx*OUTPUT_WIDTH) +: OUTPUT_WIDTH],
                    $itor(m_data[(neuron_idx*OUTPUT_WIDTH) +: OUTPUT_WIDTH]) / 65536.0);
            end

            @(negedge clk);
            m_ready = 1'b1;
            @(posedge clk);
            @(negedge clk);
            if (m_valid !== 1'b0)
                $fatal(1, "Output valid did not clear after handshake");
            m_ready = 1'b0;
        end

        $display("PASS: layer1 MAC sums and sigmoid outputs match all %0d test sets",
            TEST_SET_COUNT);
        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "Testbench timeout");
    end

endmodule
