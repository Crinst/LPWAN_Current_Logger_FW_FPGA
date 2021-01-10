// look in pins.pcf for all the pin names on the TinyFPGA BX board


module top (
    input CLK,    // 16MHz clock
    output USBPU,  // USB pull-up resistor

    output LED,   // User/boot LED next to power LED
    output PIN_1,  // custom output PIN A2

    output PIN_2, // SPI SCLK
    output PIN_3, // SPI MOSI
    input PIN_4, // SPI MISO
    output PIN_5,  // SPI CS
    output PIN_6, // SPI CLK OUT
    output PIN_10,
    output PIN_11,
    output PIN_12,
    output PIN_13

);
    // drive USB pull-up resistor to '0' to disable USB
    assign USBPU = 0;

    // general constants - running counter for main frequency
    reg [31:0] r_cycle_counter = 0;
    /*wire w_led_1;
    wire w_led_2;
    wire w_led_3;
    */
    reg w_led_1 = 0;
    reg w_led_2 = 0;
    reg w_led_3 = 0;
    reg w_led_4 = 0;


    reg r_debug_1 = 0;
    reg r_debug_2 = 0;
    reg r_debug_3 = 0;



    // *********************** P L L - 240 MHz **********************************************//
    //***************************************************************************************//
    /*
    wire w_clk_240mhz;
    wire w_clk_240mhz_locked;   // checking for clock phase locking

    // setting up PLL for 240 MHz main clock
    pll pll240( .clock_in(CLK), .clock_out(w_clk_240mhz), .locked(w_clk_240mhz_locked) );
    */
    // *********************** P L L - 240 MHz - E N D **************************************//
    //***************************************************************************************//


    // ****************************** L E D *************************************************//
    //******************************* 16 MHz ************************************************//
    reg [31:0] r_blink_prescale = 23; // approx. 8 mil. equals to approx 0.95 Hz for 16MHz main clock
    reg r_blink_enable = 1'b0;  // out enable, default turned off
    wire w_blink_output;

    //blink blink_LED( .i_clk(CLK), .i_clk_prescale(r_blink_prescale), .i_blink_en(r_blink_enable), .o_blink(w_blink_output));
    blink_simple blink_simple_LED( .i_clk(CLK), .i_clk_prescale(r_blink_prescale), .i_blink_en(r_blink_enable), .o_blink(w_blink_output));

    // enable Blink if turned off
    always @ (posedge CLK) begin
      if(!r_blink_enable) begin
        r_blink_enable = !r_blink_enable;
      end
    end

    assign LED = w_blink_output;

    // ****************************** L E D - E N D *****************************************//
    //******************************* 16 MHz ************************************************//

    // ****************************** L E D *************************************************//
    //******************************* 240 MHz ***********************************************//
    /*
    reg [31:0] r_blink_prescale_2 = 27; // approx. 134 mil. equals to approx 0.95 Hz for 240MHz main clock
    reg r_blink_enable_2 = 1'b0;  // out enable, default turned off
    wire w_blink_output_2;

    //blink blink_LED( .i_clk(CLK), .i_clk_prescale(r_blink_prescale), .i_blink_en(r_blink_enable), .o_blink(w_blink_output));
    blink_simple blink_simple_LED2( .i_clk(w_clk_240mhz), .i_clk_prescale(r_blink_prescale_2), .i_blink_en(r_blink_enable_2), .o_blink(w_blink_output_2));

    // enable Blink if turned off
    always @ (posedge w_clk_240mhz) begin
      if(!r_blink_enable_2) begin
        r_blink_enable_2 = !r_blink_enable_2;
      end
    end

    assign PIN_1 = w_blink_output_2;
    */

    // ****************************** L E D - E N D *****************************************//
    //******************************* 240 MHz ***********************************************//

    // ******************** S P I - ADC - 60 MHz ********************************************//
    //***************************************************************************************//

    // define testing SPI Interface
    parameter SPI_MODE_ADC = 0; // CPOL = 0, CPHA = 0 ===> compatible with STM basic settings
    parameter CLKS_PER_HALF_BIT_ADC = 4;  // 2 MHz
    parameter CS_CLK_DELAY_ADC = 4;  // 25 MHz
    parameter MAX_BYTES_PER_CS_ADC = 4; // send maximum of 4 bytes before changing CS line

    // ADC conversion state machine states
    localparam  ADC_UNKNOWN = 0;
    localparam  ADC_READY = 1;
    localparam  ADC_SAMPLING = 2;
    localparam  ADC_ACQUIRING = 3;

    reg [3:0] r_adc_master_state = ADC_UNKNOWN;

    // define spi signals
    wire w_spi_master_adc_clk;
    wire w_spi_master_adc_mosi;
    wire w_spi_master_adc_miso;
    wire w_spi_master_adc_cs;



    // counters to define tx, rx bytes
    reg [2:0] r_spi_master_adc_tx_data_count = 4;
    wire [2:0] w_spi_master_adc_rx_data_count;

    // conters to point in registers
    reg [3:0] r_spi_master_adc_tx_counter = 0;
    reg [3:0] r_spi_master_adc_rx_counter = 0;

    // tx data -- 11 22 33 44 bytes
    reg [31:0] r_spi_master_adc_tx_data = 0;
    reg [31:0] r_spi_master_adc_rx_data;

    // state indication constants
    reg r_spi_master_adc_reset = 0;
    reg r_spi_master_adc_tx_dv = 0;
    wire w_spi_master_adc_rx_dv;
    wire w_spi_master_adc_tx_ready;

    // temp registry
    reg [7:0] r_temp_adc_tx = 12;
    wire [7:0] w_temp_adc_rx;

    SPI_Master_With_Single_CS
    #(
      .SPI_MODE(SPI_MODE_ADC),
      .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT_ADC),
      .MAX_BYTES_PER_CS(MAX_BYTES_PER_CS_ADC),
      .CS_INACTIVE_CLKS(CS_CLK_DELAY_ADC)
    ) spiMasterADC
    (
      .i_Rst_L(r_spi_master_reset),
      .i_Clk(CLK),

      // MOSI
      .i_TX_Count(r_spi_master_tx_data_count),
      .i_TX_Byte(r_temp_tx),
      .i_TX_DV(r_spi_master_tx_dv),
      .o_TX_Ready(w_spi_master_tx_ready),

      // MISO
      .o_RX_Count(w_spi_master_rx_data_count),
      .o_RX_DV(w_spi_master_rx_dv),
      .o_RX_Byte(w_temp_rx),

      // SPI signals

      .o_SPI_Clk(w_spi_master_clk),
      .i_SPI_MISO(w_spi_master_miso),
      .o_SPI_MOSI(w_spi_master_mosi),
      .o_SPI_CS_n(w_spi_master_cs)
        /*
      .o_SPI_Clk(PIN_2),
      .i_SPI_MISO(PIN_3),
      .o_SPI_MOSI(PIN_4),
      .o_SPI_CS_n(PIN_5)
    	*/
    );

    // ******************* S P I  - ADC - 60 MHz - E N D ************************************//
    //***************************************************************************************//

    // ******************** S P I - MCU - 8 MHz *********************************************//
    //***************************************************************************************//
    // define testing SPI Interface
    parameter SPI_MODE = 0; // CPOL = 0, CPHA = 0 ===> compatible with STM basic settings
    parameter CLKS_PER_HALF_BIT = 16;  // 500 kHz
    parameter CS_CLK_DELAY = 4;  // 25 MHz
    parameter MAX_BYTES_PER_CS = 4; // send maximum of 4 bytes before changing CS line

    // SPI MASTER state machine states
    localparam  SPI_UNKNOWN = 0;      //  state after powering up or during error
    localparam  SPI_READY = 1;        //  state indicating readiness for transfer ==> data ready, constant zeroed
    localparam  SPI_INITIALIZED = 2;  //  state after sucessfully initializing spi module or finishing transfer waiting for new data commands
    localparam  SPI_TRANSFERING = 3;  // state indicating running spi transfer, no changes to buffer allowed

    reg [3:0] r_spi_master_state = SPI_UNKNOWN;

    // spi data ready indication quick constants
    // 1 = ready to start transmission, 0 = not ready yet
    reg w_spi_master_tx_data_ready = 0;

    // define spi signals
    wire w_spi_master_clk;
    wire w_spi_master_mosi;
    wire w_spi_master_miso;
    wire w_spi_master_cs;

    // indicating data readiness for sending over SPI bus
    reg r_spi_master_data_ready = 0;

    // counters to define tx, rx bytes
    reg [2:0] r_spi_master_tx_data_count = 4;
    wire [2:0] w_spi_master_rx_data_count;

    // conters to point in registers
    reg [3:0] r_spi_master_tx_counter = 0;
    reg [3:0] r_spi_master_rx_counter = 0;

    // tx data -- 11 22 33 44 bytes
    reg [31:0] r_spi_master_tx_data = 740365835;
    reg [31:0] r_spi_master_rx_data;

    // state indication constants
    reg r_spi_master_reset = 0;
    reg r_spi_master_tx_dv = 0;
    wire w_spi_master_rx_dv;
    wire w_spi_master_tx_ready;

    // temp registry
    reg [7:0] r_temp_tx = 12;
    wire [7:0] w_temp_rx;

    SPI_Master_With_Single_CS
    #(
      .SPI_MODE(SPI_MODE),
      .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT),
      .MAX_BYTES_PER_CS(MAX_BYTES_PER_CS),
      .CS_INACTIVE_CLKS(CS_CLK_DELAY)
    ) spiMasterCS
    (
      .i_Rst_L(r_spi_master_reset),
      .i_Clk(CLK),

      // MOSI
      .i_TX_Count(r_spi_master_tx_data_count),
      .i_TX_Byte(r_temp_tx),
      .i_TX_DV(r_spi_master_tx_dv),
      .o_TX_Ready(w_spi_master_tx_ready),

      // MISO
      .o_RX_Count(w_spi_master_rx_data_count),
      .o_RX_DV(w_spi_master_rx_dv),
      .o_RX_Byte(w_temp_rx),

      // SPI signals

      .o_SPI_Clk(w_spi_master_clk),
      .i_SPI_MISO(w_spi_master_miso),
      .o_SPI_MOSI(w_spi_master_mosi),
      .o_SPI_CS_n(w_spi_master_cs)
        /*
      .o_SPI_Clk(PIN_2),
      .i_SPI_MISO(PIN_3),
      .o_SPI_MOSI(PIN_4),
      .o_SPI_CS_n(PIN_5)
    	*/
    );

    // ******************* S P I  - MCU - 8 MHz - E N D *************************************//
    //***************************************************************************************//



    /*
    *   SPI MASTER RX, TX handle cycle
    */
    always @ (posedge CLK) begin

      // simple cycle counter 32b
      r_cycle_counter <= r_cycle_counter + 1;

      case (r_spi_master_state)

        SPI_UNKNOWN:  begin
          if (!r_spi_master_reset)  begin
            r_spi_master_reset <= 1;
          end // end if
          else begin
            r_spi_master_tx_counter <= 0;
            r_spi_master_rx_counter <= 0;

            r_spi_master_tx_data_count <= 0;

            w_led_1 <= 1;

            r_spi_master_state <= SPI_INITIALIZED;

          end // end else

        end // end case statement

        SPI_INITIALIZED:  begin
          r_spi_master_tx_counter <= 0;
          r_spi_master_rx_counter <= 0;

          r_spi_master_tx_data_count <= 0;

          w_led_2 <= 1;

          if (w_spi_master_tx_data_ready) begin
            w_led_3 <= 1;
            r_spi_master_state <= SPI_READY;
          end // end if

        end // end case statement

        SPI_READY:  begin
          r_spi_master_tx_data_count <= 4;
          w_led_4 <= 1;

          if(r_spi_master_state != SPI_TRANSFERING) begin
            r_spi_master_state <= SPI_TRANSFERING;
          end // end if

        end // end case statement

        SPI_TRANSFERING:  begin

          w_spi_master_tx_data_ready <= 0;

          // handling sending data
          if( (r_spi_master_tx_dv == 0) && (w_spi_master_tx_ready) ) begin

            // for sensing up to 4 Bytes
            case (r_spi_master_tx_counter)

              0:  begin // end case statement
                r_temp_tx [7:0] <= r_spi_master_tx_data [7:0];
                r_spi_master_tx_counter <= 1;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              1:  begin
                r_temp_tx [7:0] <= r_spi_master_tx_data [15:8];
                r_spi_master_tx_counter <= 2;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              2:  begin
                r_temp_tx [7:0] <= r_spi_master_tx_data [23:16];
                r_spi_master_tx_counter <= 3;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              3:  begin
                r_temp_tx [7:0] <= r_spi_master_tx_data [31:24];
                r_spi_master_tx_counter <= 4;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              default:
                r_spi_master_state <= SPI_INITIALIZED;
              /*
              default:  begin
                r_spi_master_state <= SPI_INITIALIZED;
                r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
              end // end default case statement
              */
            endcase // end case TX

          end // end if
          else begin
            r_spi_master_tx_dv <= 0;
          end // end else

          // handling Rx line
          if(w_spi_master_rx_dv) begin

            // for receiving up to 4 Bytes
            if( w_spi_master_rx_data_count == 0) begin
              r_spi_master_rx_data [7:0] <= w_temp_rx [7:0];
            end // end if
            else if( w_spi_master_rx_data_count == 1) begin
              r_spi_master_rx_data [15:8] <= w_temp_rx [7:0];
            end // end if
            else if( w_spi_master_rx_data_count == 2) begin
              r_spi_master_rx_data [23:16] <= w_temp_rx [7:0];
            end // end if
            else if( w_spi_master_rx_data_count == 3) begin
              r_spi_master_rx_data [31:24] <= w_temp_rx [7:0];
            end // end if

          end // end if RX
        end // end case statement

        // this should not happen, ever
        default:  begin
          r_spi_master_state <= SPI_UNKNOWN;
          r_spi_master_reset <= 0;

        end // end default case statement

      endcase // end case spi state machine

      // start spi transfer after 1000 clks, approx. 62,5 us
      if(r_cycle_counter[20] ) begin
        w_spi_master_tx_data_ready <= 1;
        r_cycle_counter <= 0;
      end // end if

      // ADC state machine
      case (r_adc_master_state)
        ADC_UNKNOWN:  begin
          if (!r_spi_master_adc_reset)  begin
            r_spi_master_adc_reset <= 1;
          end // end if
          else begin
            r_spi_master_adc_tx_counter <= 0;
            r_spi_master_adc_rx_counter <= 0;

            r_spi_master_adc_tx_data_count <= 0;

            r_adc_master_state <= ADC_READY;

            end // end else

        end // end case statement

        ADC_READY:  begin

        end // end case statement

        ADC_SAMPLING:  begin

        end // end case statement

        ADC_ACQUIRING:  begin

        end // end case statement

        default:  begin

        end // end default case statement
      endcase // end case adc state machine



    end  /// end always


    // SPI MASTER to MCU
    assign PIN_2 = w_spi_master_clk;
    assign PIN_3 = w_spi_master_mosi;
    assign PIN_4 = w_spi_master_miso;
    assign PIN_5 = w_spi_master_cs;

    // SPI MASTER to ADC


    // TEST OUTPUT FOR INDICATING INTERNAL STATES
    assign PIN_10 = w_led_1;
    assign PIN_11 = w_led_2;
    assign PIN_12 = w_led_3;
    assign PIN_13 = w_led_4;

    /*
    assign PIN_10 = r_spi_master_reset;
    assign PIN_11 = w_spi_master_tx_ready;
    assign PIN_12 = r_spi_master_tx_dv;
    assign PIN_13 = w_spi_master_tx_data_ready;
    */
    assign PIN_1 = CLK;

endmodule
