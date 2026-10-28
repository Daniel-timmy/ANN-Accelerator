`timescale 1ns/1ps

module output_layer_tb;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg s_valid = 1'b0;
    wire s_ready;
    reg [159:0] s_data = 0;
    wire m_valid;
    reg m_ready = 1'b0;
    wire [15:0] m_data;

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

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        s_valid = 1'b1;
        if (!s_ready)
            $fatal(1, "Input was not ready");
        @(posedge clk);

        @(negedge clk);
        s_valid = 1'b0;
        if (!m_valid || m_data !== 16'd32768)
            $fatal(1, "Expected valid sigmoid(0) output of 32768");
        if (s_ready)
            $fatal(1, "Input ready should deassert while output is stalled");

        m_ready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        if (!s_ready || m_valid)
            $fatal(1, "Output handshake did not release the module");

        $display("PASS: zero parameters produce sigmoid(0) and obey output backpressure");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Testbench timeout");
    end

endmodule
