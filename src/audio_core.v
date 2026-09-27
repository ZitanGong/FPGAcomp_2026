module audio_core #(
    parameter CLK_HZ=49152000, parameter PT_MODE=0,
    parameter NOTES="rom/notes.hex",
    parameter SHIFT=5, parameter GAIN=1,
    parameter DB_N=3,
    parameter A_N=48, parameter D_N=2400,
    parameter S_LV=32768, parameter R_N=4800
)(
    input clk, input rst, input [2:0] key_in,
    input [1:0] timbre, input [2:0] volume, input test_en,
    input cfg_we, input [4:0] cfg_idx, input [31:0] cfg_fcw,
    output shld, output key_clk,
    output bclk, output lrck, output sd, output mclk,
    output [20:0] keys,
    output signed [15:0] pcm, output valid, output ce,
    output reg fault
);
    wire [20:0] raw;
    wire done, good, clip, under, over;
    wire [20:0] gates = test_en ? 21'h022110 : keys;
    reg [15:0] a_cfg, d_cfg, s_cfg, r_cfg;

    // Instrument-specific amplitude envelopes. Durations are audio samples.
    always @* begin
        a_cfg=A_N[15:0]; d_cfg=D_N[15:0];
        s_cfg=S_LV[15:0]; r_cfg=R_N[15:0];
        case(timbre)
            2'd1: begin // organ: fast attack, full sustain
                a_cfg=16'd256; d_cfg=16'd0;
                s_cfg=16'd65535; r_cfg=16'd5127;
            end
            2'd2: begin // Karplus-Strong owns its excitation and loop decay
                a_cfg=16'd0; d_cfg=16'd0;
                s_cfg=16'd65535; r_cfg=16'd0;
            end
            2'd3: begin // voice.v owns the piano's two-stage modal decay
                a_cfg=16'd0; d_cfg=16'd0;
                s_cfg=16'd65535; r_cfg=16'd0;
            end
        endcase
    end
    scan165 #(.CLK_HZ(CLK_HZ)) u_scan(clk,rst,key_in,shld,key_clk,raw,done,good);
    key_filter u_filter(clk,rst,done,good,raw,DB_N[7:0],keys);
    synth21 #(.NOTES(NOTES),.SHIFT(SHIFT),.GAIN(GAIN)) u_synth(
        .clk(clk),.rst(rst),.ce(ce),.keys(gates),.timbre(timbre),.volume(volume),
        .cfg_we(cfg_we),.cfg_idx(cfg_idx),.cfg_fcw(cfg_fcw),
        .a_n(a_cfg),.d_n(d_cfg),.s_lv(s_cfg),.r_n(r_cfg),
        .pcm(pcm),.valid(valid),.clip(clip));
    generate if (PT_MODE) begin: PT
        pt8211_tx u_tx(clk,rst,pcm,valid,bclk,lrck,sd,ce,under,over);
        assign mclk=1'b0;
    end else begin: I2S
        i2s_tx u_tx(clk,rst,pcm,valid,ce,bclk,lrck,sd,mclk,under,over);
    end endgenerate
    always @(posedge clk) begin
        if(rst) fault<=0;
        else if((done && !good) || under || over || clip) fault<=1;
    end
endmodule
