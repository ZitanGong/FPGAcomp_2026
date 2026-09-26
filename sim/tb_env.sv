`timescale 1ns/1ps
module tb_env;
    reg clk=0,rst=1,ce=0,gate=0;
    always #5 clk=~clk;
    reg [15:0] a=48,d=2400,s=32768,r=4800;
    wire [15:0] env;
    wire [2:0] state;
    adsr dut(clk,rst,ce,gate,a,d,s,r,env,state);
    integer i,origin,expected;
    task tick;
        begin
            @(negedge clk); ce=1;
            @(negedge clk); ce=0;
            repeat(30) @(negedge clk);
        end
    endtask
    task expect_env(input integer x);
        if(env !== x[15:0]) $fatal(1,"env %0d expected %0d state %0d",env,x,state);
    endtask
    initial begin
        repeat(4) @(negedge clk); rst=0;
        tick(); expect_env(0);
        gate=1; tick(); expect_env(0);
        for(i=1;i<=48;i++) begin tick(); expect_env((65535*i)/48); end
        if(state!=2) $fatal(1,"attack count");
        for(i=1;i<=2400;i++) begin tick(); expect_env(65535-(32767*i)/2400); end
        if(state!=3) $fatal(1,"decay count");
        repeat(10) begin tick(); expect_env(32768); end
        gate=0; tick(); expect_env(32768);
        for(i=1;i<=4800;i++) begin tick(); expect_env(32768-(32768*i)/4800); end
        if(state!=0) $fatal(1,"release count");
        gate=1; tick(); repeat(20) tick(); origin=env;
        gate=0; tick(); expect_env(origin);
        repeat(100) tick(); origin=env;
        gate=1; tick(); expect_env(origin);
        for(i=1;i<=48;i++) begin tick(); expect_env(origin+((65535-origin)*i)/48); end
        gate=0; tick(); repeat(7) tick(); origin=env;
        gate=1; tick(); expect_env(origin);
        tick(); if(env<origin) $fatal(1,"retrigger discontinuity");
        a=0; d=0; r=0; gate=0; tick(); expect_env(0);
        gate=1; tick(); expect_env(s);
        gate=0; tick(); expect_env(0);
        a=1; d=1; r=1; s=65535;
        gate=1; tick(); tick(); tick(); expect_env(65535);
        gate=0; tick(); tick(); expect_env(0);
        $display("PASS tb_env: exact 48/2400/4800 samples, sustain, early release, retrigger, zero/one durations");
        $finish;
    end
    always @(posedge clk) if(!rst && ce && (dut.busy || dut.go)) $fatal(1,"envelope preparation missed sample");
    initial begin #10000000; $fatal(1,"timeout"); end
endmodule
