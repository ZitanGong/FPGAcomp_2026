module hc165(input shld, input sclk, input [7:0] par, output q);
    reg [7:0] data;
    always @(negedge shld or posedge sclk) begin
        if(!shld) data<=par;
        else data<={data[6:0],1'b0};
    end
    assign #20 q=data[7];
endmodule
