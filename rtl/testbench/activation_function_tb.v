`timescale 1ns/1ps

module activation_function_tb;

    reg signed [39:0] value_in;
    wire [15:0] value_out;

    activation_function dut (
        .value_in(value_in),
        .value_out(value_out)
    );

    task check_output;
        input signed [39:0] test_input;
        input [15:0] expected;
        input [255:0] test_name;
        begin
            value_in = test_input;
            #1;
            if (value_out !== expected) begin
                $display("FAIL: %0s: input=%0d expected=%0d got=%0d",
                         test_name, test_input, expected, value_out);
                $fatal(1);
            end
        end
    endtask

    initial begin
        // The input is signed Q16.16: real values are multiplied by 2^16.
        check_output(-40'sd524289, 16'd0, "below negative clamp");
        check_output(-40'sd524288, 16'd0, "negative clamp boundary (-8)");
        check_output(-40'sd458752, 16'd60, "table sample at -7");
        check_output(-40'sd32768, 16'd25196, "interpolation at -0.5");
        check_output(40'sd0, 16'd32768, "sigmoid at zero");
        check_output(40'sd32768, 16'd40339, "interpolation at 0.5");
        check_output(40'sd98304, 16'd52814, "interpolation at 1.5");
        check_output(40'sd524288, 16'd65535, "positive clamp boundary (+8)");
        check_output(40'sd524289, 16'd65535, "above positive clamp");

        $display("PASS: activation_function_tb completed all checks");
        $finish;
    end

endmodule
