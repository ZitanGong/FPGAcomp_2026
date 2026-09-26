module scan165 #(
    parameter CLK_HZ = 49152000,
    parameter SHIFT_HZ = 100000,
    parameter FRAME_US = 1000
)(
    input clk, input rst,
    input [2:0] din,
    output reg shld, output reg sclk,
    output reg [20:0] raw,
    output reg done, output reg good
);
    localparam HALF = (CLK_HZ + SHIFT_HZ) / (2 * SHIFT_HZ);
    localparam FRAME = (CLK_HZ / 1000) * FRAME_US / 1000;
    reg [$clog2(FRAME)-1:0] cnt;
    (* syn_preserve = 1, syn_keep = 1 *) reg [2:0] meta, sync;
    reg [20:0] bits;
    reg hdr;
    integer j;

    always @(posedge clk) begin
        if (rst) begin
            meta <= 3'b111;
            sync <= 3'b111;
        end else begin
            meta <= din;
            sync <= meta;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            cnt <= 0; shld <= 1; sclk <= 0;
            raw <= 0; bits <= 0; hdr <= 0; done <= 0; good <= 0;
        end else begin
            done <= 0;
            if (cnt == FRAME-1) cnt <= 0;
            else cnt <= cnt + 1'b1;
            if (cnt == 0) begin shld <= 0; sclk <= 0; end
            if (cnt == HALF) shld <= 1;
            if (cnt == 2*HALF) hdr <= &sync;
            for (j=0; j<7; j=j+1) begin
                if (cnt == (2+2*j)*HALF) sclk <= 1;
                if (cnt == (3+2*j)*HALF) begin
                    sclk <= 0;
                    bits[6-j] <= ~sync[0];
                    bits[13-j] <= ~sync[1];
                    bits[20-j] <= ~sync[2];
                end
            end
            if (cnt == 16*HALF) begin
                raw <= bits; good <= hdr; done <= 1;
            end
        end
    end
endmodule
