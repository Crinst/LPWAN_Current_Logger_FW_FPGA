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


    // define testing SPI Interface
    wire spi_clk;
    wire spi_mosi;
    wire spi_miso;
    wire spi_cs;

    reg spiTransferDataReady = 1'b1;
    reg spiTransferPreparation = 1'b0;

    reg spiResetPulse;
    wire spiTxReadyPulse;
    reg spiTxNextBytePulse;
    reg spiTxBytePosition = 0;
    reg [2:0] spiTxCount;
    reg [31:0] spiTxRegister = 32'b10101010101010101010101010101010;
    reg [7:0] o_byte = 8'b10101010;
    wire [7:0] i_byte;

    wire [2:0] spiRxBytePosition;
    wire spiRxReadyPulse;
    wire [31:0] spiRxRegister;

    SPI_Master_With_Single_CS spiMasterCS
    #(parameter SPI_MODE = 0,
      parameter CLKS_PER_HALF_BIT = 2,
      parameter MAX_BYTES_PER_CS = 4,
      parameter CS_INACTIVE_CLKS = 1)

    (
      .i_Rst_L(spiResetPulse),
      .i_Clk(CLK),

      .i_TX_Count(spiTxCount),
      .i_TX_Byte(o_byte),
      .i_TX_DV(spiTxNextBytePulse),
      .o_TX_Ready(spiTxReadyPulse),

      .o_RX_Count(spiRxBytePosition),
      .o_RX_DV(spiRxReadyPulse),
      .o_RX_Byte(i_byte),

      .o_SPI_Clk(spi_clk),
      .i_SPI_MISO(spi_miso),
      .o_SPI_MOSI(spi_mosi),
      .o_SPI_CS_n(spi_cs)

    );

    reg [31:0] clockCounter;

    assign PIN_2 = spi_clk;
    assign PIN_3 = spi_mosi;
    assign PIN_4 = spi_miso;
    assign PIN_5 = spi_cs;

    // keep track of time and location in blink_pattern
    reg [25:0] blink_counter;
    reg [31:0] blink_fast_counter;

    // pattern that will be flashed over the LED over time
    //wire [31:0] blink_pattern = 32'b101010001110111011100010101;
    wire [31:0] blink_pattern = 32'b10101010101010101010101010101010;
    wire [31:0] blink_fast_pattern = 32'b10101010101010101010101010101010;

    initial begin
      //repeat(10) @(posedge clk_240mhz);
      spiResetPulse = 1'b0;
      //repeat(10) @(posedge clk_240mhz);
      spiResetPulse = 1'b1;

      spiTransferDataReady = 1'b1;

    end


    always @ (posedge clk_240mhz) begin
      // reset SPI register
      if(spiTransferDataReady && !spiTransferPreparation && spiTxReadyPulse) begin
        spiResetPulse = 1'b0;
        spiResetPulse = 1'b1;
        spiTxCount = 3'b001;
        spiTransferPreparation = 1'b1;
      end
      // initialize sending data 1B
      if(spiTransferDataReady && spiTransferPreparation) begin
        o_byte <= 8'b10101010;
        spiTxNextBytePulse <= 1'b1;
        spiTransferDataReady <= 1'b0;
      end
      // finish sending data 1B
      if (!spiTransferDataReady && spiTransferPreparation) begin
        spiTxNextBytePulse <= 1'b0;
      end

      clockCounter = clockCounter + 1;

      if(clockCounter >= 100) begin
        spiResetPulse = 1'b0;
        spiResetPulse = 1'b1;
        spiTransferDataReady = 1'b1;
      end


    end

    always @ (posedge spiRxReadyPulse) begin
      spiRxRegister <= i_byte;
    end


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


    // light up the LED according to the pattern
    //assign LED = blink_pattern[blink_counter[25:21]];
    assign LED = blink_fast_pattern[blink_fast_counter[31:26]];
    assign PIN_1 = blink_pattern[blink_counter[14:4]];
endmodule
