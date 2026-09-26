module adsr(
    input clk, input rst, input ce, input gate,
    input [15:0] a_n, input [15:0] d_n,
    input [15:0] s_lv, input [15:0] r_n,
    output reg [15:0] env,
    output reg [2:0] state
);
    localparam IDLE=0, ATT=1, DEC=2, SUS=3, REL=4;
    reg old_gate, go, up;
    reg [15:0] span, den, left, target, err;
    wire [15:0] quo, rem;
    wire busy, done;
    wire [16:0] err_sum = {1'b0,err} + {1'b0,rem};
    wire carry = err_sum >= {1'b0,den};
    wire [16:0] step = {1'b0,quo} + carry;
    wire [16:0] next_err = carry ? err_sum-{1'b0,den} : err_sum;
    wire [16:0] next_env = up ? {1'b0,env}+step : {1'b0,env}-step;
    div16 u_div(clk,rst,go,span,den,quo,rem,busy,done);

    task ramp;
        input [15:0] from, dest, dur;
        begin
            target <= dest; den <= dur; left <= dur; err <= 0;
            up <= dest >= from;
            span <= dest >= from ? dest-from : from-dest;
            go <= dur != 0;
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            env<=0; state<=IDLE; old_gate<=0; go<=0; up<=0;
            span<=0; den<=1; left<=0; target<=0; err<=0;
        end else begin
            go <= 0;
            if (ce) begin
                old_gate <= gate;
                if (gate && !old_gate) begin
                    if (a_n == 0) begin
                        env <= 65535;
                        if (d_n == 0) begin env<=s_lv; state<=SUS; end
                        else begin state<=DEC; ramp(16'hffff,s_lv,d_n); end
                    end else begin state<=ATT; ramp(env,16'hffff,a_n); end
                end else if (!gate && old_gate) begin
                    if (r_n == 0 || env == 0) begin env<=0; state<=IDLE; end
                    else begin state<=REL; ramp(env,16'd0,r_n); end
                end else if (state==ATT || state==DEC || state==REL) begin
                    if (left <= 1) begin
                        env <= target;
                        if (state==ATT) begin
                            if (d_n==0) begin env<=s_lv; state<=SUS; end
                            else begin state<=DEC; ramp(target,s_lv,d_n); end
                        end else if (state==DEC) state<=SUS;
                        else state<=IDLE;
                    end else begin
                        left <= left-1'b1;
                        err <= next_err[15:0];
                        env <= next_env[15:0];
                    end
                end
            end
        end
    end
endmodule
