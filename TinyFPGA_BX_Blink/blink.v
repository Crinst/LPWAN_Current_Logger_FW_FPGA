module blink(
  input i_clk;
  input i_clk_prescale;
  inpur i_blink_en;
  output o_blink;

  );

  reg [31:0] r_clock_counter = 0;

  // reset clock counter to 0
  // turn on blink output
  always @ (posedge i_blink_en) begin
    r_clock_counter <= 0;
    o_blink <= 1;
  end

  // turn off blink output when disabled
  always @ (negedge i_blink_en) begin
    o_blink <= 0;
  end

  // count clock pulses to divide blink frequency
  always @ (posedge i_clk) begin
    r_clock_counter <= r_clock_counter + 1;
  end

  // clock divide and set blink output
  always @ (posedge i_clk) begin
    if(r_clock_counter >= 2 ** i_clk_prescale) begin
      o_blink <= !o_blink;
      r_clock_counter <= 0;
    end

  end


end module
