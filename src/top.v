module top #(
    parameter GAIN=3, parameter SHIFT=6,
    parameter DB_N=3,
    parameter A_N=51, parameter D_N=2563,
    parameter S_LV=32768, parameter R_N=5127,
    parameter TOUCH_TH=12, parameter RELEASE_TH=6, parameter LED_REV=0,
    parameter TOUCH_FIRST=0, parameter TOUCH_HZ=350000
)(
    input key0_n, input key1_n, input key2_n, input [2:0] key_in,
    output shld, output key_clk,
    output hp_bclk, output hp_ws, output hp_sd, output pa_n,
    output dbg_frame, output dbg_key, output dbg_err,
    output dbg_ref, output dbg_lock, output dbg_rst,
    inout touch_scl, inout touch_sda, input touch_irq_n,
    output led_data, output led_clk, output led_lat
);
    wire clk,ce,valid,fault;
    wire touch_fault;
    wire [20:0] keys;
    wire signed [15:0] pcm;
    reg [9:0] ref_div=0;
    reg [1:0] timbre;
    reg [2:0] volume;
    reg [15:0] por=16'hffff;
    reg frame;
    wire rst=|por;
    wire timbre_press,volume_down_press,volume_up_press;
    OSC #(.FREQ_DIV(4)) u_osc(.OSCOUT(clk));
    button_debounce #(.COUNT(525000)) u_key0(clk,rst,key0_n,timbre_press);
    button_debounce #(.COUNT(525000)) u_key1(clk,rst,key1_n,volume_down_press);
    button_debounce #(.COUNT(525000)) u_key2(clk,rst,key2_n,volume_up_press);
    always @(posedge clk) begin
        if(rst) por<=por-1'b1;
        if(rst) begin
            timbre<=0; volume<=3'd5; frame<=0; ref_div<=0;
        end
        else begin
            if(timbre_press) timbre<=timbre+1'b1;
            if(volume_down_press && volume!=0) volume<=volume-1'b1;
            else if(volume_up_press && volume!=7) volume<=volume+1'b1;
            ref_div<=ref_div+1'b1;
            if(ce) frame<=~frame;
        end
    end
    audio_core #(.CLK_HZ(52500000),.PT_MODE(1),.NOTES("rom/notes.hex"),
        .GAIN(GAIN),.SHIFT(SHIFT),.DB_N(DB_N),
        .A_N(A_N),.D_N(D_N),.S_LV(S_LV),.R_N(R_N)) u_core(
        .clk(clk),.rst(rst),.key_in(key_in),.timbre(timbre),.volume(volume),.test_en(1'b0),
        .cfg_we(1'b0),.cfg_idx(5'd0),.cfg_fcw(32'd0),
        .shld(shld),.key_clk(key_clk),.bclk(hp_bclk),.lrck(hp_ws),.sd(hp_sd),
        .mclk(),.keys(keys),.pcm(pcm),.valid(valid),.ce(ce),.fault(fault));
    touch_led #(.FIRST(TOUCH_FIRST),.BUS_HZ(TOUCH_HZ),
        .TOUCH_TH(TOUCH_TH),.RELEASE_TH(RELEASE_TH),.REVERSE(LED_REV)) u_touch(
        .clk(clk),.rst(rst),.irq_n(touch_irq_n),.scl(touch_scl),.sda(touch_sda),
        .led_data(led_data),.led_clk(led_clk),.led_lat(led_lat),
        .ready(),.fault(touch_fault));
    assign pa_n=rst;
    assign dbg_frame=frame;
    assign dbg_key=|keys;
    assign dbg_err=fault | touch_fault;
    assign dbg_ref=ref_div[9];
    assign dbg_lock=1'b1;
    assign dbg_rst=rst;
endmodule
