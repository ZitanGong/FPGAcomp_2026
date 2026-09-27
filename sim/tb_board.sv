`timescale 1ns/1ps
module tb_board;
    reg key0_n=1,key1_n=1,key2_n=1;
    reg [20:0] press=0;
    wire [2:0] din;
    wire shld,kclk,bc,ws,sd,pa,df,dk,de,dr,dl,ds;
    top dut(.key0_n(key0_n),.key1_n(key1_n),.key2_n(key2_n),.key_in(din),
        .shld(shld),.key_clk(kclk),.hp_bclk(bc),.hp_ws(ws),.hp_sd(sd),.pa_n(pa),
        .dbg_frame(df),.dbg_key(dk),.dbg_err(de),.dbg_ref(dr),.dbg_lock(dl),.dbg_rst(ds));
    hc165 a(shld,kclk,{1'b1,~press[6:0]},din[0]);
    hc165 b(shld,kclk,{1'b1,~press[13:7]},din[1]);
    hc165 c(shld,kclk,{1'b1,~press[20:14]},din[2]);
    reg prev=1;
    reg [15:0] rx=0,word0=0,next_pcm=0,expected=0;
    integer bits=-1,nonzero=0,cycles=0,start_cycle=0;
    time tpress,taudio=0;
    real t,period;
    always @(posedge dut.clk) begin
        cycles++;
        if(!pa && dut.ce) start_cycle=cycles;
        #0.001;
        if(pa) next_pcm=0;
        if(!pa && dut.valid) begin
            if(cycles-start_cycle!=11) $fatal(1,"board deadline");
            next_pcm=dut.pcm;
        end
        if(!pa && de) $fatal(1,"board fault");
    end
    always @(posedge bc or posedge pa) if(pa) begin
        prev=1; bits=-1; rx=0; word0=0; expected=0;
    end else begin
        if(ws!=prev) begin
            if(bits>=0 && bits!=16) $fatal(1,"board word length");
            bits=1; rx={15'd0,sd};
            if(!ws) expected=next_pcm;
        end else begin bits++; rx={rx[14:0],sd}; end
        if(bits==16) begin
            if(rx!==expected) $fatal(1,"board PCM mismatch");
            if(!ws) word0=rx;
            else if(rx!==word0) $fatal(1,"board stereo mismatch");
            if(rx!=0) begin
                nonzero++;
                if(press!=0 && taudio==0) taudio=$time;
            end
        end
        prev=ws;
    end
    initial begin
        wait(!pa);
        if(dl!==1) $fatal(1,"OSC ready flag");
        @(negedge ws); t=$realtime; @(negedge ws);
        period=$realtime-t;
        if(period<19504 || period>19506) $fatal(1,"nominal frame rate %f",period);
        repeat(10) @(negedge ws);
        if(nonzero!=0) $fatal(1,"idle noise");
        @(posedge shld); #1000; press=21'h100a01; tpress=$time;
        wait(dk); wait(taudio!=0);
        if(taudio-tpress>3300000) $fatal(1,"board keyboard latency");
        repeat(150) @(negedge ws);
        if(dut.keys!=press || nonzero<100) $fatal(1,"keyboard chord");
        press=21'h1fffff; wait(dut.keys==press); repeat(200) @(negedge ws);
        press=0; wait(!dk); repeat(100) @(negedge ws);
        press=1; wait(dk); repeat(100) @(negedge ws);
        press=0; wait(!dk); repeat(5139) @(negedge ws);
        if(dut.pcm!=0) $fatal(1,"release not silent");
        nonzero=0; repeat(100) @(negedge ws);
        if(nonzero) $fatal(1,"serial idle noise");
        key0_n=0; repeat(600) @(negedge ws);
        if(dut.timbre!=2'd1) $fatal(1,"KEY0 timbre select");
        key0_n=1; repeat(600) @(negedge ws);
        if(dut.timbre!=2'd1) $fatal(1,"KEY0 release changed timbre");
        key1_n=0; repeat(600) @(negedge ws); key1_n=1; repeat(600) @(negedge ws);
        if(dut.volume!=3'd4) $fatal(1,"KEY1 volume down");
        key2_n=0; repeat(600) @(negedge ws); key2_n=1; repeat(600) @(negedge ws);
        if(dut.volume!=3'd5) $fatal(1,"KEY2 volume up");
        $display("PASS tb_board: POR, PT8211, keyboard/all keys/retrigger/timbre/volume keys, zero idle, stereo and deadline; latency=%0d ns",taudio-tpress);
        $finish;
    end
    initial begin #250000000; $fatal(1,"board timeout"); end
endmodule
