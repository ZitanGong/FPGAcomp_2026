`timescale 1ns/1ps
module tb_synth;
    reg clk=0,rst=1,ce=0,we=0;
    always #5 clk=~clk;
    reg [20:0] keys=21'h022110;
    reg [4:0] idx=0;
    reg [31:0] val=0;
    wire signed [15:0] pcm;
    wire valid,clip;
    synth21 dut(clk,rst,ce,keys,2'd0,3'd4,we,idx,val,16'd0,16'd0,16'd65535,16'd0,pcm,valid,clip);
    reg [31:0] words[0:20];
    reg [31:0] ph[0:20];
    integer exp_voice[0:20];
    integer note_gain[0:20];
    integer i,n,fd,sum,expected,count=0;
    real sw;
    integer romval;
    time start_at;
    genvar g;
    generate for(g=0;g<21;g=g+1) begin: CHECK
        always @(posedge dut.vv[g]) begin
            #1;
            if($signed(dut.voices[g*16 +:16]) !== exp_voice[g])
                $fatal(1,"voice %0d result %0d expected %0d",g,$signed(dut.voices[g*16 +:16]),exp_voice[g]);
            if(dut.V[g].u_voice.phase !== ph[g]) $fatal(1,"independent phase %0d",g);
        end
    end endgenerate
    task sample;
        begin
            @(negedge clk);
            sum=0;
            for(i=0;i<21;i++) begin
                ph[i]=ph[i]+words[i];
                sw=32767.0*$sin(6.283185307179586*$itor(ph[i][31:22])/1024.0);
                romval=$rtoi(sw>=0 ? sw+0.5 : sw-0.5);
                exp_voice[i]=keys[i] ? ((romval*((65535*note_gain[i]+16384) >>> 15)+32768-(romval<0 ? 1 : 0)) >>> 16) : 0;
                sum+=exp_voice[i];
            end
            expected=(sum+16-(sum<0 ? 1 : 0)) >>> 5;
            ce=1;
            @(posedge clk); start_at=$time;
            @(negedge clk); ce=0;
            @(posedge valid); #1;
            if($time-start_at!=111 || pcm!==expected[15:0] || clip)
                $fatal(1,"mix/deadline got=%d expected=%d elapsed=%0t",pcm,expected,$time-start_at);
            count++;
            repeat(54) @(negedge clk);
        end
    endtask
    initial begin
        $readmemh("rom/notes.hex",words);
        note_gain[4]=32768; note_gain[5]=32768; note_gain[6]=32768;
        note_gain[0]=32768; note_gain[1]=32768; note_gain[2]=32768; note_gain[3]=32768;
        note_gain[11]=18022; note_gain[12]=17564; note_gain[13]=17105;
        note_gain[7]=16646; note_gain[8]=16187; note_gain[9]=15729; note_gain[10]=15073;
        note_gain[18]=13435; note_gain[19]=12911; note_gain[20]=12386;
        note_gain[14]=11862; note_gain[15]=11338; note_gain[16]=10813; note_gain[17]=10158;
        for(i=0;i<21;i++) ph[i]=0;
        fd=$fopen("reports/four_tones.txt","w");
        if(!fd) $fatal(1,"audio file");
        repeat(4) @(negedge clk); rst=0;
        for(n=0;n<48000;n++) begin sample(); $fdisplay(fd,"%0d",pcm); end
        $fclose(fd);
        keys=21'h1fffff; repeat(200) sample();
        keys=0; repeat(3) sample();
        keys=21'h1fffff;
        @(negedge clk); idx=12; val=32'd59055800; we=1;
        @(negedge clk); we=0; words[12]=val;
        repeat(200) sample();
        @(negedge clk); idx=31; val=0; we=1;
        @(negedge clk); we=0;
        repeat(10) sample();
        $display("PASS tb_synth: %0d samples, 21 parallel phases/ROM/products, live FCW, 11-cycle deadline, four-tone dump",count);
        $finish;
    end
    initial begin #40000000; $fatal(1,"timeout"); end
endmodule
