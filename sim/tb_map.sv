`timescale 1ns/1ps
module tb_map;
    reg [31:0] notes[0:20];
    reg [31:0] exp[0:20];
    integer i;
    initial begin
        $readmemh("rom/notes.hex",notes);
        exp[0]=32'h00df33f5; exp[1]=32'h00fa896e; exp[2]=32'h011937d5;
        exp[3]=32'h013ba81a; exp[4]=32'h00a7369a; exp[5]=32'h00bbb0c9;
        exp[6]=32'h00d2acf0; exp[7]=32'h01be67e9; exp[8]=32'h01f512dd;
        exp[9]=32'h02326faa; exp[10]=32'h02775033; exp[11]=32'h014e6d33;
        exp[12]=32'h01776191; exp[13]=32'h01a559df; exp[14]=32'h037ccfd2;
        exp[15]=32'h03ea25ba; exp[16]=32'h0464df55; exp[17]=32'h04eea066;
        exp[18]=32'h029cda66; exp[19]=32'h02eec323; exp[20]=32'h034ab3bf;
        for(i=0;i<21;i=i+1)
            if(notes[i]!==exp[i]) $fatal(1,"SW%0d FCW=%h expected=%h",i+1,notes[i],exp[i]);
        $display("PASS tb_map: frequency table only; Do-Si SW5,6,7,1,2,3,4 / SW12,13,14,8,9,10,11 / SW19,20,21,15,16,17,18");
        $finish;
    end
endmodule
