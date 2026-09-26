module voice #(parameter FILE = "rom/sine4k.hex")(
    input clk, input rst, input ce, input gate,
    input [31:0] fcw,
    input [15:0] a_n, input [15:0] d_n,
    input [15:0] s_lv, input [15:0] r_n,
    output reg signed [15:0] pcm,
    output reg valid
);
    (* syn_preserve = 1 *) reg [31:0] phase;
    wire [15:0] env;
    wire [2:0] state;
    wire signed [15:0] wave;
    reg [15:0] amp;
    reg [2:0] v;
    reg signed [32:0] prod /* synthesis syn_dspstyle="dsp" */;
    wire signed [32:0] rounded=prod+33'sd32768-(prod[32] ? 33'sd1 : 33'sd0);
    adsr u_env(clk,rst,ce,gate,a_n,d_n,s_lv,r_n,env,state);
    sine_rom #(.FILE(FILE),.AW(12)) u_rom(clk,v[0],phase[31:20],wave);
    always @(posedge clk) begin
        if (rst) begin
            phase<=0; amp<=0; prod<=0; pcm<=0; v<=0; valid<=0;
        end else begin
            v <= {v[1:0],ce}; valid<=v[2];
            if (ce) phase <= phase + fcw;
            if (v[0]) amp <= env;
            if (v[1]) prod <= wave * $signed({1'b0,amp});
            if (v[2]) pcm <= rounded[31:16];
        end
    end
endmodule
