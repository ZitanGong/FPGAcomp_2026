module mix21 #(parameter SHIFT = 5, parameter GAIN=1)(
    input clk, input rst, input valid,
    input [335:0] pcm,
    output reg signed [15:0] out,
    output reg done, output reg clip
);
    reg signed [16:0] s1 [0:15];
    reg signed [17:0] s2 [0:7];
    reg signed [18:0] s3 [0:3];
    reg signed [19:0] s4 [0:1];
    reg signed [20:0] s5;
    wire signed [23:0] wide={{3{s5[20]}},s5};
    wire signed [23:0] gain=(GAIN==3) ? wide+(wide<<<1) : wide;
    wire signed [23:0] rounded;
    generate if(SHIFT==0) begin: EXACT
        assign rounded=gain;
    end else begin: ROUND
        assign rounded=gain+(24'sd1<<<(SHIFT-1))-(gain[23] ? 24'sd1 : 24'sd0);
    end endgenerate
    wire signed [23:0] scaled=rounded>>>SHIFT;
    wire signed [15:0] x [0:31];
    reg [4:0] v;
    genvar g;
    generate for (g=0;g<32;g=g+1) begin: IN
        if (g<21) assign x[g] = pcm[g*16 +: 16];
        else assign x[g] = 16'sd0;
    end endgenerate
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            v<=0; done<=0; out<=0; clip<=0; s5<=0;
            for(i=0;i<16;i=i+1) s1[i]<=0;
            for(i=0;i<8;i=i+1) s2[i]<=0;
            for(i=0;i<4;i=i+1) s3[i]<=0;
            for(i=0;i<2;i=i+1) s4[i]<=0;
        end else begin
            v<={v[3:0],valid}; done<=v[4];
            if(valid) for(i=0;i<16;i=i+1)
                s1[i] <= {x[2*i][15],x[2*i]} + {x[2*i+1][15],x[2*i+1]};
            if(v[0]) for(i=0;i<8;i=i+1)
                s2[i] <= {s1[2*i][16],s1[2*i]} + {s1[2*i+1][16],s1[2*i+1]};
            if(v[1]) for(i=0;i<4;i=i+1)
                s3[i] <= {s2[2*i][17],s2[2*i]} + {s2[2*i+1][17],s2[2*i+1]};
            if(v[2]) for(i=0;i<2;i=i+1)
                s4[i] <= {s3[2*i][18],s3[2*i]} + {s3[2*i+1][18],s3[2*i+1]};
            if(v[3]) s5 <= {s4[0][19],s4[0]} + {s4[1][19],s4[1]};
            if(v[4]) begin
                clip <= 0;
                if(scaled > 24'sd32767) begin out<=16'sh7fff; clip<=1; end
                else if(scaled < -24'sd32768) begin out<=16'sh8000; clip<=1; end
                else out <= scaled[15:0];
            end
        end
    end
endmodule
