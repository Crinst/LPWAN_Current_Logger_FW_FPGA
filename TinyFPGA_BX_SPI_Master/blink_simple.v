/*
**  Simple blink module
**  inputs - clock source, clock prescale, blink output enable signal and output signal
*/

module blink_simple(
  input i_clk,
  input [31:0] i_clk_prescale,
  input i_blink_en,
  output wire o_blink
  );

  reg [31:0] r_clock_counter = 0;
  reg outputStatus;

  always @ (posedge i_clk) begin
    // counting clock pulses
    r_clock_counter <= r_clock_counter + 1;

    // divide clock pulses according to used prescale and output enable signal
    outputStatus <= r_clock_counter[i_clk_prescale] & i_blink_en ;
    //o_blink <= r_clock_counter[i_clk_prescale] & i_blink_en ;

  end

  assign o_blink = outputStatus;

endmodule
