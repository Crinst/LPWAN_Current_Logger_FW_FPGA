// look in pins.pcf for all the pin names on the TinyFPGA BX board


module top (
    input CLK,    // 16MHz clock
    output LED,   // User/boot LED next to power LED
    output PIN_1,  // custom output PIN A2
    output USBPU,  // USB pull-up resistor
    output PIN_2,
    output PIN_3,
    output PIN_4,
    output PIN_5
);
    // drive USB pull-up resistor to '0' to disable USB
    assign USBPU = 0;

    wire clk_240mhz;
    wire clk_240mhz_locked;

    // setting up PLL for 240 MHz main clock
    pll pll240( .clock_in(CLK), .clock_out(clk_240mhz), .locked(clk_240mhz_locked) );

    ////////
    // make a simple blink circuit
    ////////

    // keep track of time and location in blink_pattern
    reg [25:0] blink_counter;
    reg [31:0] blink_fast_counter;

    // pattern that will be flashed over the LED over time
    //wire [31:0] blink_pattern = 32'b101010001110111011100010101;
    wire [31:0] blink_pattern = 32'b10101010101010101010101010101010;
    wire [31:0] blink_fast_pattern = 32'b10101010101010101010101010101010;


    // increment the blink_counter every clock
    always @(posedge CLK)
      begin
        blink_counter <= blink_counter + 1;
      end

    // increase blink fast counter
    always @ (posedge clk_240mhz) begin
      if(clk_240mhz_locked) begin
        blink_fast_counter <= blink_fast_counter + 1;
      end
    end

    reg [31:0] r_blink_prescale = 2 ** 23; // approx. 8 mil. equals to approx 2 Hz for 16MHz main clock
    reg r_blink_enable = 1;
    wire w_blink_output;


    blink blink_LED( .i_clk(CLK), .i_clk_prescale(r_blink_prescale), .i_blink_en(r_blink_enable), .o_blink(w_blink_output));

    assign LED = w_blink_output;

    // light up the LED according to the pattern
    //assign LED = blink_pattern[blink_counter[25:21]];
    //assign LED = blink_fast_pattern[blink_fast_counter[31:26]];
    assign PIN_1 = blink_pattern[blink_counter[14:4]];
endmodule
