module voice #(
    parameter FILE = "rom/timbres4.hex",
    parameter [15:0] NOTE_GAIN = 16'd32768,
    parameter integer KS_DELAY = 195
)(
    input clk, input rst, input ce, input gate,
    input [1:0] timbre,
    input [31:0] fcw,
    input [15:0] a_n, input [15:0] d_n,
    input [15:0] s_lv, input [15:0] r_n,
    output reg signed [15:0] pcm,
    output reg valid
);
    (* syn_preserve = 1 *) reg [31:0] phase;
    wire [15:0] adsr_env;
    wire [2:0] state;
    wire signed [15:0] wave_attack, wave_body;
    reg [15:0] amp, colour;
    reg [15:0] spectral_age;
    // Q16.8 keeps sub-LSB decay precision for multi-second aftersound.
    reg [23:0] piano_prompt, piano_after;
    reg old_gate;
    reg [1:0] old_timbre;
    reg [4:0] v;
    reg signed [32:0] attack_product, body_product;
    reg signed [15:0] wave_mix;
    reg signed [33:0] prod /* synthesis syn_dspstyle="dsp" */;

    // Timbre 2: one independent Karplus-Strong string per key.  The memory is
    // filled from the 52.5 MHz domain in under 10 us, then updated once per
    // audio sample.  The two-point average is the loop's dispersion/damping
    // filter and also contributes the familiar half-sample tuning delay.
    reg signed [15:0] ks_mem [0:511] /* synthesis syn_ramstyle="block_ram" */;
    reg [8:0] ks_ptr, ks_read_ptr, ks_fill_ptr;
    reg [15:0] ks_lfsr;
    reg signed [15:0] ks_noise_z1, ks_read, ks_z1, ks_out;
    reg ks_filling, ks_active, ks_pending;
    wire ks_feedback_bit=ks_lfsr[15]^ks_lfsr[13]^ks_lfsr[12]^ks_lfsr[10];
    wire signed [16:0] ks_noise_sum=$signed(ks_lfsr)+ks_noise_z1;
    wire signed [15:0] ks_excitation=ks_noise_sum>>>2;
    wire signed [16:0] ks_pair_sum=ks_read+ks_z1;
    wire signed [15:0] ks_average=ks_pair_sum>>>1;
    wire signed [15:0] ks_loss=gate ? (ks_average>>>8) : (ks_average>>>3);
    wire signed [16:0] ks_damped={ks_average[15],ks_average}
                                  -{ks_loss[15],ks_loss};
    wire [15:0] ks_abs=ks_read[15] ? (~ks_read+1'b1) : ks_read;
    wire [15:0] ks_z1_abs=ks_z1[15] ? (~ks_z1+1'b1) : ks_z1;

    wire note_trigger = gate && (!old_gate || timbre != old_timbre);
    wire [24:0] piano_sum = {1'b0,piano_prompt}+{1'b0,piano_after};
    wire [16:0] piano_level = piano_sum>>8;
    wire [15:0] piano_env = piano_level[16] ? 16'hffff : piano_level[15:0];
    wire [15:0] selected_env = timbre==2'd2 ? 16'hffff :
                               timbre==2'd3 ? piano_env : adsr_env;
    wire [32:0] tracked_amp={1'b0,selected_env}*NOTE_GAIN+33'd16384;
    wire signed [16:0] attack_weight={1'b0,16'hffff-colour};
    wire signed [16:0] body_weight={1'b0,colour};
    wire signed [33:0] blend_sum={{1{attack_product[32]}},attack_product}
                                  +{{1{body_product[32]}},body_product};
    wire signed [33:0] blend_rounded=blend_sum+34'sd32768
                                      -(blend_sum[33] ? 34'sd1 : 34'sd0);
    wire signed [33:0] pcm_rounded=prod+34'sd32768-(prod[33] ? 34'sd1 : 34'sd0);
    // ROM bank 2 is free because timbre 2 uses the delay-line model.  Reuse it
    // for a separately calibrated C3 piano spectrum in the low octave.
    wire [1:0] rom_bank=(timbre==2'd3 && KS_DELAY>=207) ? 2'd2 : timbre;

    adsr u_env(clk,rst,ce,gate,a_n,d_n,s_lv,r_n,adsr_env,state);
    sine_rom #(.FILE(FILE),.AW(12)) u_rom(
        clk,v[0],{rom_bank,phase[31:22]},wave_attack,wave_body);

    function [23:0] decay_step;
        input [23:0] value;
        input [4:0] shift;
        reg [23:0] shifted;
        begin
            shifted=value>>shift;
            decay_step=(value!=0 && shifted==0) ? 24'd1 : shifted;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            phase<=0; amp<=0; colour<=0; spectral_age<=0;
            piano_prompt<=0; piano_after<=0;
            old_gate<=0; old_timbre<=0;
            attack_product<=0; body_product<=0; wave_mix<=0; prod<=0;
            ks_ptr<=0; ks_read_ptr<=0; ks_fill_ptr<=0;
            ks_lfsr<=16'hace1^KS_DELAY; ks_noise_z1<=0;
            ks_read<=0; ks_z1<=0; ks_out<=0;
            ks_filling<=0; ks_active<=0; ks_pending<=0;
            pcm<=0; v<=0; valid<=0;
        end else begin
            v <= {v[3:0],ce};
            valid<=v[4];
            if (ce) begin
                phase <= phase + fcw;
                old_gate <= gate;
                old_timbre <= timbre;

                // 16/65536 at 51.2 kHz: attack spectrum reaches body in 80 ms.
                if (note_trigger) spectral_age<=0;
                else if ((gate || selected_env!=0) && spectral_age<16'hfff0)
                    spectral_age<=spectral_age+16'd16;
                else if (!gate && selected_env==0) spectral_age<=0;

                // Reduced two-stage piano decay: prompt radiation + aftersound.
                if (timbre!=2'd3) begin
                    piano_prompt<=0;
                    piano_after<=0;
                end else if (note_trigger) begin
                    piano_prompt<=24'd12582656; // 49151 in Q16.8
                    piano_after<=24'd4194304;   // 16384 in Q16.8
                end else if (gate) begin
                    piano_prompt<=piano_prompt-decay_step(piano_prompt,5'd14);
                    piano_after<=piano_after-decay_step(piano_after,5'd17);
                end else begin
                    // A real damper kills the released string much faster than
                    // the undamped aftersound.  End below about -60 dB so a
                    // quantized periodic residue cannot hover indefinitely.
                    if (piano_level<17'd64) begin
                        piano_prompt<=0;
                        piano_after<=0;
                    end else begin
                        piano_prompt<=piano_prompt-decay_step(piano_prompt,5'd11);
                        piano_after<=piano_after-decay_step(piano_after,5'd13);
                    end
                end
            end

            // Noise-burst initialization has priority over loop playback.
            if (ce && timbre==2'd2 && note_trigger) begin
                ks_fill_ptr<=0;
                ks_lfsr<=16'hace1^KS_DELAY;
                ks_noise_z1<=0;
                ks_filling<=1;
                ks_active<=0;
                ks_pending<=0;
                ks_out<=0;
            end else if (ks_filling) begin
                ks_mem[ks_fill_ptr]<=ks_excitation;
                ks_noise_z1<=$signed(ks_lfsr);
                ks_lfsr<={ks_lfsr[14:0],ks_feedback_bit};
                if (ks_fill_ptr==KS_DELAY-1) begin
                    ks_fill_ptr<=0;
                    ks_ptr<=0;
                    ks_z1<=0;
                    ks_filling<=0;
                    ks_active<=1;
                end else ks_fill_ptr<=ks_fill_ptr+1'b1;
            end else begin
                if (ce && timbre==2'd2 && ks_active) begin
                    ks_read<=ks_mem[ks_ptr];
                    ks_read_ptr<=ks_ptr;
                    ks_ptr<=(ks_ptr==KS_DELAY-1) ? 9'd0 : ks_ptr+1'b1;
                    ks_pending<=1;
                end else if (ks_pending) begin
                    ks_mem[ks_read_ptr]<=ks_damped[15:0];
                    ks_z1<=ks_read;
                    ks_out<=ks_read;
                    ks_pending<=0;
                    if (ks_abs<16'd8 && ks_z1_abs<16'd8) begin
                        ks_active<=0;
                        ks_out<=0;
                    end
                end
            end

            if (v[0]) begin
                amp <= tracked_amp[30:15];
                colour <= (timbre==2'd2 || timbre==2'd3) ? spectral_age : 16'hffff;
            end
            if (v[1]) begin
                attack_product <= wave_attack*attack_weight;
                body_product <= wave_body*body_weight;
            end
            if (v[2]) wave_mix <= blend_rounded[31:16];
            if (v[3]) prod <= (timbre==2'd2 ? ks_out : wave_mix)
                              *$signed({1'b0,amp});
            if (v[4]) pcm <= pcm_rounded[31:16];
        end
    end
endmodule
