`timescale 1ns/1ps
module mpr_model(inout scl,inout sda,input present);
    reg low=0;
    reg [7:0] mem[0:127];
    reg [7:0] rx=0,ptr=0,tx=0;
    integer phase=0,n=0,i;
    reg ack=0,reading=0,master_ack=0;
    integer writes=0,reads=0,starts=0,stops=0,nacks=0;
    assign sda=low ? 1'b0 : 1'bz;
    initial for(i=0;i<128;i=i+1) mem[i]=0;
    always @(negedge sda) if(scl===1'b1) begin
        phase=0; n=0; rx=0; reading=0; ack=0; starts=starts+1;
    end
    always @(posedge sda) if(scl===1'b1) begin
        phase=4; n=0; reading=0; stops=stops+1;
    end
    always @(posedge scl) begin
        if(phase!=4) begin
            if(n<8) begin
                if(!reading) rx={rx[6:0],sda};
                n=n+1;
                if(n==8 && !reading) begin
                    ack=present;
                    if(phase==0) ack=present && rx[7:1]==7'h5a;
                    if(ack && phase==1) ptr=rx;
                    if(ack && phase==2) begin
                        if(ptr==8'h80 && rx==8'h63) begin
                            for(i=0;i<128;i=i+1) mem[i]=0;
                        end else if(ptr<128) mem[ptr]=rx;
                        ptr=ptr+1'b1; writes=writes+1;
                    end
                end
            end else begin
                if(reading) begin
                    master_ack=!sda; reads=reads+1;
                    if(sda) nacks=nacks+1;
                end
                n=9;
            end
        end
    end
    always @(negedge scl) begin
        if(phase!=4) begin
            if(n==8) low=reading ? 0 : ack;
            else if(n==9) begin
                low=0; n=0;
                if(reading) begin
                    ptr=ptr+1'b1;
                    if(master_ack) begin tx=mem[ptr]; low=~tx[7]; end
                    else begin phase=4; reading=0; end
                end else if(!ack) phase=4;
                else if(phase==0 && rx[0]) begin
                    phase=3; reading=1; tx=mem[ptr]; low=~tx[7];
                end else if(phase==0) phase=1;
                else if(phase==1) phase=2;
            end else if(reading) low=~tx[7-n];
        end else low=0;
    end
endmodule
