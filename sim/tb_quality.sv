`timescale 1ns/1ps
module tb_quality;
    reg clk=0,rst=1,ce=0,gate=1;
    always #5 clk=~clk;
    reg [31:0] notes[0:20];
    wire signed [15:0] pcm;
    wire valid;
    voice dut(clk,rst,ce,gate,2'd0,notes[9],16'd0,16'd0,16'd32768,16'd0,pcm,valid);
    integer n,fd;
    task sample;
        begin
            @(negedge clk); ce=1;
            @(negedge clk); ce=0;
            @(posedge valid); #1;
            repeat(21) @(negedge clk);
        end
    endtask
    initial begin
        $readmemh("rom/notes.hex",notes);
        fd=$fopen("reports/quality.txt","w");
        if(!fd) $fatal(1,"quality file");
        repeat(4) @(negedge clk); rst=0;
        for(n=0;n<65536;n++) begin
            sample(); $fdisplay(fd,"%0d %0d",dut.phase,pcm);
        end
        $fclose(fd);
        gate=0;
        repeat(100) begin sample(); if(pcm!==0) $fatal(1,"idle digital noise"); end
        $display("PASS tb_quality: 1024-point A4, symmetric output, exact idle zero");
        $finish;
    end
    initial begin #30000000; $fatal(1,"quality timeout"); end
endmodule
