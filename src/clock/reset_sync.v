module reset_sync(input clk, input rst_n, input lock, output rst);
    (* syn_preserve = 1 *) reg [2:0] pipe;
    always @(posedge clk or negedge rst_n or negedge lock) begin
        if(!rst_n || !lock) pipe<=3'b111;
        else pipe<={pipe[1:0],1'b0};
    end
    assign rst=pipe[2];
endmodule
