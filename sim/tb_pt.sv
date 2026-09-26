`timescale 1ns/1ps
module tb_pt;
    reg clk=0,rst=1,valid=0,feed=1,check_rx=1;
    always #5 clk=~clk;
    reg [15:0] pcm=0,next_pcm=0,expected=0;
    reg [8:0] pipe=0;
    wire bclk,ws,sd,ce,under,over;
    pt8211_tx dut(clk,rst,pcm,valid,bclk,ws,sd,ce,under,over);
    reg prev=1;
    reg [15:0] rx=0;
    integer bits=-1,words=0;
    integer n=0;
    time last_rise=0,last_change=0;
    always @(posedge bclk) if(!rst) begin
        if(last_rise && $time-last_rise!=320) $fatal(1,"PT BCLK period");
        if(last_change && $time-last_change<160) $fatal(1,"PT setup half-cycle");
        last_rise=$time;
    end
    always @(sd or ws) if(!rst && $time>100) begin
        if(last_rise && $time-last_rise<160) $fatal(1,"PT hold half-cycle");
        last_change=$time;
    end
    always @(posedge clk) begin
        if(rst) begin pipe<=0; valid<=0; pcm<=0; n<=0; next_pcm<=0; end
        else begin
            pipe<={pipe[7:0],ce};
            valid<=pipe[8] && feed;
            if(pipe[8] && feed) begin
                case(n)
                    0: pcm<=16'h8000;
                    1: pcm<=16'h7fff;
                    2: pcm<=16'hffff;
                    3: pcm<=16'h0001;
                    default: pcm<=$random;
                endcase
                n<=n+1;
            end
            if(valid) next_pcm<=pcm;
        end
    end
    always @(posedge bclk) if(!rst) begin
        if(ws!=prev) begin
            if(bits>=0 && bits!=16) $fatal(1,"PT slot");
            bits=1; rx={15'd0,sd};
            if(!ws) expected=next_pcm;
        end else begin bits++; rx={rx[14:0],sd}; end
        if(bits==16) begin
            words++;
            if(check_rx && rx!==expected) $fatal(1,"PT word %h expected %h",rx,expected);
        end
        prev=ws;
    end
    initial begin
        repeat(4) @(negedge clk); rst=0;
        wait(words==200);
        if(under || over) $fatal(1,"PT unexpected buffer fault");
        feed=0; check_rx=0;
        repeat(3) @(posedge ce);
        if(!under) $fatal(1,"PT underrun missing");
        @(negedge clk); force valid=1;
        repeat(3) @(negedge clk);
        release valid;
        if(!over) $fatal(1,"PT overrun missing");
        rst=1; repeat(2) @(negedge clk);
        if(under || over) $fatal(1,"PT error reset");
        $display("PASS tb_pt: randomized LSBJ stereo, frame request, underrun/overrun/reset"); $finish;
    end
    always @(sd or ws) if(!rst && $time>100 && bclk!==0) $fatal(1,"PT changed away from falling edge");
    initial begin #2000000; $fatal(1,"timeout"); end
endmodule
