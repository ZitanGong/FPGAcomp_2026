module touch_map #(
    parameter REVERSE=0, parameter STALE_N=1050000
)(
    input clk, input rst, input valid, input ready, input [7:0] touch,
    output reg [15:0] leds, output reg [3:0] pos,
    output reg active, output reg done
);
    reg [31:0] age;
    reg [15:0] next_leds;
    reg [3:0] next_pos;
    integer i;
    always @* begin
        next_leds=0; next_pos=0;
        for(i=7;i>=0;i=i-1) begin
            if(REVERSE) next_leds[2*(7-i)+:2]={2{touch[i]}};
            else next_leds[2*i+:2]={2{touch[i]}};
            if(touch[i]) next_pos=REVERSE ? 7-i : i;
        end
    end
    always @(posedge clk) begin
        if(rst || !ready) begin
            leds<=0; pos<=0; active<=0; done<=0; age<=0;
        end else begin
            done<=0;
            if(valid) begin
                leds<=next_leds; pos<=next_pos; active<=|touch;
                age<=0; done<=1;
            end else if(age>=STALE_N-1) begin
                leds<=0; pos<=0; active<=0;
            end else age<=age+1'b1;
        end
    end
endmodule
