`timescale 1ns/1ps
module touch_case #(parameter FIRST=0)(output reg finished=0);
    reg clk=0,rst=1,present=1,irq_n=1,hold_scl=0,hold_sda=0;
    always #10 clk=~clk;
    tri1 scl,sda;
    assign scl=hold_scl ? 1'b0 : 1'bz;
    assign sda=hold_sda ? 1'b0 : 1'bz;
    wire data,sclk,lat,ready,fault;
    touch_led #(.CLK_HZ(1000000),.BUS_HZ(25000),.FIRST(FIRST),.BOOT_N(20),.RESET_N(20),
        .SETTLE_N(20),.POLL_N(20000),.STALE_N(100000),.RETRY_N(100),.WAIT_N(200)) dut(
        .clk(clk),.rst(rst),.irq_n(irq_n),.scl(scl),.sda(sda),
        .led_data(data),.led_clk(sclk),.led_lat(lat),.ready(ready),.fault(fault));
    mpr_model chip(scl,sda,present);
    reg [15:0] sr=0,led=0;
    integer bits=0,frames=0,i,j,n0;
    reg [15:0] frame_led;
    always @(posedge sclk) begin
        if(bits==0) frame_led=dut.u_led.sent;
        sr={sr[14:0],data}; bits=bits+1;
    end
    always @(posedge lat) begin
        if(bits!=16) $fatal(1,"595 clock count %0d",bits);
        if(sr!==frame_led) $fatal(1,"595 bit order/snapshot");
        led=sr; bits=0; frames=frames+1;
    end
    task frame(input [7:0] mask);
        integer x,v,status;
        begin
            wait(dut.u_mpr.st==5); @(negedge clk);
            status=(mask<<FIRST) | (1<<(FIRST+8));
            if(FIRST==1) status=status|1;
            chip.mem[0]=status&255; chip.mem[1]=(status>>8)&15;
            for(x=0;x<12;x=x+1) begin
                v=600+x*13;
                chip.mem[4+2*x]=v&255; chip.mem[5+2*x]=(v>>8)&3;
                chip.mem[30+x]=180+x;
            end
        end
    endtask
    always @(negedge clk) if(dut.valid && ready) begin
        for(integer x=0;x<8;x=x+1) begin
            if(dut.filt[x*10+:10] !== (600+(x+FIRST)*13))
                $fatal(1,"filtered channel offset %0d",x);
            if(dut.base[x*10+:10] !== ((180+x+FIRST)*4))
                $fatal(1,"baseline channel offset %0d",x);
        end
    end
    task expect_led(input [15:0] val);
        integer t;
        begin
            t=0;
            while(led!==val && t<150000) begin @(posedge clk); t=t+1; end
            if(led!==val) $fatal(1,"LED expected %h got %h",val,led);
        end
    endtask
    initial begin
        repeat(5) @(negedge clk); rst=0;
        wait(ready);
        if(chip.mem[8'h5e]!=(8'h88+FIRST) || chip.mem[8'h5d]!=8'h20 ||
           chip.mem[8'h5b]!=8'h01)
            $fatal(1,"MPR configuration");
        for(i=0;i<8;i=i+1)
            if(chip.mem[8'h41+2*(i+FIRST)]!=12 || chip.mem[8'h42+2*(i+FIRST)]!=6)
                $fatal(1,"threshold %0d",i);
        for(j=0;j<8;j=j+1) begin
            frame(1<<j); expect_led(16'h3<<(2*j));
            frame(0); expect_led(0);
        end
        frame(8'h81); expect_led(16'hc003);
        frame(8'hff); expect_led(16'hffff);
        frame(0); expect_led(0);
        frame(8'h08); expect_led(16'h00c0);
        present=0;
        wait(fault); expect_led(0);
        present=1; wait(ready); frame(1); expect_led(3);
        // Clock stretch below timeout must recover without a fault.
        @(negedge scl); hold_scl=1;
        repeat(50) @(negedge clk); hold_scl=0;
        wait(dut.valid); if(fault) $fatal(1,"short stretch failed");
        // Stuck SCL is bounded and clears a stale LED.
        @(negedge scl); hold_scl=1; wait(fault); expect_led(0);
        hold_scl=0; wait(ready); frame(8'h80); expect_led(16'hc000);
        // A sensor-only power reset must trigger reinitialization.
        wait(dut.u_mpr.st==5); @(negedge clk); chip.mem[8'h5e]=0;
        wait(fault); expect_led(0);
        wait(ready); frame(1); expect_led(3);
        wait(dut.u_mpr.st==5); @(negedge clk); chip.mem[1]=8'h80;
        wait(fault); expect_led(0);
        wait(ready); frame(8'h80); expect_led(16'hc000);
        wait(dut.u_mpr.st==5); @(negedge clk); hold_sda=1;
        n0=chip.starts; wait(fault); expect_led(0);
        repeat(200) @(negedge clk); hold_sda=0;
        wait(ready); frame(1); expect_led(3);
        if(chip.nacks<10 || frames<16) $fatal(1,"incomplete serial traffic");
        $display("PASS touch_case FIRST=%0d: init, channel offsets, pairs, multitouch, release, polling, recovery, 595",FIRST);
        finished=1;
    end
    initial begin #100000000; $fatal(1,"touch timeout st=%0d bus=%0d",dut.u_mpr.st,dut.u_mpr.u_bus.st); end
endmodule

module tb_touch;
    wire done;
    touch_case #(.FIRST(0)) u(done);
    initial begin wait(done); $display("PASS tb_touch"); $finish; end
endmodule

module tb_touch_first1;
    wire done;
    touch_case #(.FIRST(1)) u(done);
    initial begin wait(done); $display("PASS tb_touch_first1"); $finish; end
endmodule
