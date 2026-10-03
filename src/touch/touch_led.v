module touch_led #(
    parameter CLK_HZ=52500000, parameter BUS_HZ=350000, parameter FIRST=0,
    parameter BOOT_N=CLK_HZ/10, parameter RESET_N=CLK_HZ/500,
    parameter SETTLE_N=CLK_HZ/50, parameter POLL_N=CLK_HZ/500,
    parameter RETRY_N=CLK_HZ/10, parameter WAIT_N=CLK_HZ/100,
    parameter TOUCH_TH=12, parameter RELEASE_TH=6,
    parameter REVERSE=0, parameter STALE_N=CLK_HZ/50
)(
    input clk, input rst, input irq_n, inout scl, inout sda,
    output led_data, output led_clk, output led_lat,
    output ready, output fault
);
    wire [7:0] touch;
    wire [79:0] filt,base;
    wire [15:0] leds;
    wire valid;
    mpr121 #(.CLK_HZ(CLK_HZ),.BUS_HZ(BUS_HZ),.FIRST(FIRST),.BOOT_N(BOOT_N),.RESET_N(RESET_N),
        .SETTLE_N(SETTLE_N),.POLL_N(POLL_N),.RETRY_N(RETRY_N),.WAIT_N(WAIT_N),
        .TOUCH_TH(TOUCH_TH),.RELEASE_TH(RELEASE_TH)) u_mpr(
        .clk(clk),.rst(rst),.irq_n(irq_n),.scl(scl),.sda(sda),
        .touch(touch),.filt(filt),.base(base),.valid(valid),.ready(ready),.fault(fault));
    touch_map #(.REVERSE(REVERSE),.STALE_N(STALE_N)) u_pos(
        .clk(clk),.rst(rst),.valid(valid),.ready(ready),.touch(touch),
        .leds(leds),.pos(),.active(),.done());
    led595 #(.CLK_HZ(CLK_HZ)) u_led(
        .clk(clk),.rst(rst),.leds(leds),.data(led_data),.sclk(led_clk),.lat(led_lat));
endmodule
