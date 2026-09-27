// Four 1024-sample timbres. Each word packs attack in the low half and body
// in the high half, read together through one address port per voice.
module sine_rom #(parameter FILE = "rom/timbres4.hex", parameter AW=12)(
    input clk, input en, input [AW-1:0] addr,
    output reg signed [15:0] q_attack,
    output reg signed [15:0] q_body
);
    reg [31:0] mem [0:(1<<AW)-1] /* synthesis syn_romstyle="block_rom" */;
    initial $readmemh(FILE,mem);
    always @(posedge clk) if (en) begin
        q_attack <= mem[addr][15:0];
        q_body <= mem[addr][31:16];
    end
endmodule
