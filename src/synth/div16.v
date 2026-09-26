module div16(
    input clk, input rst, input go,
    input [15:0] num, input [15:0] den,
    output reg [15:0] quo, output reg [15:0] rem,
    output reg busy, output reg done
);
    reg [15:0] q, d;
    reg [16:0] r;
    reg [3:0] cnt;
    wire [16:0] t = {r[15:0], q[15]};
    wire ge = t >= {1'b0,d};
    wire [16:0] rn = ge ? t - {1'b0,d} : t;
    wire [15:0] qn = {q[14:0],ge};
    always @(posedge clk) begin
        if (rst) begin
            q<=0; d<=1; r<=0; cnt<=0; quo<=0; rem<=0; busy<=0; done<=0;
        end else begin
            done <= 0;
            if (go) begin
                q<=num; d<=(den==0 ? 16'd1 : den); r<=0; cnt<=0; busy<=1;
            end else if (busy) begin
                q<=qn; r<=rn; cnt<=cnt+1'b1;
                if (cnt == 15) begin
                    quo<=qn; rem<=rn[15:0]; busy<=0; done<=1;
                end
            end
        end
    end
endmodule
