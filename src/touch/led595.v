module led595 #(
    parameter CLK_HZ=52500000, parameter SHIFT_HZ=100000,
    parameter REFRESH_N=CLK_HZ/1000
)(
    input clk, input rst, input [15:0] leds,
    output reg data, output reg sclk, output reg lat
);
    localparam HALF=(CLK_HZ+2*SHIFT_HZ-1)/(2*SHIFT_HZ);
    reg [2:0] st;
    reg [31:0] cnt,refresh;
    reg [15:0] sh,sent;
    reg started;
    reg [3:0] bit_n;
    always @(posedge clk) begin
        if(rst) begin
            st<=0; cnt<=0; refresh<=0; sh<=0; sent<=0; started<=0; bit_n<=0;
            data<=0; sclk<=0; lat<=0;
        end else begin
            if(refresh!=0) refresh<=refresh-1'b1;
            if(cnt!=0) cnt<=cnt-1'b1;
            else case(st)
                0: if(!started || leds!=sent || refresh==0) begin
                    sh<=leds; sent<=leds; started<=1; data<=leds[15]; bit_n<=15;
                    cnt<=HALF-1; refresh<=REFRESH_N; st<=1;
                end
                1: begin sclk<=1; cnt<=HALF-1; st<=2; end
                2: begin
                    sclk<=0; cnt<=HALF-1;
                    if(bit_n==0) st<=3;
                    else begin sh<={sh[14:0],1'b0}; data<=sh[14]; bit_n<=bit_n-1'b1; st<=1; end
                end
                3: begin lat<=1; cnt<=HALF-1; st<=4; end
                4: begin lat<=0; cnt<=HALF-1; st<=0; end
                default: st<=0;
            endcase
        end
    end
endmodule
