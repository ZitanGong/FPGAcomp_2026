`timescale 1ns/1ps
module tb_touch_speed;
    reg clk=0,rst=1;
    always #9.52381 clk=~clk;
    tri1 scl,sda;
    wire valid,ready,fault;
    mpr121 #(.BOOT_N(20),.RESET_N(20),.SETTLE_N(20)) dut(
        .clk(clk),.rst(rst),.irq_n(1'b1),.scl(scl),.sda(sda),
        .touch(),.filt(),.base(),.valid(valid),.ready(ready),.fault(fault));
    mpr_model chip(scl,sda,1'b1);
    realtime rise_t=0,fall_t=0,frame_t,elapsed;
    integer clocks=0;
    always @(posedge scl) begin
        if(fall_t>0 && $realtime-fall_t<1300.0) $fatal(1,"I2C tLOW violated");
        rise_t=$realtime; clocks=clocks+1;
    end
    always @(negedge scl) begin
        if(rise_t>0 && $realtime-rise_t<700.0) $fatal(1,"I2C tHIGH violated");
        fall_t=$realtime;
    end
    always @(posedge fault) if(!rst) $fatal(1,"bus fault at default speed");
    initial begin
        repeat(5) @(negedge clk); rst=0;
        wait(ready); @(posedge valid); frame_t=$realtime;
        repeat(3) begin
            @(posedge valid); elapsed=$realtime-frame_t; frame_t=$realtime;
            if(elapsed<1999000 || elapsed>2010000) $fatal(1,"poll deadline %0f ns",elapsed);
        end
        if(clocks<2000) $fatal(1,"insufficient I2C traffic");
        $display("PASS tb_touch_speed: default bus tLOW/tHIGH and 2 ms valid cadence (%0f ns)",elapsed);
        $finish;
    end
    initial begin #20000000; $fatal(1,"speed timeout"); end
endmodule
