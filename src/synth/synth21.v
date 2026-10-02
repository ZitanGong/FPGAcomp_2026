module synth21 #(
    parameter FILE = "rom/timbres4.hex",
    parameter NOTES = "rom/notes.hex",
    parameter SHIFT = 5, parameter GAIN=1
)(
    input clk, input rst, input ce, input [20:0] keys,
    input [1:0] timbre, input [2:0] volume,
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
    // Q1.15 key-tracking curve in physical pitch order C3..B5.  The keyboard
    // scan order is non-linear, so map every switch explicitly.  This gently
    // reduces the naturally prominent upper register instead of making a hard
    // gain jump at each octave boundary.
    function [15:0] note_gain;
        input integer index;
        begin
            case(index)
                4: note_gain=16'd32768; // C3: low octave at full level
                5: note_gain=16'd32768; // D3
                6: note_gain=16'd32768; // E3
                0: note_gain=16'd32768; // F3
                1: note_gain=16'd32768; // G3
                2: note_gain=16'd32768; // A3
                3: note_gain=16'd32768; // B3
               11: note_gain=16'd18022; // C4: 55%
               12: note_gain=16'd17564; // D4
               13: note_gain=16'd17105; // E4
                7: note_gain=16'd16646; // F4
                8: note_gain=16'd16187; // G4
                9: note_gain=16'd15729; // A4
               10: note_gain=16'd15073; // B4: 46%
               18: note_gain=16'd13435; // C5: 41%
               19: note_gain=16'd12911; // D5
               20: note_gain=16'd12386; // E5
               14: note_gain=16'd11862; // F5
               15: note_gain=16'd11338; // G5
               16: note_gain=16'd10813; // A5
               17: note_gain=16'd10158; // B5: 31%
              default: note_gain=16'd32768;
            endcase
        end
    endfunction
    // Karplus-Strong uses its own loudness curve.  The modal/organ curve above
    // intentionally attenuates the upper register, but that makes plucked
    // notes sound much quieter as the delay line gets shorter.  Keep the
    // physical-model timbre nearly flat and let the per-note loop loss below
    // control the decay time instead.
    function [15:0] ks_note_gain;
        input integer index;
        begin
            ks_note_gain=16'd32768;
        end
    endfunction
    // Integer delay including the 0.5-sample loop-average delay, for 51.2 kHz.
    // Indices follow the physical 74HC165 scan wiring rather than pitch order.
    function integer ks_delay;
        input integer index;
        begin
            case(index)
                 0: ks_delay=293;  1: ks_delay=261;  2: ks_delay=232;
                 3: ks_delay=207;  4: ks_delay=391;  5: ks_delay=348;
                 6: ks_delay=310;  7: ks_delay=146;  8: ks_delay=130;
                 9: ks_delay=116; 10: ks_delay=103; 11: ks_delay=195;
                12: ks_delay=174; 13: ks_delay=155; 14: ks_delay=73;
                15: ks_delay=65;  16: ks_delay=58;  17: ks_delay=51;
                18: ks_delay=97;  19: ks_delay=87;  20: ks_delay=77;
              default: ks_delay=195;
            endcase
        end
    endfunction
    // Choose the damping shift from the string length so that the T60 time is
    // roughly constant across the keyboard.  A fixed shift makes short
    // (high-pitch) delay lines decay much faster than long ones.
    function [4:0] ks_loss_shift;
        input integer index;
        begin
            case(index)
                 0: ks_loss_shift=5'd7;  1: ks_loss_shift=5'd7;
                 2: ks_loss_shift=5'd7;  3: ks_loss_shift=5'd7;
                 4: ks_loss_shift=5'd7;  5: ks_loss_shift=5'd7;
                 6: ks_loss_shift=5'd7;  7: ks_loss_shift=5'd8;
                 8: ks_loss_shift=5'd8;  9: ks_loss_shift=5'd8;
                10: ks_loss_shift=5'd8; 11: ks_loss_shift=5'd8;
                12: ks_loss_shift=5'd8; 13: ks_loss_shift=5'd8;
                14: ks_loss_shift=5'd9; 15: ks_loss_shift=5'd9;
                16: ks_loss_shift=5'd9; 17: ks_loss_shift=5'd10;
                18: ks_loss_shift=5'd9; 19: ks_loss_shift=5'd9;
                20: ks_loss_shift=5'd9;
              default: ks_loss_shift=5'd8;
            endcase
        end
    endfunction
    always @(posedge clk) begin
        if(rst) for(i=0;i<21;i=i+1) fcw[i]<=init_fcw[i];
        else if(cfg_we && cfg_idx<21) fcw[cfg_idx]<=cfg_fcw;
    end
    genvar g;
    generate for(g=0;g<21;g=g+1) begin: V
        voice #(.FILE(FILE),.NOTE_GAIN(note_gain(g)),
                .KS_DELAY(ks_delay(g)),.KS_LOSS_SHIFT(ks_loss_shift(g)),
                .KS_NOTE_GAIN(ks_note_gain(g))) u_voice(
            .clk(clk),.rst(rst),.ce(ce),.gate(keys[g]),.timbre(timbre),
            .fcw(fcw[g]),.a_n(a_n),.d_n(d_n),.s_lv(s_lv),.r_n(r_n),
            .pcm(voices[g*16 +: 16]),.valid(vv[g]));
    end endgenerate
    mix21 #(.SHIFT(SHIFT),.GAIN(GAIN)) u_mix(clk,rst,vv[0],voices,volume,pcm,valid,clip);
endmodule
