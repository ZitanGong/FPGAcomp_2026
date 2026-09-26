module synth21 #(
    parameter FILE = "rom/sine4k.hex",
    parameter NOTES = "rom/notes.hex",
    parameter SHIFT = 5, parameter GAIN=1
)(
    input clk, input rst, input ce, input [20:0] keys,
    input cfg_we, input [4:0] cfg_idx, input [31:0] cfg_fcw,
    input [15:0] a_n, input [15:0] d_n,
    input [15:0] s_lv, input [15:0] r_n,
    output signed [15:0] pcm, output valid, output clip
);
    reg [31:0] init_fcw [0:20];
    reg [31:0] fcw [0:20];
    wire [335:0] voices;
    wire [20:0] vv;
    initial $readmemh(NOTES,init_fcw);
    integer i;
    always @(posedge clk) begin
        if(rst) for(i=0;i<21;i=i+1) fcw[i]<=init_fcw[i];
        else if(cfg_we && cfg_idx<21) fcw[cfg_idx]<=cfg_fcw;
    end
    genvar g;
    generate for(g=0;g<21;g=g+1) begin: V
        voice #(.FILE(FILE)) u_voice(
            clk,rst,ce,keys[g],fcw[g],a_n,d_n,s_lv,r_n,
            voices[g*16 +: 16],vv[g]);
    end endgenerate
    mix21 #(.SHIFT(SHIFT),.GAIN(GAIN)) u_mix(clk,rst,vv[0],voices,pcm,valid,clip);
endmodule
