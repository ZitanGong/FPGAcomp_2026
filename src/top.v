module top #(
    parameter GAIN=3, parameter SHIFT=6,
    parameter DB_N=3,
    parameter A_N=51, parameter D_N=2563,
    parameter S_LV=32768, parameter R_N=5127
)(
    input rst_n, input test_n, input [2:0] key_in,
    output shld, output key_clk,
    output hp_bclk, output hp_ws, output hp_sd, output pa_n,
    output dbg_frame, output dbg_key, output dbg_err,
    output dbg_ref, output dbg_lock, output dbg_rst
);
    wire clk,rst,ce,valid,fault;
    wire [20:0] keys;
    wire signed [15:0] pcm;
    reg [9:0] ref_div=0;
    (* syn_preserve = 1 *) reg [1:0] ts;
    reg frame;
    OSC #(.FREQ_DIV(4)) u_osc(.OSCOUT(clk));
    reset_sync u_rst(clk,rst_n,1'b1,rst);
    always @(posedge clk) begin
        if(rst) begin ts<=3; frame<=0; ref_div<=0; end
        else begin
            ts<={ts[0],test_n};
            ref_div<=ref_div+1'b1;
            if(ce) frame<=~frame;
        end
    end
    audio_core #(.CLK_HZ(52500000),.PT_MODE(1),.NOTES("rom/notes.hex"),
        .GAIN(GAIN),.SHIFT(SHIFT),.DB_N(DB_N),
        .A_N(A_N),.D_N(D_N),.S_LV(S_LV),.R_N(R_N)) u_core(
        .clk(clk),.rst(rst),.key_in(key_in),.test_en(~ts[1]),
        .cfg_we(1'b0),.cfg_idx(5'd0),.cfg_fcw(32'd0),
        .shld(shld),.key_clk(key_clk),.bclk(hp_bclk),.lrck(hp_ws),.sd(hp_sd),
        .mclk(),.keys(keys),.pcm(pcm),.valid(valid),.ce(ce),.fault(fault));
    assign pa_n=rst;
    assign dbg_frame=frame;
    assign dbg_key=|keys;
    assign dbg_err=fault;
    assign dbg_ref=ref_div[9];
    assign dbg_lock=1'b1;
    assign dbg_rst=rst;
endmodule
