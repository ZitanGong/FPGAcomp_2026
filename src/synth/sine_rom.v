module sine_rom #(parameter FILE = "rom/sine4k.hex", parameter AW=12)(
    input clk, input en, input [AW-1:0] addr,
    output reg signed [15:0] q
);
    reg signed [15:0] mem [0:(1<<AW)-1] /* synthesis syn_romstyle="block_rom" */;
    initial $readmemh(FILE,mem);
    always @(posedge clk) if (en) q <= mem[addr];
endmodule
