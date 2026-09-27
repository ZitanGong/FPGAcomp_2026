`timescale 1ns/1ps
module tb_core;
    reg clk=0,rst=1,test_en=0;
    always #10.172526 clk=~clk;
    reg [20:0] press=0;
    wire [2:0] din;
    wire shld,kclk,bclk,lrck,sd,mclk,valid,ce,fault;
    wire [20:0] keys;
    wire signed [15:0] pcm;
    audio_core dut(clk,rst,din,2'd0,3'd4,test_en,1'b0,5'd0,32'd0,
        shld,kclk,bclk,lrck,sd,mclk,keys,pcm,valid,ce,fault);
    hc165 a(shld,kclk,{1'b1,~press[6:0]},din[0]);
    hc165 b(shld,kclk,{1'b1,~press[13:7]},din[1]);
    hc165 c(shld,kclk,{1'b1,~press[20:14]},din[2]);
    integer cycles=0,start_cycle=0,max_delay=0,frames=0,bitno=-1;
    time t_press,t_key,t_audio=0;
    reg prev_lr=1;
    reg [15:0] expect_pcm=0,rx=0,next_pcm=0;
    always @(posedge clk) begin
        cycles++;
        if(!rst && ce) start_cycle=cycles;
        #0.001;
        if(!rst && valid) begin
            if(cycles-start_cycle!=11) $fatal(1,"sample deadline %0d",cycles-start_cycle);
            max_delay=cycles-start_cycle; next_pcm=pcm;
        end
        if(!rst && fault) $fatal(1,"integrated fault");
    end
    always @(posedge bclk) if(!rst) begin
        if(lrck!==prev_lr) begin
            bitno=0; rx=0;
            if(!lrck) begin expect_pcm=next_pcm; frames++; end
        end else begin
            bitno++;
            if(bitno>=1 && bitno<=16) rx={rx[14:0],sd};
            if(bitno==16) begin
                if(rx!==expect_pcm) $fatal(1,"integration I2S %h expected %h",rx,expect_pcm);
                if(rx!=0 && t_audio==0 && press!=0) t_audio=$time;
            end
        end
        prev_lr=lrck;
    end
    initial begin
        repeat(10) @(negedge clk); rst=0;
        @(posedge shld); #1000; press=21'h100a01; t_press=$time;
        wait(keys==press); t_key=$time;
        wait(t_audio!=0);
        if(t_audio-t_press>3200000) $fatal(1,"digital latency >3.2ms");
        $display("Digital latency: key=%0d ns, first complete I2S word=%0d ns",t_key-t_press,t_audio-t_press);
        repeat(300) @(posedge ce);
        press=0; wait(keys==0);
        repeat(30) @(posedge ce);
        test_en=1; repeat(100) @(posedge ce);
        if(dut.gates!=21'h022110) $fatal(1,"four-tone mode");
        test_en=0; repeat(4900) @(posedge ce);
        if(pcm!=0) $fatal(1,"release did not end");
        $display("PASS tb_core: %0d frames, real dividers, keyboard-to-I2S, sample latency %0d/1024 cycles",frames,max_delay);
        $finish;
    end
    initial begin #150000000; $fatal(1,"timeout"); end
endmodule
