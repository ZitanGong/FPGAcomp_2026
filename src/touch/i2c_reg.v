module i2c_reg #(
    parameter CLK_HZ=52500000, parameter BUS_HZ=100000,
    parameter WAIT_N=525000
)(
    input clk, input rst, input go, input rd,
    input [6:0] addr, input [7:0] reg_addr, input [7:0] wr_data,
    input [5:0] rd_len,
    inout scl, inout sda,
    output reg busy, output reg done, output reg err,
    output reg rx_v, output reg [5:0] rx_idx, output reg [7:0] rx_data
);
    localparam Q=(CLK_HZ+4*BUS_HZ-1)/(4*BUS_HZ);
    localparam IDLE=0, START=1, START_L=2, TX_L=3, TX_R=4, TX_H=5,
        ACK_L=6, ACK_R=7, ACK_H=8, ACK_F=9,
        REP_L=10, REP_R=11, REP_H=12,
        RX_L=13, RX_R=14, RX_H=15, MA_L=16, MA_R=17, MA_H=18, MA_F=19,
        STOP_L=20, STOP_R=21, STOP_H=22, STOP_F=23,
        CLR_L=24, CLR_R=25, CLR_H=26;
    reg [4:0] st;
    reg sl,dl;
    reg [1:0] sc,sd;
    reg [31:0] div,wd;
    reg [7:0] tx,rx,ra,dat;
    reg [6:0] dev;
    reg read_op,ack;
    reg [1:0] phase;
    reg [2:0] bit_n;
    reg [3:0] clear_n;
    reg [5:0] len;
    wire tick=(div==Q-1);
    wire wait_hi=(st==START || st==TX_R || st==ACK_R || st==REP_R ||
                  st==RX_R || st==MA_R || st==STOP_R || st==CLR_R);
    assign scl=sl ? 1'b0 : 1'bz;
    assign sda=dl ? 1'b0 : 1'bz;
    always @(posedge clk) begin
        if(rst) begin sc<=3; sd<=3; end
        else begin sc<={sc[0],scl}; sd<={sd[0],sda}; end
        if(rst) begin
            st<=IDLE; sl<=0; dl<=0; div<=0; wd<=0;
            busy<=0; done<=0; err<=0; rx_v<=0; rx_idx<=0; rx_data<=0;
            tx<=0; rx<=0; ra<=0; dat<=0; dev<=0; read_op<=0;
            ack<=0; phase<=0; bit_n<=7; clear_n<=0; len<=1;
        end else begin
            done<=0; rx_v<=0;
            if(tick) div<=0; else div<=div+1'b1;
            if(busy && wait_hi && !sc[1]) wd<=wd+1'b1; else wd<=0;
            if(busy && wd==WAIT_N-1) begin
                sl<=0; dl<=0; busy<=0; err<=1; done<=1; st<=IDLE; wd<=0;
            end else if(st==IDLE) begin
                if(go) begin
                    busy<=1; err<=0; rx_idx<=0; read_op<=rd;
                    dev<=addr; ra<=reg_addr; dat<=wr_data;
                    len<=(rd_len==0 ? 6'd1 : rd_len);
                    tx<={addr,1'b0}; phase<=0; bit_n<=7;
                    sl<=0; dl<=0; div<=0; st<=START;
                end
            end else if(tick) case(st)
                START: if(sc[1]) begin
                    if(sd[1]) begin dl<=1; st<=START_L; end
                    else begin clear_n<=0; err<=1; st<=CLR_L; end
                end
                START_L: begin sl<=1; st<=TX_L; end
                TX_L: begin dl<=~tx[bit_n]; st<=TX_R; end
                TX_R: begin sl<=0; if(sc[1]) st<=TX_H; end
                TX_H: begin
                    sl<=1;
                    if(bit_n==0) st<=ACK_L;
                    else begin bit_n<=bit_n-1'b1; st<=TX_L; end
                end
                ACK_L: begin dl<=0; st<=ACK_R; end
                ACK_R: begin sl<=0; if(sc[1]) begin ack<=!sd[1]; st<=ACK_H; end end
                ACK_H: begin sl<=1; st<=ACK_F; end
                ACK_F: begin
                    bit_n<=7;
                    if(!ack) begin err<=1; st<=STOP_L; end
                    else case(phase)
                        0: begin tx<=ra; phase<=1; st<=TX_L; end
                        1: if(read_op) st<=REP_L;
                           else begin tx<=dat; phase<=2; st<=TX_L; end
                        2: st<=STOP_L;
                        3: begin rx<=0; st<=RX_L; end
                    endcase
                end
                REP_L: begin dl<=0; st<=REP_R; end
                REP_R: begin sl<=0; if(sc[1]) st<=REP_H; end
                REP_H: begin dl<=1; tx<={dev,1'b1}; phase<=3; st<=START_L; end
                RX_L: begin dl<=0; st<=RX_R; end
                RX_R: begin sl<=0; if(sc[1]) begin rx<={rx[6:0],sd[1]}; st<=RX_H; end end
                RX_H: begin
                    sl<=1;
                    if(bit_n==0) st<=MA_L;
                    else begin bit_n<=bit_n-1'b1; st<=RX_L; end
                end
                MA_L: begin dl<=(rx_idx!=len-1'b1); st<=MA_R; end
                MA_R: begin sl<=0; if(sc[1]) st<=MA_H; end
                MA_H: begin sl<=1; st<=MA_F; end
                MA_F: begin
                    dl<=0; rx_data<=rx; rx_v<=1;
                    if(rx_idx==len-1'b1) st<=STOP_L;
                    else begin st<=RX_L; bit_n<=7; end
                end
                STOP_L: begin sl<=1; dl<=1; st<=STOP_R; end
                STOP_R: begin sl<=0; if(sc[1]) st<=STOP_H; end
                STOP_H: begin dl<=0; st<=STOP_F; end
                STOP_F: begin busy<=0; done<=1; st<=IDLE; end
                CLR_L: begin sl<=1; dl<=0; st<=CLR_R; end
                CLR_R: begin sl<=0; if(sc[1]) st<=CLR_H; end
                CLR_H: begin
                    sl<=1;
                    if(clear_n==8) st<=STOP_L;
                    else begin clear_n<=clear_n+1'b1; st<=CLR_L; end
                end
                default: st<=IDLE;
            endcase
            if(rx_v && st==RX_L) rx_idx<=rx_idx+1'b1;
        end
    end
endmodule
