module mpr121 #(
    parameter CLK_HZ=52500000, parameter BUS_HZ=350000, parameter FIRST=0,
    parameter BOOT_N=CLK_HZ/10, parameter RESET_N=CLK_HZ/500,
    parameter SETTLE_N=CLK_HZ/50, parameter POLL_N=CLK_HZ/500,
    parameter RETRY_N=CLK_HZ/10, parameter WAIT_N=CLK_HZ/100,
    parameter [6:0] ADDR=7'h5a,
    parameter [7:0] TOUCH_TH=12, parameter [7:0] RELEASE_TH=6
)(
    input clk, input rst, input irq_n, inout scl, inout sda,
    output reg [7:0] touch,
    output [79:0] filt, output [79:0] base,
    output reg valid, output reg ready, output reg fault
);
    localparam [7:0] ECR=8'h88+FIRST;
    localparam DELAY=0, INIT=1, INIT_WAIT=2, CHECK=3, CHECK_WAIT=4,
        RUN=5, READ_WAIT=6;
    reg [2:0] st,next_st;
    reg [31:0] delay_n,poll_n;
    reg [5:0] idx;
    reg [1:0] irq;
    reg go,rd;
    reg [7:0] ra,wd;
    reg [5:0] len;
    wire done,err,rx_v;
    wire [5:0] rx_idx;
    wire [7:0] rx_data;
    reg [7:0] buf_data [0:38];
    reg [15:0] cfg;
    wire [11:0] raw_touch={buf_data[1][3:0],buf_data[0]};
    integer j;
    genvar k;
    generate for(k=0;k<8;k=k+1) begin: g_data
        assign filt[k*10+:10]={buf_data[5+2*(k+FIRST)][1:0],buf_data[4+2*(k+FIRST)]};
        assign base[k*10+:10]={buf_data[30+k+FIRST],2'b00};
    end endgenerate
    i2c_reg #(.CLK_HZ(CLK_HZ),.BUS_HZ(BUS_HZ),.WAIT_N(WAIT_N)) u_bus(
        .clk(clk),.rst(rst),.go(go),.rd(rd),.addr(ADDR),.reg_addr(ra),
        .wr_data(wd),.rd_len(len),.scl(scl),.sda(sda),.busy(),
        .done(done),.err(err),.rx_v(rx_v),.rx_idx(rx_idx),.rx_data(rx_data));
    always @* begin
        cfg={8'h5e,ECR};
        case(idx)
            0: cfg=16'h8063;
            1: cfg=16'h5e00;
            2: cfg=16'h2b01;
            3: cfg=16'h2c01;
            4: cfg=16'h2d0e;
            5: cfg=16'h2e00;
            6: cfg=16'h2f01;
            7: cfg=16'h3005;
            8: cfg=16'h3101;
            9: cfg=16'h3200;
            10: cfg=16'h3300;
            11: cfg=16'h3400;
            12: cfg=16'h3500;
            31: cfg=16'h5b01;
            32: cfg=16'h5c10;
            33: cfg=16'h5d20;
            34: cfg={8'h5e,ECR};
            default: begin
                cfg[15:8]=8'h41+(idx-6'd13);
                if(((idx-13)/2)<FIRST || ((idx-13)/2)>=FIRST+8)
                    cfg[7:0]=idx[0] ? 8'hff : 8'hfe;
                else cfg[7:0]=idx[0] ? TOUCH_TH : RELEASE_TH;
            end
        endcase
    end
    always @(posedge clk) begin
        if(rst) irq<=3; else irq<={irq[0],irq_n};
        if(rst) begin
            st<=DELAY; next_st<=INIT; delay_n<=BOOT_N; poll_n<=0;
            idx<=0; go<=0; rd<=0; ra<=0; wd<=0; len<=1;
            touch<=0; valid<=0; ready<=0; fault<=0;
            for(j=0;j<39;j=j+1) buf_data[j]<=0;
        end else begin
            go<=0; valid<=0;
            if(poll_n!=0) poll_n<=poll_n-1'b1;
            if(rx_v && rx_idx<39) buf_data[rx_idx]<=rx_data;
            if(done && (err || (st==CHECK_WAIT && buf_data[0]!=ECR) ||
                       (st==READ_WAIT && buf_data[1][7]))) begin
                touch<=0; valid<=1; ready<=0; fault<=1;
                idx<=0; st<=DELAY; next_st<=INIT; delay_n<=RETRY_N;
            end else case(st)
                DELAY: if(delay_n!=0) delay_n<=delay_n-1'b1; else st<=next_st;
                INIT: begin
                    ra<=cfg[15:8]; wd<=cfg[7:0]; rd<=0; len<=1;
                    go<=1; st<=INIT_WAIT;
                end
                INIT_WAIT: if(done) begin
                    if(idx==0) begin
                        idx<=1; delay_n<=RESET_N; next_st<=INIT; st<=DELAY;
                    end else if(idx==34) st<=CHECK;
                    else begin idx<=idx+1'b1; st<=INIT; end
                end
                CHECK: begin ra<=8'h5e; len<=1; rd<=1; go<=1; st<=CHECK_WAIT; end
                CHECK_WAIT: if(done) begin
                    if(ready) st<=RUN;
                    else begin
                        delay_n<=SETTLE_N; next_st<=RUN; st<=DELAY;
                        ready<=1; fault<=0; poll_n<=0;
                    end
                end
                RUN: if(poll_n==0 || !irq[1]) begin
                    ra<=0; len<=39; rd<=1; go<=1; st<=READ_WAIT; poll_n<=POLL_N;
                end
                READ_WAIT: if(done) begin
                    touch<=raw_touch[FIRST+:8];
                    valid<=1; st<=CHECK;
                end
                default: st<=DELAY;
            endcase
        end
    end
endmodule
