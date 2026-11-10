`timescale 1ns/1ps

module ann_processor_real_data_tb;

    localparam INPUT_COUNT = 20;
    localparam TEST_SET_COUNT = 500;
    localparam HIDDEN_COUNT = 10;
    localparam DATA_WIDTH = 16;
    localparam ACC_WIDTH = 40;
    localparam BIAS_WIDTH = 32;
    localparam OUTPUT_WIDTH = 16;
    localparam INPUT_FILE = "C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/X_test.mem";
    localparam LABEL_FILE = "C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/y_test.mem";
    localparam LAYER1_WEIGHT_FILE = "C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/layer1_weights.mem";
    localparam LAYER1_BIAS_FILE = "C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/layer1_bias.mem";
    localparam OUTPUT_WEIGHT_FILE = "C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/output_layer_weights.mem";
    localparam OUTPUT_BIAS_FILE = "C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/output_layer_bias.mem";

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg s_valid = 1'b0;
    wire s_ready;
    reg signed [DATA_WIDTH-1:0] s_data = 0;
    wire m_valid;
    reg m_ready = 1'b0;
    wire [OUTPUT_WIDTH-1:0] m_data;

    reg signed [DATA_WIDTH-1:0] test_input_memory [0:TEST_SET_COUNT*INPUT_COUNT-1];
    reg signed [DATA_WIDTH-1:0] test_label_memory [0:TEST_SET_COUNT-1];
    reg signed [DATA_WIDTH-1:0] input_samples [0:INPUT_COUNT-1];
    reg signed [DATA_WIDTH-1:0] reference_layer1_weights [0:INPUT_COUNT*HIDDEN_COUNT-1];
    reg signed [BIAS_WIDTH-1:0] reference_layer1_biases [0:HIDDEN_COUNT-1];
    reg signed [DATA_WIDTH-1:0] reference_output_weights [0:HIDDEN_COUNT-1];
    reg signed [BIAS_WIDTH-1:0] reference_output_biases [0:0];
    reg [615:0] expected_network;
    integer i;
    integer frame_idx;
    integer sample_idx;
    integer predicted_class;
    integer actual_class;
    integer passed_count;
    real decoded_output;
    real decoded_label;

    always #5 clk = ~clk;

    ann_processor #(
        .LAYER1_WEIGHT_FILE(LAYER1_WEIGHT_FILE),
        .LAYER1_BIAS_FILE(LAYER1_BIAS_FILE),
        .OUTPUT_WEIGHT_FILE(OUTPUT_WEIGHT_FILE),
        .OUTPUT_BIAS_FILE(OUTPUT_BIAS_FILE)
    ) dut (
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

    function [615:0] reference_network;
        input integer unused;
        reg signed [39:0] accumulator;
        reg signed [31:0] layer1_product;
        reg signed [32:0] output_product;
        reg signed [39:0] scaled_output_product;
        integer neuron_idx;
        integer sample_idx;
        begin
            reference_network = 616'd0;

            for (neuron_idx = 0; neuron_idx < HIDDEN_COUNT; neuron_idx = neuron_idx + 1) begin
                accumulator = reference_layer1_biases[neuron_idx];
                for (sample_idx = 0; sample_idx < INPUT_COUNT; sample_idx = sample_idx + 1) begin
                    layer1_product = input_samples[sample_idx] *
                        reference_layer1_weights[(sample_idx*HIDDEN_COUNT) + neuron_idx];
                    accumulator = accumulator +
                        {{8{layer1_product[31]}}, layer1_product};
                end
                reference_network[(216 + neuron_idx*ACC_WIDTH) +: ACC_WIDTH] =
                    accumulator;
                reference_network[(neuron_idx*OUTPUT_WIDTH) +: OUTPUT_WIDTH] =
                    reference_sigmoid(accumulator);
            end

            accumulator = reference_output_biases[0];
            for (neuron_idx = 0; neuron_idx < HIDDEN_COUNT; neuron_idx = neuron_idx + 1) begin
                output_product =
                    $signed({1'b0, reference_network[(neuron_idx*OUTPUT_WIDTH) +: OUTPUT_WIDTH]}) *
                    reference_output_weights[neuron_idx];
                scaled_output_product =
                    $signed({{7{output_product[32]}}, output_product}) >>> 8;
                accumulator = accumulator + scaled_output_product;
            end
            reference_network[175:160] = reference_sigmoid(accumulator);
            reference_network[215:176] = accumulator;
        end
    endfunction

    initial begin
        $readmemh(LAYER1_WEIGHT_FILE, reference_layer1_weights);
        $readmemh(LAYER1_BIAS_FILE, reference_layer1_biases);
        $readmemh(OUTPUT_WEIGHT_FILE, reference_output_weights);
        $readmemh(OUTPUT_BIAS_FILE, reference_output_biases);
        $readmemh(INPUT_FILE, test_input_memory);
        $readmemh(LABEL_FILE, test_label_memory);
        #1;
        for (i = 0; i < TEST_SET_COUNT*INPUT_COUNT; i = i + 1) begin
            if ((^test_input_memory[i]) === 1'bx)
                $fatal(1, "Missing or unknown test input at word index %0d in %s",
                    i, INPUT_FILE);
        end
        for (i = 0; i < TEST_SET_COUNT; i = i + 1) begin
            if ((^test_label_memory[i]) === 1'bx)
                $fatal(1, "Missing or unknown test label at index %0d in %s",
                    i, LABEL_FILE);
        end
        for (i = 0; i < INPUT_COUNT*HIDDEN_COUNT; i = i + 1) begin
            if ((^reference_layer1_weights[i]) === 1'bx)
                $fatal(1, "Missing or unknown layer1 weight at index %0d", i);
        end
        for (i = 0; i < HIDDEN_COUNT; i = i + 1) begin
            if ((^reference_layer1_biases[i]) === 1'bx)
                $fatal(1, "Missing or unknown layer1 bias at index %0d", i);

            if ((^reference_output_weights[i]) === 1'bx)
                $fatal(1, "Missing or unknown output-layer weight at index %0d", i);
        end
        if ((^reference_output_biases[0]) === 1'bx)
            $fatal(1, "Missing or unknown output-layer bias");

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        passed_count = 0;

        for (frame_idx = 0; frame_idx < TEST_SET_COUNT; frame_idx = frame_idx + 1) begin
            for (sample_idx = 0; sample_idx < INPUT_COUNT; sample_idx = sample_idx + 1)
                input_samples[sample_idx] =
                    test_input_memory[(frame_idx*INPUT_COUNT) + sample_idx];

            expected_network = reference_network(0);

            for (sample_idx = 0; sample_idx < INPUT_COUNT; sample_idx = sample_idx + 1) begin
                @(negedge clk);
                s_valid = 1'b1;
                s_data = input_samples[sample_idx];
                while (!s_ready)
                    @(negedge clk);
                @(posedge clk);
            end

            @(negedge clk);
            s_valid = 1'b0;

            wait (m_valid);
            if (m_data !== expected_network[175:160])
                $fatal(1, "Test set %0d output mismatch: DUT=%0d, TB=%0d",
                    frame_idx, m_data, expected_network[175:160]);

            decoded_output = $itor(m_data) / 65536.0;
            decoded_label = $itor(test_label_memory[frame_idx]) / 256.0;
            predicted_class = (decoded_output < 0.7) ? 0 : 1;
            actual_class = (decoded_label < 0.5) ? 0 : 1;

            if (predicted_class != actual_class) begin
                $display("FAILED test set %0d: predicted=%0d, actual=%0d",
                    frame_idx, predicted_class, actual_class);
                $write("  Input Q8.8 (raw/decoded):");
                for (i = 0; i < INPUT_COUNT; i = i + 1)
                    $write(" %0d/%0.4f",
                        input_samples[i], $itor(input_samples[i]) / 256.0);
                $display("");
                $display("  DUT output: encoded=%0d (0x%04h), decoded=%0.6f, class=%0d",
                    m_data, m_data, decoded_output, predicted_class);
                $display("  y_test: encoded=%0d (0x%04h), decoded=%0.6f, class=%0d",
                    test_label_memory[frame_idx], test_label_memory[frame_idx],
                    decoded_label, actual_class);
            end else begin
                passed_count = passed_count + 1;
            end

            @(negedge clk);
            m_ready = 1'b1;
            while (m_valid !== 1'b0)
                @(negedge clk);
            m_ready = 1'b0;
        end

        $display("Passed %0d of %0d test sets.", passed_count, TEST_SET_COUNT);
        $finish;
    end

    initial begin
        #(TEST_SET_COUNT * (INPUT_COUNT + 5) * 10);
        $fatal(1, "Testbench timeout");
    end

endmodule
