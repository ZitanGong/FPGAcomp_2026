`timescale 1ns/1ps
module tb_div;
    reg clk=0,rst=1,go=0;
    always #5 clk=~clk;
    reg [15:0] num=0,den=1;
    wire [15:0] q,r;
    wire busy,done;
    div16 dut(clk,rst,go,num,den,q,r,busy,done);
    integer i,d;
    initial begin
        repeat(4) @(negedge clk); rst=0;
        for(i=0;i<1000;i++) begin
            @(negedge clk); num=$random; den=i<2 ? i : $random;
            d=den==0 ? 1 : den; go=1;
            @(negedge clk); go=0;
            @(posedge done); #1;
            if(q!==num/d || r!==num%d || busy) $fatal(1,"division %0d / %0d",num,d);
        end
        $display("PASS tb_div: 1000 divider vectors including 0/1 denominator"); $finish;
    end
    initial begin #300000; $fatal(1,"timeout"); end
endmodule
