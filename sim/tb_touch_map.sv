`timescale 1ns/1ps
module tb_touch_map;
    reg clk=0,rst=1,valid=0,ready=1;
    reg [7:0] touch=0;
    wire [15:0] leds,rev;
    wire [3:0] pos;
    wire active,done;
    always #10 clk=~clk;
    touch_map #(.STALE_N(40)) dut(clk,rst,valid,ready,touch,leds,pos,active,done);
    touch_map #(.STALE_N(40),.REVERSE(1)) back(.clk(clk),.rst(rst),.valid(valid),.ready(ready),.touch(touch),.leds(rev),.pos(),.active(),.done());
    reg [15:0] exp_led,exp_rev;
    integer m,k;
    reg serial_done=0;
    task sample(input [7:0] v);
        begin
            @(negedge clk); touch=v; valid=1;
            @(negedge clk); valid=0;
        end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst=0;
        for(m=0;m<256;m=m+1) begin
            exp_led=0; exp_rev=0;
            for(k=0;k<8;k=k+1) begin
                if(m & (1<<k)) begin exp_led=exp_led | (16'h3<<(2*k)); exp_rev=exp_rev | (16'h3<<(14-2*k)); end
            end
            sample(m);
            if(leds!==exp_led || rev!==exp_rev || active!==(m!=0) || !done)
                $fatal(1,"pair map mask=%h",m);
        end
        repeat(20) begin sample(8'h08); repeat(20) @(negedge clk); end
        if(leds!=16'h00c0) $fatal(1,"held touch cleared with fresh frames");
        sample(0);
        if(leds!=0 || active) $fatal(1,"release did not clear in one cycle");
        sample(8'h80); repeat(41) @(negedge clk);
        if(leds!=0 || active) $fatal(1,"stale frame held LEDs");
        sample(1); ready=0; @(negedge clk);
        if(leds!=0) $fatal(1,"offline LEDs");
        wait(serial_done);
        $display("PASS tb_touch_map: 256 masks, reversal, hold, release, stale/offline, mid-transfer change");
        $finish;
    end
    reg [15:0] cmd=0,sr=0,physical=0,snapshot;
    wire data,sclk,lat;
    integer bits=0;
    led595 #(.CLK_HZ(1000000),.SHIFT_HZ(100000),.REFRESH_N(1000)) tx(clk,rst,cmd,data,sclk,lat);
    always @(posedge sclk) begin
        if(bits==0) snapshot=tx.sent;
        sr={sr[14:0],data}; bits=bits+1;
    end
    always @(posedge lat) begin
        if(bits!=16 || sr!==snapshot) $fatal(1,"595 torn frame");
        physical=sr; bits=0;
    end
    initial begin
        wait(!rst); @(negedge clk); cmd=16'hc000;
        wait(physical==16'hc000);
        @(negedge clk); cmd=3;
        wait(bits==8); @(negedge clk); cmd=0;
        fork
            begin wait(physical==0); serial_done=1; end
            begin repeat(360) @(negedge clk); if(!serial_done) $fatal(1,"595 release exceeded two transfers"); end
        join
    end
    initial begin #1000000; $fatal(1,"map timeout"); end
endmodule
