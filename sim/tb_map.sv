`timescale 1ns/1ps
module tb_map;
    reg [20:0] phys=0;
    wire [20:0] keys;
    integer i;
    integer sw[0:20];
    key_map dut(phys,keys);
    initial begin
        sw[0]=5; sw[1]=6; sw[2]=7; sw[3]=1; sw[4]=2; sw[5]=3; sw[6]=4;
        sw[7]=12; sw[8]=13; sw[9]=14; sw[10]=8; sw[11]=9; sw[12]=10; sw[13]=11;
        sw[14]=19; sw[15]=20; sw[16]=21; sw[17]=15; sw[18]=16; sw[19]=17; sw[20]=18;
        for(i=0;i<21;i=i+1) begin
            phys=21'b1<<(sw[i]-1); #1;
            if(keys!==(21'b1<<i)) $fatal(1,"note %0d expected SW%0d, keys=%h",i,sw[i],keys);
        end
        phys=21'h1fffff; #1;
        if(keys!==21'h1fffff) $fatal(1,"all-key mapping");
        $display("PASS tb_map: Do-Si rows SW5,6,7,1,2,3,4 / SW12,13,14,8,9,10,11 / SW19,20,21,15,16,17,18");
        $finish;
    end
endmodule
