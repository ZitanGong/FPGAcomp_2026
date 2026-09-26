module pt8211_tx(
    input clk, input rst, input [15:0] pcm, input valid,
    output reg bclk, output reg ws, output reg sd,
    output ce, output reg underrun, output reg overrun
);
    reg [9:0] cnt;
    wire [4:0] slot=cnt[9:5];
    wire fall=cnt[4:0]==15;
    reg [15:0] pending, sample;
    reg ready, armed;
    assign ce=fall && slot==30;
    always @(posedge clk) begin
        if(rst) begin
            cnt<=0; bclk<=1; ws<=1; sd<=0;
            pending<=0; sample<=0; ready<=0; armed<=0;
            underrun<=0; overrun<=0;
        end else begin
            cnt<=cnt+1'b1;
            if(valid) begin
                if(ready) overrun<=1;
                pending<=pcm; ready<=1;
            end
            if(cnt[3:0]==15) bclk<=cnt[4];
            if(fall) begin
                ws<=slot[4];
                if(slot==30) armed<=1;
                if(slot==0) begin
                    ready<=0;
                    if(ready) begin sample<=pending; sd<=pending[15]; end
                    else begin
                        sample<=0; sd<=0;
                        if(armed) underrun<=1;
                    end
                end else sd<=sample[15-slot[3:0]];
            end
        end
    end
endmodule
