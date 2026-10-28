module neuron #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH = 40
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         sample_valid,
    input  wire                         sample_first,
    input  wire                         sample_last,
    input  wire signed [DATA_WIDTH-1:0] data_in,
    input  wire signed [DATA_WIDTH-1:0] weight_in,
    input  wire signed [ACC_WIDTH-1:0]  bias_in,
    output reg  signed [ACC_WIDTH-1:0]  sum_out,
    output reg                          sum_valid
);

    reg signed [ACC_WIDTH-1:0] accumulator;
    wire signed [(2*DATA_WIDTH)-1:0] product;
    wire signed [ACC_WIDTH-1:0] product_extended;

    assign product = data_in * weight_in;
    assign product_extended = {
        {(ACC_WIDTH-(2*DATA_WIDTH)){product[(2*DATA_WIDTH)-1]}},
        product
    };

    always @(posedge clk) begin
        if (!rst_n) begin
            accumulator <= 0;
            sum_out <= 0;
            sum_valid <= 1'b0;
        end else begin
            sum_valid <= 1'b0;

            if (sample_valid) begin
                if (sample_first) begin
                    accumulator <= product_extended;
                    if (sample_last) begin
                        sum_out <= product_extended + bias_in;
                        sum_valid <= 1'b1;
                    end
                end else begin
                    accumulator <= accumulator + product_extended;
                    if (sample_last) begin
                        sum_out <= accumulator + product_extended + bias_in; ,
                        sum_valid <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
