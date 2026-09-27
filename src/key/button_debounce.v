// Active-low push button synchronizer, debounce filter and one-clock press pulse.
module button_debounce #(parameter COUNT=525000)(
    input clk, input rst, input key_n, output reg pressed
);
    reg meta, sync, stable;
    reg [19:0] count;
    always @(posedge clk) begin
        if(rst) begin
            meta<=1'b1; sync<=1'b1; stable<=1'b1;
            count<=0; pressed<=1'b0;
        end else begin
            meta<=key_n; sync<=meta; pressed<=1'b0;
            if(sync==stable) count<=0;
            else if(count==COUNT-1) begin
                stable<=sync; count<=0;
                if(stable && !sync) pressed<=1'b1;
            end else count<=count+1'b1;
        end
    end
endmodule
