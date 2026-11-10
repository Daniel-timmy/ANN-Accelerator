`timescale 1ns/1ps

module neuron_tb;

    localparam INPUT_COUNT = 20;
    localparam TEST_SET_COUNT = 5;
    localparam HIDDEN_COUNT = 10;
    localparam DATA_WIDTH = 16;
    localparam ACC_WIDTH = 40;
    localparam INPUT_FILE = "C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/X_test.mem";
    localparam LAYER1_WEIGHT_FILE = "C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/layer1_weights.mem";
    localparam LAYER1_BIAS_FILE = "C:/Users/user/OneDrive/Desktop/ANN Accelerator/rtl/testvectors/layer1_bias.mem";

    reg clk;
    reg rst_n;
    reg sample_valid;
    reg sample_first;
    reg sample_last;
    reg signed [DATA_WIDTH-1:0] data_in;
    reg signed [DATA_WIDTH-1:0] weight_in;
    reg signed [(2*DATA_WIDTH)-1:0] bias_in;
    wire signed [ACC_WIDTH-1:0] sum_out;
    wire sum_valid;

    reg signed [DATA_WIDTH-1:0] test_input_memory [0:TEST_SET_COUNT*INPUT_COUNT-1];
    reg signed [DATA_WIDTH-1:0] input_samples [0:INPUT_COUNT-1];
    reg signed [DATA_WIDTH-1:0] layer1_weights [0:INPUT_COUNT*HIDDEN_COUNT-1];
    reg signed [(2*DATA_WIDTH)-1:0] layer1_biases [0:HIDDEN_COUNT-1];

    integer i;
    integer frame_idx;
    integer sample_idx;
    integer neuron_idx;
    real decoded_sum;
    real decoded_product;

    neuron dut (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(sample_valid),
        .sample_first(sample_first),
        .sample_last(sample_last),
        .data_in(data_in),
        .weight_in(weight_in),
        .bias_in(bias_in),
        .sum_out(sum_out),
        .sum_valid(sum_valid)
    );

    always #5 clk = ~clk;

    function real decode_q16_16;
        input signed [39:0] encoded_value;
        begin
            decode_q16_16 =
                (($itor($signed(encoded_value[39:32])) * 4294967296.0) +
                 ($itor(encoded_value[31:16]) * 65536.0) +
                 $itor(encoded_value[15:0])) / 65536.0;
        end
    endfunction

    task send_sample;
        input first;
        input last;
        input signed [DATA_WIDTH-1:0] sample;
        input signed [DATA_WIDTH-1:0] weight;
        input signed [ACC_WIDTH-1:0] bias;
        begin
            @(negedge clk);
            sample_valid = 1'b1;
            sample_first = first;
            sample_last = last;
            data_in = sample;
            weight_in = weight;
            bias_in = bias;
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        sample_valid = 1'b0;
        sample_first = 1'b0;
        sample_last = 1'b0;
        data_in = 0;
        weight_in = 0;
        bias_in = 0;

        $readmemh(INPUT_FILE, test_input_memory);
        $readmemh(LAYER1_WEIGHT_FILE, layer1_weights);
        $readmemh(LAYER1_BIAS_FILE, layer1_biases);
        #1;

        for (i = 0; i < TEST_SET_COUNT*INPUT_COUNT; i = i + 1) begin
            if ((^test_input_memory[i]) === 1'bx)
                $fatal(1, "Missing or unknown test input at word index %0d in %s",
                    i, INPUT_FILE);
        end
        for (i = 0; i < INPUT_COUNT*HIDDEN_COUNT; i = i + 1) begin
            if ((^layer1_weights[i]) === 1'bx)
                $fatal(1, "Missing or unknown layer1 weight at index %0d", i);
        end
        for (i = 0; i < HIDDEN_COUNT; i = i + 1) begin
            if ((^layer1_biases[i]) === 1'bx)
                $fatal(1, "Missing or unknown layer1 bias at index %0d", i);
        end

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        for (frame_idx = 0; frame_idx < TEST_SET_COUNT; frame_idx = frame_idx + 1) begin
            for (sample_idx = 0; sample_idx < INPUT_COUNT; sample_idx = sample_idx + 1)
                input_samples[sample_idx] =
                    test_input_memory[(frame_idx*INPUT_COUNT) + sample_idx];

            $display("Test set %0d: neuron weighted sums", frame_idx);
            for (neuron_idx = 0; neuron_idx < HIDDEN_COUNT; neuron_idx = neuron_idx + 1) begin
                for (sample_idx = 0; sample_idx < INPUT_COUNT; sample_idx = sample_idx + 1) begin
                    send_sample(
                        sample_idx == 0,
                        sample_idx == INPUT_COUNT-1,
                        input_samples[sample_idx],
                        layer1_weights[(sample_idx*HIDDEN_COUNT) + neuron_idx],
                        layer1_biases[neuron_idx]
                    );
                    // decoded_product = decode_q16_16(dut.product_extended);
                    // $display("  Sent sample %0d to neuron %0d: data_in=%0d (0x%04h), weight_in=%0d (0x%04h), bias_in=%0d (0x%010h) Product: encoded=%0d (0x%010h) decoded=%0.6f",
                    //     sample_idx, neuron_idx,
                    //     input_samples[sample_idx], input_samples[sample_idx],
                    //     layer1_weights[(neuron_idx*INPUT_COUNT) + sample_idx],
                    //     layer1_weights[(neuron_idx*INPUT_COUNT) + sample_idx],
                    //     layer1_biases[neuron_idx], layer1_biases[neuron_idx],
                    //     dut.product_extended, dut.product_extended, decoded_product);
                end

                $display("Neuron %0d: bias_in=%0d (0x%010h), weighted sum before activation=%0d, decoded_weighted_sum=%0.6f",
                    neuron_idx, layer1_biases[neuron_idx], layer1_biases[neuron_idx],
                    sum_out, decode_q16_16(sum_out));

                if (sum_valid) begin
                    decoded_sum = decode_q16_16(sum_out);
                    
                    $display("  Neuron %0d weighted sum: encoded=%0d (0x%010h), decoded=%0.6f ",
                        neuron_idx, sum_out, sum_out, decoded_sum);
                end else begin
                    $fatal(1, "Neuron %0d did not assert sum_valid for test set %0d",
                        neuron_idx, frame_idx);
                end
            end
        end

        $display("Displayed encoded and decoded neuron sums for all %0d test sets.",
            TEST_SET_COUNT);
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Testbench timeout");
    end

endmodule
