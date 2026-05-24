// ============================================================================
// Module: Asynchronous FIFO (Top Level)
// ============================================================================
module async_fifo #(
    parameter DSIZE = 8,  // Data width (8 bits)
    parameter ASIZE = 4   // Address width (4 bits = 16 depth)
)(
    input  wire             wclk,
    input  wire             wrst_n,
    input  wire             winc,
    input  wire [DSIZE-1:0] wdata,
    output wire             wfull,

    input  wire             rclk,
    input  wire             rrst_n,
    input  wire             rinc,
    output wire [DSIZE-1:0] rdata,
    output wire             rempty
);

    wire [ASIZE:0] wptr, rptr;
    wire [ASIZE:0] wq2_rptr, rq2_wptr;

    // 1. 2-Stage Synchronizer: Read Pointer to Write Domain
    sync_r2w #(ASIZE) sync_r2w_inst (
        .wq2_rptr(wq2_rptr), 
        .rptr(rptr), 
        .wclk(wclk), 
        .wrst_n(wrst_n)
    );

    // 2. 2-Stage Synchronizer: Write Pointer to Read Domain
    sync_w2r #(ASIZE) sync_w2r_inst (
        .rq2_wptr(rq2_wptr), 
        .wptr(wptr), 
        .rclk(rclk), 
        .rrst_n(rrst_n)
    );

    // 3. Dual-Port RAM Storage
    fifomem #(DSIZE, ASIZE) fifomem_inst (
        .rdata(rdata), 
        .wdata(wdata), 
        .waddr(wptr[ASIZE-1:0]), 
        .raddr(rptr[ASIZE-1:0]), 
        .wclken(winc & ~wfull), 
        .wclk(wclk)
    );

    // 4. Read Pointer & Empty Logic
    rptr_empty #(ASIZE) rptr_empty_inst (
        .rempty(rempty), 
        .rptr(rptr), 
        .rq2_wptr(rq2_wptr), 
        .rinc(rinc), 
        .rclk(rclk), 
        .rrst_n(rrst_n)
    );

    // 5. Write Pointer & Full Logic
    wptr_full #(ASIZE) wptr_full_inst (
        .wfull(wfull), 
        .wptr(wptr), 
        .wq2_rptr(wq2_rptr), 
        .winc(winc), 
        .wclk(wclk), 
        .wrst_n(wrst_n)
    );

endmodule


// ============================================================================
// Sub-Module: Dual-Port RAM
// ============================================================================
module fifomem #(
    parameter DSIZE = 8,
    parameter ASIZE = 4
)(
    output wire [DSIZE-1:0] rdata,
    input  wire [DSIZE-1:0] wdata,
    input  wire [ASIZE-1:0] waddr, raddr,
    input  wire             wclken, wclk
);

    // Memory array
    localparam DEPTH = 1 << ASIZE;
    reg [DSIZE-1:0] mem [0:DEPTH-1];

    assign rdata = mem[raddr];

    always @(posedge wclk) begin
        if (wclken) begin
            mem[waddr] <= wdata;
        end
    end
endmodule


// ============================================================================
// Sub-Module: Synchronizer (Read to Write Domain)
// ============================================================================
module sync_r2w #(
    parameter ASIZE = 4
)(
    output reg  [ASIZE:0] wq2_rptr,
    input  wire [ASIZE:0] rptr,
    input  wire           wclk, wrst_n
);

    reg [ASIZE:0] wq1_rptr;

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wq1_rptr <= 0;
            wq2_rptr <= 0;
        end else begin
            wq1_rptr <= rptr;
            wq2_rptr <= wq1_rptr; // 2nd stage
        end
    end
endmodule


// ============================================================================
// Sub-Module: Synchronizer (Write to Read Domain)
// ============================================================================
module sync_w2r #(
    parameter ASIZE = 4
)(
    output reg  [ASIZE:0] rq2_wptr,
    input  wire [ASIZE:0] wptr,
    input  wire           rclk, rrst_n
);

    reg [ASIZE:0] rq1_wptr;

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rq1_wptr <= 0;
            rq2_wptr <= 0;
        end else begin
            rq1_wptr <= wptr;
            rq2_wptr <= rq1_wptr; // 2nd stage
        end
    end
endmodule


// ============================================================================
// Sub-Module: Read Pointer & Empty Logic
// ============================================================================
module rptr_empty #(
    parameter ASIZE = 4
)(
    output reg              rempty,
    output reg  [ASIZE:0]   rptr,
    input  wire [ASIZE:0]   rq2_wptr,
    input  wire             rinc, rclk, rrst_n
);

    reg  [ASIZE:0] rbin;
    wire [ASIZE:0] rgraynext, rbinnext;
    wire           rempty_val;

    // Memory read-address pointer (binary to gray conversion)
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin <= 0;
            rptr <= 0;
        end else begin
            rbin <= rbinnext;
            rptr <= rgraynext;
        end
    end

    // Binary logic
    assign rbinnext = rbin + (rinc & ~rempty);
    // Binary to Gray conversion
    assign rgraynext = (rbinnext >> 1) ^ rbinnext;

    // FIFO empty when the next rptr == synchronized wptr or on reset
    assign rempty_val = (rgraynext == rq2_wptr);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n)
            rempty <= 1'b1;
        else
            rempty <= rempty_val;
    end
endmodule


// ============================================================================
// Sub-Module: Write Pointer & Full Logic
// ============================================================================
module wptr_full #(
    parameter ASIZE = 4
)(
    output reg              wfull,
    output reg  [ASIZE:0]   wptr,
    input  wire [ASIZE:0]   wq2_rptr,
    input  wire             winc, wclk, wrst_n
);

    reg  [ASIZE:0] wbin;
    wire [ASIZE:0] wgraynext, wbinnext;
    wire           wfull_val;

    // Memory write-address pointer (binary to gray conversion)
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin <= 0;
            wptr <= 0;
        end else begin
            wbin <= wbinnext;
            wptr <= wgraynext;
        end
    end

    // Binary logic
    assign wbinnext = wbin + (winc & ~wfull);
    // Binary to Gray conversion
    assign wgraynext = (wbinnext >> 1) ^ wbinnext;

    // FIFO full when:
    // 1. MSB and 2nd MSB of write pointer are inverse of synchronized read pointer
    // 2. All other bits match exactly
    assign wfull_val = (wgraynext == {~wq2_rptr[ASIZE:ASIZE-1], wq2_rptr[ASIZE-2:0]});

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n)
            wfull <= 1'b0;
        else
            wfull <= wfull_val;
    end
endmodule