`timescale 1ns/1ps
module tb_key_fault;
    reg clk=0,rst=1;
    always #500 clk=~clk;
    reg [20:0] press=0;
    reg [2:0] mode=0;
    wire shld,sclk,done,good;
    wire [2:0] q,din;
    wire [20:0] raw,keys;
    wire kc=mode==3 ? 1'b0 : sclk;
    assign din=mode==1 ? 3'b111 : mode==2 ? {1'b0,q[1:0]} : q;
    hc165 a(shld,kc,{1'b1,~press[6:0]},q[0]);
    hc165 b(shld,kc,{1'b1,~press[13:7]},q[1]);
    hc165 c(shld,kc,{1'b1,~press[20:14]},q[2]);
    scan165 #(.CLK_HZ(1000000)) dut(clk,rst,din,shld,sclk,raw,done,good);
    key_filter filt(clk,rst,done,good,raw,8'd3,keys);
    task restart;
        input [2:0] m;
        begin
            @(negedge clk); rst=1; mode=m; press=21'h100a01;
            repeat(4) @(negedge clk); rst=0;
            repeat(4) @(posedge done);
            repeat(2) @(negedge clk);
        end
    endtask
    initial begin
        restart(0);
        if(keys!=press || !good) $fatal(1,"reference chord");
        restart(1);
        if(keys!=0 || raw!=0 || !good) $fatal(1,"disconnected pull-up signature");
        $display("All OUT stuck high: good=1, raw=0, keys=0 (cannot detect by H alone)");
        restart(2);
        if(keys!=0 || good || raw[13:0]!=press[13:0]) $fatal(1,"one bad lane signature");
        $display("OUT3 stuck low: good=0, valid OUT1/2 changes blocked by whole-frame check");
        restart(3);
        if(keys!=0 || raw!=0 || !good) $fatal(1,"missing shift clock signature");
        $display("No clock reaches chips: H held at 1, good=1, raw=0, keys=0");
        restart(0);
        if(keys!=press || !good) $fatal(1,"recovery");
        $display("PASS tb_key_fault: disconnected inputs, stuck-low lane, missing shift clock, recovery");
        $finish;
    end
    initial begin #30000000; $fatal(1,"fault injection timeout"); end
endmodule
