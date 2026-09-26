module key_map(
    input [20:0] phys,
    output [20:0] keys
);
    assign keys={phys[17:14],phys[20:18],phys[10:7],
                 phys[13:11],phys[3:0],phys[6:4]};
endmodule
