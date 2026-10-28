module layer1 #(
    parameter WEIGHT_FILE = "layer1_weights.mem",
    parameter BIAS_FILE = "layer1_bias.mem"
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         s_valid,
    output wire         s_ready,
    input  wire signed [15:0] s_data,
    output reg          m_valid,
    input  wire         m_ready,
    output reg  [159:0] m_data
);

    localparam INPUT_COUNT = 20;
    localparam NEURON_COUNT = 10;
    localparam DATA_WIDTH = 16;
    localparam ACC_WIDTH = 40;
    localparam OUTPUT_WIDTH = 16;
    localparam INDEX_WIDTH = 5;

    // Weights are neuron-major Q8.8 values; biases and sums are signed Q16.16.
    reg signed [DATA_WIDTH-1:0] weights [0:(INPUT_COUNT*NEURON_COUNT)-1];
    reg signed [ACC_WIDTH-1:0] biases [0:NEURON_COUNT-1];
    reg [INDEX_WIDTH-1:0] input_index;
    reg frame_pending;

    wire [NEURON_COUNT-1:0] neuron_valid;
    wire signed [ACC_WIDTH-1:0] neuron_sum [0:NEURON_COUNT-1];
    wire [OUTPUT_WIDTH-1:0] activated [0:NEURON_COUNT-1];

    integer init_index;
    integer output_index;
    genvar neuron_index;

    assign s_ready = !frame_pending && !m_valid;

    initial begin
        for (init_index = 0; init_index < INPUT_COUNT*NEURON_COUNT; init_index = init_index + 1)
            weights[init_index] = 0;
        for (init_index = 0; init_index < NEURON_COUNT; init_index = init_index + 1)
            biases[init_index] = 0;

        $readmemh(WEIGHT_FILE, weights);
        $readmemh(BIAS_FILE, biases);
    end

    generate
        for (neuron_index = 0; neuron_index < NEURON_COUNT; neuron_index = neuron_index + 1) begin : gen_neuron
            neuron #(
                .DATA_WIDTH(DATA_WIDTH),
                .ACC_WIDTH(ACC_WIDTH)
            ) neuron_inst (
                .clk(clk),
                .rst_n(rst_n),
                .sample_valid(s_valid && s_ready),
                .sample_first(input_index == 0),
                .sample_last(input_index == INPUT_COUNT-1),
                .data_in(s_data),
                .weight_in(weights[(neuron_index*INPUT_COUNT) + input_index]),
                .bias_in(biases[neuron_index]),
                .sum_out(neuron_sum[neuron_index]),
                .sum_valid(neuron_valid[neuron_index])
            );

            activation_function activation_inst (
                .value_in(neuron_sum[neuron_index]),
                .value_out(activated[neuron_index])
            );
        end
    endgenerate

    always @(posedge clk) begin
        if (!rst_n) begin
            input_index <= 0;
            frame_pending <= 1'b0;
            m_valid <= 1'b0;
            m_data <= 0;
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            if (s_valid && s_ready) begin
                if (input_index == INPUT_COUNT-1) begin
                    input_index <= 0;
                    frame_pending <= 1'b1;
                end else begin
                    input_index <= input_index + 1'b1;
                end
            end

            if (frame_pending && (&neuron_valid)) begin
                for (output_index = 0; output_index < NEURON_COUNT; output_index = output_index + 1)
                    m_data[(output_index*OUTPUT_WIDTH) +: OUTPUT_WIDTH] <= activated[output_index];
                m_valid <= 1'b1;
                frame_pending <= 1'b0;
            end
        end
    end

endmodule
