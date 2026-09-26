`timescale 1ns/1ps
module tb_key;
    reg clk=0, rst=1;
    always #500 clk=~clk;
    reg [20:0] press=0;
    reg h=1;
    wire [2:0] din;
    wire shld,sclk,done,good;
    wire [20:0] raw,keys;
    reg [7:0] db=1;
    scan165 #(.CLK_HZ(1000000)) dut(clk,rst,din,shld,sclk,raw,done,good);
    key_filter filt(clk,rst,done,good,raw,db,keys);
    hc165 a(shld,sclk,{h,~press[6:0]},din[0]);
    hc165 b(shld,sclk,{h,~press[13:7]},din[1]);
    hc165 c(shld,sclk,{h,~press[20:14]},din[2]);
    integer n;
    time prev_frame=0, prev_rise=0;
    integer edges=0;
    always @(negedge shld) begin
        if(prev_frame && $time-prev_frame!=1000000) $fatal(1,"scan period");
        prev_frame=$time; edges=0; prev_rise=0;
    end
    always @(posedge sclk) begin
        if(!shld) $fatal(1,"shift during load");
        if(prev_rise && $time-prev_rise!=10000) $fatal(1,"shift frequency");
        prev_rise=$time; edges++;
    end
    task frame;
        input [20:0] p;
        begin
            @(negedge clk); press=p;
            @(posedge done); #1;
            if(raw !== p || good !== h || edges!=7)
                $fatal(1,"order/header raw=%h expected=%h good=%b edges=%0d",raw,p,good,edges);
            @(negedge clk); @(negedge clk);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst=0;
        frame(0);
        for(n=0;n<21;n++) begin
            frame(21'b1<<n);
            if(keys !== (21'b1<<n)) $fatal(1,"key map %0d",n);
        end
        frame(0); db=3;
        frame(3); if(keys!=0) $fatal(1,"early debounce");
        frame(1); if(keys!=0) $fatal(1,"early debounce 2");
        frame(3); if(keys!=1) $fatal(1,"independent debounce");
        frame(1); frame(3); if(keys!=1) $fatal(1,"bounce accepted");
        frame(3); frame(3); if(keys!=3) $fatal(1,"stable press");
        frame(21'h155555); frame(21'h155555); frame(21'h155555);
        if(keys!=21'h155555) $fatal(1,"multi-key press/release");
        frame(0); frame(21'h155555); frame(0);
        if(keys!=21'h155555) $fatal(1,"release bounce");
        frame(0); frame(0); if(keys!=0) $fatal(1,"release");
        repeat(3) frame(21'h100a01);
        if(keys!=21'h100a01) $fatal(1,"rapid repeat down");
        repeat(3) frame(0);
        if(keys!=0) $fatal(1,"rapid repeat up");
        h=0; repeat(4) frame(21'h1fffff);
        if(keys!=0) $fatal(1,"bad H accepted");
        h=1; repeat(2) frame(21'h1fffff);
        if(keys!=0) $fatal(1,"bad frame counts retained");
        frame(21'h1fffff); if(keys!=21'h1fffff) $fatal(1,"all keys");
        $display("PASS tb_key: 21 mappings, H discard, 100kHz/1ms, debounce, bounce, chords, repeat");
        $finish;
    end
    initial begin #100000000; $fatal(1,"timeout"); end
endmodule
