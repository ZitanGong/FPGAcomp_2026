`timescale 1ns/1ps
module tb_mix;
    reg clk=0,rst=1,valid=0;
    always #5 clk=~clk;
    reg [335:0] x=0;
    wire signed [15:0] y,hot,loud;
    wire done,clip,hd,hc,ld,lc;
    mix21 dut(clk,rst,valid,x,3'd4,y,done,clip);
    mix21 #(.SHIFT(0)) stress(clk,rst,valid,x,3'd4,hot,hd,hc);
    mix21 #(.SHIFT(6),.GAIN(3)) board(clk,rst,valid,x,3'd4,loud,ld,lc);
    integer i,j,sum,v,expected,eh,el;
    task check;
        begin
            @(negedge clk); valid=1;
            @(negedge clk); valid=0;
            @(posedge done); #1;
            expected=(sum+16-(sum<0 ? 1 : 0)) >>> 5;
            el=(3*sum+32-(sum<0 ? 1 : 0)) >>> 6;
            eh=sum>32767 ? 32767 : (sum< -32768 ? -32768 : sum);
            if(y!==expected[15:0] || clip || hot!==eh[15:0] || hc!==(eh!=sum))
                $fatal(1,"mix sum=%d y=%d hot=%d clip=%b",sum,y,hot,hc);
            if(loud!==el[15:0] || lc || !ld) $fatal(1,"board gain/rounding %d %d",loud,el);
            @(negedge clk);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst=0;
        for(i=0;i<21;i++) x[i*16 +:16]=16'h7fff;
        sum=21*32767; check();
        for(i=0;i<21;i++) x[i*16 +:16]=16'h8000;
        sum=21*(-32768); check();
        x=0;
        for(j=-65;j<=65;j++) begin x[15:0]=j; sum=j; check(); end
        for(j=0;j<200;j++) begin
            sum=0;
            for(i=0;i<21;i++) begin v=$signed(16'($random)); x[i*16 +:16]=v; sum+=v; end
            check();
        end
        $display("PASS tb_mix: 21 full-scale voices, 3/64 headroom, symmetric rounding, saturation, random vectors");
        $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
