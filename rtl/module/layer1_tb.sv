`timescale 1ns/1ps

module layer1_tb;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg s_valid = 1'b0;
    wire s_ready;
    reg signed [15:0] s_data = 0;
    wire m_valid;
    reg m_ready = 1'b0;
    wire [159:0] m_data;
    integer i;

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

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        for (i = 0; i < 20; i = i + 1) begin
            @(negedge clk);
            s_valid = 1'b1;
            s_data = 0;
            while (!s_ready)
                @(negedge clk);
            @(posedge clk);
        end

        @(negedge clk);
        s_valid = 1'b0;

        wait (m_valid);
        for (i = 0; i < 10; i = i + 1) begin
            if (m_data[(i*16) +: 16] !== 16'd32768)
                $fatal(1, "Neuron %0d output mismatch: %0d", i, m_data[(i*16) +: 16]);
        end

        @(negedge clk);
        m_ready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        if (m_valid !== 1'b0)
            $fatal(1, "Output valid did not clear after handshake");

        $display("PASS: one 20-input vector produced ten expected sigmoid outputs");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Testbench timeout");
    end

endmodule
