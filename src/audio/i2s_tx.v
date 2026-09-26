module i2s_tx(
    input clk, input rst,
    input signed [15:0] pcm, input valid,
    output ce,
    output reg bclk, output reg lrck, output reg sd,
    output reg mclk,
    output reg underrun, output reg overrun
);
    reg [9:0] cnt;
    wire [5:0] slot = cnt[9:4];
    reg [15:0] pending, sample;
    reg ready, armed;
    wire fall = cnt[3:0]==7;
    assign ce = fall && slot==60;
    always @(posedge clk) begin
        if(rst) begin
            cnt<=0; mclk<=0; bclk<=1; lrck<=1; sd<=0;
            pending<=0; sample<=0; ready<=0; armed<=0;
            underrun<=0; overrun<=0;
        end else begin
            cnt<=cnt+1'b1;
            mclk<=cnt[1];
            if(valid) begin
                if(ready) overrun<=1;
                pending<=pcm; ready<=1;
            end
            if(cnt[2:0]==7) begin
                bclk<=cnt[3];
                if(!cnt[3]) begin
                    if(slot==60) armed<=1;
                    if(slot==0) begin
                        lrck<=0; sd<=0; ready<=0;
                        if(ready) sample<=pending;
                        else begin sample<=0; if(armed) underrun<=1; end
                    end else if(slot==32) begin lrck<=1; sd<=0; end
                    else if(slot>=1 && slot<=16) sd<=sample[16-slot];
                    else if(slot>=33 && slot<=48) sd<=sample[48-slot];
                    else sd<=0;
                end
            end
        end
    end
endmodule
