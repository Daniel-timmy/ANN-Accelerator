module activation_function (
    input  wire signed [39:0] value_in,
    output reg         [15:0] value_out
);

    function [15:0] sigmoid_q16;
        input signed [39:0] x;
        reg [39:0] shifted;
        reg [4:0] segment;
        reg [7:0] fraction;
        reg [15:0] y0;
        reg [15:0] y1;
        reg [31:0] interpolation;
        begin
            if (x <= -40'sd524288) begin
                sigmoid_q16 = 16'd0;
            end else if (x >= 40'sd524288) begin
                sigmoid_q16 = 16'd65535;
            end else begin
                // Input and table steps are Q16.16 and 1.0 respectively.
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
                sigmoid_q16 = interpolation[15:0];
            end
        end
    endfunction

    always @* begin
        value_out = sigmoid_q16(value_in);
    end

endmodule
