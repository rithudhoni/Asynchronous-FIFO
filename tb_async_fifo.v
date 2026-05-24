`timescale 1ns / 1ps

module tb_async_fifo();

    // Match the parameters from your RTL
    parameter DSIZE = 8;
    parameter ASIZE = 4;

    // Testbench signals
    reg wclk, rclk;
    reg wrst_n, rrst_n;
    reg winc, rinc;
    reg [DSIZE-1:0] wdata;
    wire [DSIZE-1:0] rdata;
    wire wfull, rempty;

    // Instantiate the Device Under Test (DUT)
    async_fifo #(
        .DSIZE(DSIZE),
        .ASIZE(ASIZE)
    ) dut (
        .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty)
    );

    // -------------------------------------------------------
    // Clock Generation (Asynchronous Frequencies)
    // -------------------------------------------------------
    // Write clock: 100 MHz (10ns period)
    initial wclk = 0;
    always #5 wclk = ~wclk;

    // Read clock: 33.33 MHz (30ns period)
    initial rclk = 0;
    always #15 rclk = ~rclk;

    // -------------------------------------------------------
    // Stimulus Block
    // -------------------------------------------------------
    initial begin
        // 1. Initialize signals
        wrst_n = 0; rrst_n = 0;
        winc = 0; rinc = 0;
        wdata = 8'h00; // Start at 0, so first addition makes it 1

        // 2. Apply and release reset
        #40;
        wrst_n = 1; rrst_n = 1;
        #40;

        $display("--- Phase 1: Burst Write until FULL ---");
        while (!wfull) begin
            @(negedge wclk); // Drive on the falling edge to prevent race conditions!
            if (!wfull) begin
                winc = 1;
                wdata = wdata + 1; 
            end
        end
        @(negedge wclk) winc = 0;
        $display("--- FIFO is FULL ---");

        #100; // Let the design settle

        $display("--- Phase 2: Burst Read until EMPTY ---");
        while (!rempty) begin
            @(negedge rclk); // Drive read increment on falling edge
            if (!rempty) begin
                rinc = 1;
            end
        end
        @(negedge rclk) rinc = 0;
        $display("--- FIFO is EMPTY ---");

        #100;

        $display("--- Phase 3: Simultaneous Read & Write ---");
        fork
            begin : WRITE_THREAD
                repeat(20) begin
                    @(negedge wclk);
                    if (!wfull) begin
                        winc = 1;
                        wdata = wdata + 1;
                    end else begin
                        winc = 0;
                    end
                end
                @(negedge wclk) winc = 0;
            end
            begin : READ_THREAD
                repeat(20) begin
                    @(negedge rclk);
                    if (!rempty) begin
                        rinc = 1;
                    end else begin
                        rinc = 0;
                    end
                end
                @(negedge rclk) rinc = 0;
            end
        join

        #200;
        $display("--- Simulation Complete ---");
        $stop;
    end
    
endmodule