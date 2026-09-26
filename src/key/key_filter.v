module key_filter #(parameter N = 21)(
    input clk, input rst,
    input done, input good,
    input [N-1:0] raw,
    input [7:0] db_n,
    output reg [N-1:0] keys
);
    reg [7:0] cnt [0:N-1];
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            keys <= 0;
            for (i=0; i<N; i=i+1) cnt[i] <= 0;
        end else if (done) begin
            for (i=0; i<N; i=i+1) begin
                if (!good || raw[i] == keys[i]) cnt[i] <= 0;
                else if (db_n <= 1 || cnt[i] >= db_n-1'b1) begin
                    keys[i] <= raw[i]; cnt[i] <= 0;
                end else cnt[i] <= cnt[i] + 1'b1;
            end
        end
    end
endmodule
