module output_layer #(
    parameter WEIGHT_FILE = "output_layer_weights.mem",
    parameter BIAS_FILE = "output_layer_bias.mem"
) (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         s_valid,
    output wire         s_ready,
    input  wire [159:0] s_data,
    output reg          m_valid,
    input  wire         m_ready,
    output reg  [15:0]  m_data
);

    localparam INPUT_COUNT = 10;
    localparam ACC_WIDTH = 40;

    // Inputs are Q0.16, weights are signed Q8.8, and bias/sum are Q16.16.
    reg signed [15:0] weights [0:INPUT_COUNT-1];
    reg signed [ACC_WIDTH-1:0] biases [0:0];

    wire signed [16:0] activation_signed [0:INPUT_COUNT-1];
    wire signed [32:0] products [0:INPUT_COUNT-1];
    wire signed [ACC_WIDTH-1:0] scaled_products [0:INPUT_COUNT-1];

    reg signed [ACC_WIDTH-1:0] weighted_sum;
    wire [15:0] activated_sum;

    integer init_index;
    integer sum_index;

    assign s_ready = !m_valid || m_ready;

    initial begin
        for (init_index = 0; init_index < INPUT_COUNT; init_index = init_index + 1)
            weights[init_index] = 0;
        biases[0] = 0;

        $readmemh(WEIGHT_FILE, weights);
        $readmemh(BIAS_FILE, biases);
    end

    genvar input_index;
    generate
        for (input_index = 0; input_index < INPUT_COUNT; input_index = input_index + 1) begin : gen_product
            assign activation_signed[input_index] = {1'b0, s_data[(input_index*16) +: 16]};
            assign products[input_index] =
                activation_signed[input_index] * weights[input_index];
            assign scaled_products[input_index] =
                {{7{products[input_index][32]}}, products[input_index]} >>> 8;
        end
    endgenerate

    always @* begin
        weighted_sum = biases[0];
        for (sum_index = 0; sum_index < INPUT_COUNT; sum_index = sum_index + 1)
            weighted_sum = weighted_sum + scaled_products[sum_index];
    end

    activation_function activation_inst (
        .value_in(weighted_sum),
        .value_out(activated_sum)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data <= 0;
        end else begin
            if (s_valid && s_ready) begin
                m_data <= activated_sum;
                m_valid <= 1'b1;
            end else if (m_valid && m_ready) begin
                m_valid <= 1'b0;
            end
        end
    end

endmodule