module ann_processor #(
    parameter LAYER1_WEIGHT_FILE = "layer1_weights.mem",
    parameter LAYER1_BIAS_FILE = "layer1_bias.mem",
    parameter OUTPUT_WEIGHT_FILE = "output_layer_weights.mem",
    parameter OUTPUT_BIAS_FILE = "output_layer_bias.mem"
) (
    input  wire                clk,
    input  wire                rst_n,
    input  wire                s_valid,
    output wire                s_ready,
    input  wire signed [15:0]  s_data,
    output wire                m_valid,
    input  wire                m_ready,
    output wire [15:0]         m_data
);

    wire layer1_valid;
    wire layer1_ready;
    wire [159:0] layer1_data;

    layer1 #(
        .WEIGHT_FILE(LAYER1_WEIGHT_FILE),
        .BIAS_FILE(LAYER1_BIAS_FILE)
    ) layer1_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .m_valid(layer1_valid),
        .m_ready(layer1_ready),
        .m_data(layer1_data)
    );

    output_layer #(
        .WEIGHT_FILE(OUTPUT_WEIGHT_FILE),
        .BIAS_FILE(OUTPUT_BIAS_FILE)
    ) output_layer_inst (
        .clk(clk),
        .rst_n(rst_n),
        .s_valid(layer1_valid),
        .s_ready(layer1_ready),
        .s_data(layer1_data),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data(m_data)
    );

endmodule