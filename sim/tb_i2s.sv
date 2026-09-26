`timescale 1ns/1ps
module tb_i2s;
    reg clk=0,rst=1,valid=0;
    always #10 clk=~clk;
    reg signed [15:0] pcm=0;
    wire ce,bclk,lrck,sd,mclk,under,over;
    i2s_tx dut(clk,rst,pcm,valid,ce,bclk,lrck,sd,mclk,under,over);
    reg [15:0] seq[0:7];
    reg [15:0] want=0, rx=0;
    integer n=0,frames=0,bitno=-1,channel=1,req=0;
    reg prev_lr=1,enabled=1;
    time prev_req=0,prev_bclk=0;
    time prev_mclk=0;
    always @(posedge mclk) if(!rst) begin
        if(prev_mclk && $time-prev_mclk!=80) $fatal(1,"MCLK divider");
        prev_mclk=$time;
    end
    always @(sd or lrck) if(!rst) begin
        #0.001;
        if(bclk!==0) $fatal(1,"SD/WS must change on falling BCLK");
        if($time!=prev_bclk) $fatal(1,"SD/WS change outside launch edge");
    end
    always @(posedge clk) if(!rst && ce) begin
        if(prev_req && $time-prev_req!=20480) $fatal(1,"sample period");
        prev_req=$time; req++;
    end
    always @(negedge bclk) if(!rst) begin
        if(prev_bclk && $time-prev_bclk!=320) $fatal(1,"BCLK divider");
        prev_bclk=$time;
    end
    always @(posedge bclk) if(!rst && enabled) begin
        if(lrck !== prev_lr) begin
            if(bitno>=0 && bitno!=31) $fatal(1,"slot length %0d",bitno);
            bitno=0; channel=lrck; rx=0;
            if(!lrck) begin
                frames++;
                want=frames<=1 ? 16'd0 : seq[(frames-2)%8];
            end
        end else begin
            bitno++;
            if(bitno>=1 && bitno<=16) rx={rx[14:0],sd};
            if(bitno==16 && rx!==want) $fatal(1,"I2S frame=%0d ch=%0d got=%h want=%h",frames,channel,rx,want);
            if(bitno>16 && sd!==0) $fatal(1,"padding");
        end
        prev_lr=lrck;
    end
    initial begin
        seq[0]=16'h8000; seq[1]=16'h7fff; seq[2]=16'h0001; seq[3]=16'hffff;
        seq[4]=16'ha55a; seq[5]=16'h5aa5; seq[6]=0; seq[7]=16'h1234;
        repeat(4) @(negedge clk); rst=0;
        repeat(12) begin
            @(posedge ce);
            repeat(12) @(negedge clk);
            pcm=seq[n%8]; valid=1;
            @(negedge clk); valid=0; n++;
        end
        @(posedge ce); #1;
        if(under || over) $fatal(1,"unexpected mailbox fault");
        enabled=0;
        repeat(1100) @(negedge clk);
        if(!under) $fatal(1,"missing underrun indication");
        pcm=1; valid=1; repeat(3) @(negedge clk); valid=0;
        if(!over) $fatal(1,"missing overrun indication");
        $display("PASS tb_i2s: independent decoder, MSB delay, 32-bit slots, signed stereo, rates, underrun/overrun");
        $finish;
    end
    initial begin #1000000; $fatal(1,"timeout"); end
endmodule
