`timescale 1ns/1ps
module tb_pt_core;
    reg clk=0,rst=1,test_en=0;
    always #10.172526 clk=~clk;
    reg [20:0] press=0;
    wire [2:0] din;
    wire shld,kclk,bclk,ws,sd,mclk,valid,ce,fault;
    wire [20:0] keys;
    wire signed [15:0] pcm;
    audio_core #(.PT_MODE(1)) dut(clk,rst,din,2'd0,3'd4,test_en,1'b0,5'd0,32'd0,
        shld,kclk,bclk,ws,sd,mclk,keys,pcm,valid,ce,fault);
    hc165 a(shld,kclk,{1'b1,~press[6:0]},din[0]);
    hc165 b(shld,kclk,{1'b1,~press[13:7]},din[1]);
    hc165 c(shld,kclk,{1'b1,~press[20:14]},din[2]);
    integer cycles=0,start_cycle=0,last_ce=0,frames=0,bits=-1;
    time t_press,t_audio=0;
    reg prev_ws=1;
    reg [15:0] expect_pcm=0,rx=0,next_pcm=0;
    always @(posedge clk) begin
        cycles++;
        if(!rst && ce) begin
            if(last_ce && cycles-last_ce!=1024) $fatal(1,"PT sample period");
            last_ce=cycles; start_cycle=cycles;
        end
        #0.001;
        if(!rst && valid) begin
            if(cycles-start_cycle!=11) $fatal(1,"PT deadline");
            next_pcm=pcm;
        end
        if(!rst && fault) $fatal(1,"PT core fault");
        if(mclk!==0) $fatal(1,"I2S MCLK active in PT mode");
    end
    always @(posedge bclk) if(!rst) begin
        if(ws!==prev_ws) begin
            if(bits>=0 && bits!=16) $fatal(1,"PT word length");
            bits=1; rx={15'd0,sd};
            if(!ws) begin expect_pcm=next_pcm; frames++; end
        end else begin bits++; rx={rx[14:0],sd}; end
        if(bits==16) begin
            if(rx!==expect_pcm) $fatal(1,"PT PCM %h expected %h",rx,expect_pcm);
            if(rx!=0 && t_audio==0 && press!=0) t_audio=$time;
        end
        prev_ws=ws;
    end
    initial begin
        repeat(10) @(negedge clk); rst=0;
        @(posedge shld); #1000; press=21'h100a01; t_press=$time;
        wait(keys==press); wait(t_audio!=0);
        if(t_audio-t_press>3300000) $fatal(1,"PT digital latency");
        $display("PT digital latency: %0d ns",t_audio-t_press);
        repeat(300) @(posedge ce);
        press=0; wait(keys==0); repeat(30) @(posedge ce);
        press=21'h100a01; wait(keys==press);
        repeat(100) @(posedge ce);
        press=21'h1fffff; wait(keys==press);
        repeat(100) @(posedge ce);
        press=0; wait(keys==0);
        test_en=1; repeat(100) @(posedge ce);
        if(dut.gates!=21'h022110) $fatal(1,"PT test key");
        test_en=0; repeat(4900) @(posedge ce);
        if(pcm!=0) $fatal(1,"PT release did not end");
        $display("PASS tb_pt_core: %0d frames, keyboard/chord/retrigger/test key, 11/1024-cycle deadline",frames);
        $finish;
    end
    initial begin #180000000; $fatal(1,"PT core timeout"); end
endmodule
