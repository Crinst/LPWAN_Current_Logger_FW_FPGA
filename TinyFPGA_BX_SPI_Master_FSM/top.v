// look in pins.pcf for all the pin names on the TinyFPGA BX board


module top (
    input CLK,      // 16MHz clock
    output USBPU,   // USB pull-up resistor

    output LED,     // User/boot LED next to power LED
    output PIN_1,   // custom output PIN A2

    output PIN_2,   // SPI MCU SCLK
    output PIN_3,   // SPI MCU MOSI
    input PIN_4,    // SPI MCU MISO
    output PIN_5,   // SPI MCU CS
    output PIN_6,   // SPI MCU CLK OUT

    input PIN_7,    // ADC RVS
    input PIN_8,    // SPI ADC MISO
    output PIN_10,  // SPI ADC MOSI
    output PIN_11,  // SPI ADC CLK
    output PIN_12,  // SPI ADC CS
    output PIN_13,   // SPI ADC CONVS

    output PIN_14,  // mA range
    output PIN_15,  // uA range
    output PIN_16   // nA range

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

    // *********************** A D C  - RANGE - 3CH *****************************************//
    //***************************************************************************************//

    // define all possible ranges for measuring current
    localparam  ADC_RANGE_MA = 0;
    localparam  ADC_RANGE_UA = 1;
    localparam  ADC_RANGE_NA = 2;
    localparam  ADC_RANGE_UNKNOWN = 3;

    localparam  AdC_RANGE_LIMIT_LOW = 2100;
    localparam  AdC_RANGE_LIMIT_HIGH = 220000;

    reg w_adc_master_range_ma = 1;
    reg w_adc_master_range_ua = 0;
    reg w_adc_master_range_na = 0;


    // ADC range state reg for current range and previos range
    reg [3:0] r_adc_master_range = ADC_RANGE_UNKNOWN;
    reg [3:0] r_adc_master_last_range = ADC_RANGE_UNKNOWN;

    // big 40 Byte register meant for storing 10 measured samples for increased throughput created 2 with ability to switch between each as receive/transmit continue
    reg [319:0] r_adc_master_tx_buffer_1 = 0;
    reg [319:0] r_adc_master_tx_buffer_2 = 0;

    reg [31:0] r_adc_master_rx_buffer_1 = 0;
    reg [31:0] r_adc_master_rx_buffer_2 = 0;

    // constants for selecting rx, tx buffer
    localparam  ADC_TX_BUFFER_1 = 0;
    localparam  ADC_TX_BUFFER_2 = 1;
    localparam  ADC_RX_BUFFER_1 = 0;
    localparam  ADC_RX_BUFFER_2 = 1;

    // rx, tx buffer selector
    reg r_adc_master_tx_buffer_selector = ADC_TX_BUFFER_2;
    reg r_adc_master_rx_buffer_selector = ADC_RX_BUFFER_2;

    // define all states for ADC range check state machine
    localparam  ADC_RANGE_STATE_CHECKED = 0;
    localparam  ADC_RANGE_STATE_UNCHECKED = 1;
    localparam  ADC_RANGE_STATE_DONE = 2;

    // adc range state machine status
    reg [3:0] r_adc_master_range_state = ADC_RANGE_STATE_DONE;

    // adc rx reading counter
    reg [7:0] r_adc_master_rx_reading_counter = 0;

    // adc tx byte counter
    reg [7:0] r_adc_master_tx_byte_counter = 0;

    // adc readings - number of reading before initializing transmission
    // value between 1 to 10 readings
    localparam  ADC_READINGS = 10;


    // *********************** A D C  - RANGE - 3CH - E N D *********************************//
    //***************************************************************************************//

    // ******************** S P I - ADC - 60 MHz ********************************************//
    //***************************************************************************************//

    // define testing SPI Interface
    parameter SPI_MODE_ADC = 0; // CPOL = 0, CPHA = 0 ===> compatible with STM basic settings
    parameter CLKS_PER_HALF_BIT_ADC = 16;  // 2 MHz
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
    wire w_spi_master_adc_rvs;
    reg r_spi_master_adc_convst;
    reg r_spi_master_adc_cs_control = 0;

    // status flag for initializing start of another conversion
    reg r_adc_master_conversion = 0;

    // counters to define tx, rx bytes
    reg [2:0] r_spi_master_adc_tx_data_count = 4;
    wire [2:0] w_spi_master_adc_rx_data_count;

    // conters to point in registers
    reg [3:0] r_spi_master_adc_tx_counter = 0;
    reg [3:0] r_spi_master_adc_rx_counter = 0;

    // tx data -- 11 22 33 44 bytes
    reg [31:0] r_spi_master_adc_tx_data = 740365835;
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
      .i_Rst_L(r_spi_master_adc_reset),
      .i_Clk(CLK),

      // MOSI
      .i_TX_Count(r_spi_master_adc_tx_data_count),
      .i_TX_Byte(r_temp_adc_tx),
      .i_TX_DV(r_spi_master_adc_tx_dv),
      .o_TX_Ready(w_spi_master_adc_tx_ready),

      // MISO
      .o_RX_Count(w_spi_master_adc_rx_data_count),
      .o_RX_DV(w_spi_master_adc_rx_dv),
      .o_RX_Byte(w_temp_adc_rx),

      // SPI signals

      .o_SPI_Clk(w_spi_master_adc_clk),
      .i_SPI_MISO(w_spi_master_adc_miso),
      .o_SPI_MOSI(w_spi_master_adc_mosi),
      .o_SPI_CS_n(w_spi_master_adc_cs)
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
    parameter MAX_BYTES_PER_CS = 40; // send maximum of 4 bytes before changing CS line

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
    reg [5:0] r_spi_master_tx_data_count = 40;
    wire [5:0] w_spi_master_rx_data_count;

    // conters to point in registers
    reg [7:0] r_spi_master_tx_counter = 0;
    reg [7:0] r_spi_master_rx_counter = 0;

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
          r_spi_master_tx_data_count <= 40;
          w_led_4 <= 1;

          if(r_spi_master_state != SPI_TRANSFERING) begin
            r_spi_master_state <= SPI_TRANSFERING;
          end // end if

        end // end case statement

        SPI_TRANSFERING:  begin

          w_spi_master_tx_data_ready <= 0;

          // handling sending data
          if( (r_spi_master_tx_dv == 0) && (w_spi_master_tx_ready) ) begin

            // for sensing up to 40 Bytes
            case (r_spi_master_tx_counter)

              0:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [7:0];
                  r_temp_tx [7:0] <= 0;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [7:0];
                  r_temp_tx [7:0] <= 0;
                end // end else

                r_spi_master_tx_counter <= 1;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              1:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [15:8];
                  r_temp_tx [7:0] <= 1*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [15:8];
                  r_temp_tx [7:0] <= 1;
                end // end else

                r_spi_master_tx_counter <= 2;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              2:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [23:16];
                  r_temp_tx [7:0] <= 2*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [23:16];
                  r_temp_tx [7:0] <= 2;
                end // end else

                r_spi_master_tx_counter <= 3;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              3:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [31:24];
                  r_temp_tx [7:0] <= 3*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [31:24];
                  r_temp_tx [7:0] <= 3;
                end // end else

                r_spi_master_tx_counter <= 4;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              4:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [39:32];
                  r_temp_tx [7:0] <= 4*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [39:32];
                  r_temp_tx [7:0] <= 4;
                end // end else

                r_spi_master_tx_counter <= 5;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              5:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [47:40];
                  r_temp_tx [7:0] <= 5*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [47:40];
                  r_temp_tx [7:0] <= 5;
                end // end else

                r_spi_master_tx_counter <= 6;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              6:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [55:48];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [55:48];
                end // end else

                r_spi_master_tx_counter <= 7;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              7:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [63:56];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [63:56];
                end // end else

                r_spi_master_tx_counter <= 8;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              8:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [71:64];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [71:64];
                end // end else

                r_spi_master_tx_counter <= 9;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              9:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [79:72];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [79:72];
                end // end else

                r_spi_master_tx_counter <= 10;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              10:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [87:80];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [87:80];
                end // end else

                r_spi_master_tx_counter <= 11;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              11:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [95:88];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [95:88];
                end // end else

                r_spi_master_tx_counter <= 12;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              12:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [103:96];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [103:96];
                end // end else

                r_spi_master_tx_counter <= 13;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              13:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [111:104];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [111:104];
                end // end else

                r_spi_master_tx_counter <= 14;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              14:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [119:112];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [119:112];
                end // end else

                r_spi_master_tx_counter <= 15;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              15:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [127:120];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [127:120];
                end // end else

                r_spi_master_tx_counter <= 16;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              16:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [135:128];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [135:128];
                end // end else

                r_spi_master_tx_counter <= 17;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              17:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [143:136];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [143:136];
                end // end else

                r_spi_master_tx_counter <= 18;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              18:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [151:144];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [151:144];
                end // end else

                r_spi_master_tx_counter <= 19;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              19:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [159:152];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [159:152];
                end // end else

                r_spi_master_tx_counter <= 20;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              20:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [167:160];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [167:160];
                end // end else

                r_spi_master_tx_counter <= 21;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              21:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [175:168];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [175:168];
                end // end else

                r_spi_master_tx_counter <= 22;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              22:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [183:176];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [183:176];
                end // end else

                r_spi_master_tx_counter <= 23;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              23:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [191:184];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [191:184];
                end // end else

                r_spi_master_tx_counter <= 24;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              24:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [199:192];
                end // end if
                else  begin
                  r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [199:192];
                end // end else

                r_spi_master_tx_counter <= 25;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              25:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [207:200];
                  r_temp_tx [7:0] <= 26*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [207:200];
                  r_temp_tx [7:0] <= 26;
                end // end else

                r_spi_master_tx_counter <= 26;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              26:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [215:208];
                  r_temp_tx [7:0] <= 27*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [215:208];
                  r_temp_tx [7:0] <= 27;
                end // end else

                r_spi_master_tx_counter <= 27;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              27:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [223:216];
                  r_temp_tx [7:0] <= 28*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [223:216];
                  r_temp_tx [7:0] <= 28;
                end // end else

                r_spi_master_tx_counter <= 28;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              28:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [231:224];
                  r_temp_tx [7:0] <= 29*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [231:224];
                  r_temp_tx [7:0] <= 29;
                end // end else

                r_spi_master_tx_counter <= 29;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              29:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [239:232];
                  r_temp_tx [7:0] <= 30*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [239:232];
                  r_temp_tx [7:0] <= 30;
                end // end else

                r_spi_master_tx_counter <= 30;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              30:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [247:240];
                  r_temp_tx [7:0] <= 31*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [247:240];
                  r_temp_tx [7:0] <= 31;
                end // end else

                r_spi_master_tx_counter <= 31;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              31:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [255:248];
                  r_temp_tx [7:0] <= 32*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [255:248];
                  r_temp_tx [7:0] <= 32;
                end // end else

                r_spi_master_tx_counter <= 32;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              32:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [263:256];
                  r_temp_tx [7:0] <= 33*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [263:256];
                  r_temp_tx [7:0] <= 33;
                end // end else

                r_spi_master_tx_counter <= 33;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              33:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [271:264];
                  r_temp_tx [7:0] <= 34*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [271:264];
                  r_temp_tx [7:0] <= 34;
                end // end else

                r_spi_master_tx_counter <= 34;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              34:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [279:272];
                  r_temp_tx [7:0] <= 35*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [279:272];
                  r_temp_tx [7:0] <= 35;
                end // end else

                r_spi_master_tx_counter <= 35;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              35:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [287:280];
                  r_temp_tx [7:0] <= 36*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [287:280];
                  r_temp_tx [7:0] <= 36;
                end // end else

                r_spi_master_tx_counter <= 36;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              36:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [295:288];
                  r_temp_tx [7:0] <= 37*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [295:288];
                  r_temp_tx [7:0] <= 37;
                end // end else

                r_spi_master_tx_counter <= 37;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              37:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [303:296];
                  r_temp_tx [7:0] <= 38*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [303:296];
                  r_temp_tx [7:0] <= 38;
                end // end else

                r_spi_master_tx_counter <= 38;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              38:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [311:304];
                  r_temp_tx [7:0] <= 39*2;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [311:304];
                  r_temp_tx [7:0] <= 39;
                end // end else

                r_spi_master_tx_counter <= 39;
                //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
                r_spi_master_tx_dv <= 1;
              end // end case statement

              39:  begin // end case statement
                if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [319:312];
                  r_temp_tx [7:0] <= 80;
                end // end if
                else  begin
                  //r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [319:312];
                  r_temp_tx [7:0] <= 40;

                end // end else

                r_spi_master_tx_counter <= 40;
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
        //w_spi_master_tx_data_ready <= 1;
        r_adc_master_conversion <= 1;
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
          r_spi_master_adc_tx_counter <= 0;
          r_spi_master_adc_rx_counter <= 0;

          r_spi_master_adc_tx_data_count <= 4;

          if(r_adc_master_conversion) begin
            r_adc_master_state <= ADC_SAMPLING;
          end

        end // end case statement

        ADC_SAMPLING:  begin

          if(r_adc_master_conversion) begin
            r_adc_master_conversion <= 0;
            r_spi_master_adc_cs_control <= 0;
            r_spi_master_adc_convst <= 1;
          end // end if
          else  begin
            r_spi_master_adc_convst <= 0;
            r_spi_master_adc_cs_control <= 1;
            r_adc_master_state <= ADC_ACQUIRING;
          end // end else


        end // end case statement

        ADC_ACQUIRING:  begin

          //if(w_spi_master_adc_rvs && w_spi_master_rx_dv)  begin
          if(w_spi_master_adc_rx_dv)  begin
            // for receiving up to 4 Bytes
            if( w_spi_master_adc_rx_data_count == 0) begin
              r_spi_master_adc_rx_data [7:0] <= w_temp_adc_rx [7:0];
              //r_spi_master_adc_rx_data [7:0] <= 55;
              r_spi_master_adc_rx_counter <= 1;
              //r_spi_master_adc_rx_counter <= r_spi_master_adc_rx_counter + 1;
            end // end if
            else if( w_spi_master_adc_rx_data_count == 1) begin
              r_spi_master_adc_rx_data [15:8] <= w_temp_adc_rx [7:0];
              //r_spi_master_adc_rx_data [15:8] <= 66;
              r_spi_master_adc_rx_counter <= 2;
              //r_spi_master_adc_rx_counter <= r_spi_master_adc_rx_counter + 1;
            end // end if
            else if( w_spi_master_adc_rx_data_count == 2) begin
              r_spi_master_adc_rx_data [23:16] <= w_temp_adc_rx [7:0];
              //r_spi_master_adc_rx_data [23:16] <= 77;
              r_spi_master_adc_rx_counter <= 3;
              //r_spi_master_adc_rx_counter <= r_spi_master_adc_rx_counter + 1;
            end // end if
            else if( w_spi_master_adc_rx_data_count == 3) begin
              r_spi_master_adc_rx_data [31:24] <= w_temp_adc_rx [7:0];
              //r_spi_master_adc_rx_data [31:24] <= 88;
              r_spi_master_adc_rx_counter <= 4;
              //r_spi_master_adc_rx_counter <= r_spi_master_adc_rx_counter + 1;
            end // end if

          end // end ADC RX


          // handling sending data
          if( (r_spi_master_adc_tx_dv == 0) && (w_spi_master_adc_tx_ready) ) begin

            // for sensing up to 4 Bytes
            case (r_spi_master_adc_tx_counter)

              0:  begin // end case statement
                r_temp_adc_tx [7:0] <= r_spi_master_adc_tx_data [7:0];
                //r_spi_master_adc_tx_counter <= 1;
                r_spi_master_adc_tx_counter <= r_spi_master_adc_tx_counter + 1;
                r_spi_master_adc_tx_dv <= 1;
              end // end case statement

              1:  begin
                r_temp_adc_tx [7:0] <= r_spi_master_adc_tx_data [15:8];
                //r_spi_master_adc_tx_counter <= 2;
                r_spi_master_adc_tx_counter <= r_spi_master_adc_tx_counter + 1;
                r_spi_master_adc_tx_dv <= 1;
              end // end case statement

              2:  begin
                r_temp_adc_tx [7:0] <= r_spi_master_adc_tx_data [23:16];
                //r_spi_master_adc_tx_counter <= 3;
                r_spi_master_adc_tx_counter <= r_spi_master_adc_tx_counter + 1;
                r_spi_master_adc_tx_dv <= 1;
              end // end case statement

              3:  begin
                r_temp_adc_tx [7:0] <= r_spi_master_adc_tx_data [31:24];
                //r_spi_master_adc_tx_counter <= 4;
                r_spi_master_adc_tx_counter <= r_spi_master_adc_tx_counter + 1;
                r_spi_master_adc_tx_dv <= 1;
              end // end case statement

              // overflow --> go back to being ready for new conversion cycle
              default:  begin
                //r_adc_master_state <= ADC_READY;
                r_temp_adc_tx [7:0] <= 99;
                //r_spi_master_adc_tx_counter <= 1;
                //r_spi_master_adc_tx_counter <= r_spi_master_adc_tx_counter + 1;
                //r_spi_master_adc_tx_dv <= 1;
              end // end default case statement

            endcase // end case TX

          end // end if
          else begin
            r_spi_master_adc_tx_dv <= 0;
          end // end else
          // end ADC TX

          if( (r_spi_master_adc_tx_data_count == r_spi_master_adc_rx_counter) && (r_spi_master_state == SPI_INITIALIZED) )  begin
          //if( ( (r_spi_master_adc_tx_counter-1) == w_spi_master_adc_rx_data_count) && (r_spi_master_state == SPI_INITIALIZED) )  begin

            //r_spi_master_tx_data <= r_spi_master_adc_rx_data;

            //r_adc_master_rx_buffer_1 [31:0] <= (r_spi_master_adc_rx_data [23:16] >> 6) | (r_spi_master_adc_rx_data [15:8] << 2) | (r_spi_master_adc_rx_data [7:0] << 10);

            if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
              r_adc_master_rx_buffer_2 <= (r_spi_master_adc_rx_data [23:16] >> 6) | (r_spi_master_adc_rx_data [15:8] << 2) | (r_spi_master_adc_rx_data [7:0] << 10);
            end // end if
            else if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_2)  begin
              r_adc_master_rx_buffer_1 <= (r_spi_master_adc_rx_data [23:16] >> 6) | (r_spi_master_adc_rx_data [15:8] << 2) | (r_spi_master_adc_rx_data [7:0] << 10);
            end // end if

            //w_spi_master_tx_data_ready <= 1;
            r_adc_master_state <= ADC_READY;
            r_adc_master_range_state <= ADC_RANGE_STATE_UNCHECKED;

          end // end if

        end // end case statement

        // this should not happen, ever
        default:  begin
          r_adc_master_state <= ADC_UNKNOWN;
          r_spi_master_adc_reset <= 0;

        end // end default case statement

      endcase // end case adc state machine


      case (r_adc_master_range_state)

        ADC_RANGE_STATE_DONE: begin


        end // end case statement

        ADC_RANGE_STATE_CHECKED:  begin

          case (r_adc_master_rx_reading_counter)

            0:  begin
              if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                r_adc_master_tx_buffer_2 [31:0] <= r_adc_master_rx_buffer_1 [31:0];
              end // end if
              else  begin
                r_adc_master_tx_buffer_1 [31:0] <= r_adc_master_rx_buffer_1 [31:0];
              end // end else

              //r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;
              r_adc_master_rx_reading_counter <= 1;
            end // end case statement

            1:  begin
              if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                r_adc_master_tx_buffer_2 [63:32] <= r_adc_master_rx_buffer_1 [31:0];
              end // end if
              else  begin
                r_adc_master_tx_buffer_1 [63:32] <= r_adc_master_rx_buffer_1 [31:0];
              end // end else

              //r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;
              r_adc_master_rx_reading_counter <= 2;
            end // end case statement

            2:  begin
              if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                r_adc_master_tx_buffer_2 [95:64] <= r_adc_master_rx_buffer_1 [31:0];
              end // end if
              else  begin
                r_adc_master_tx_buffer_1 [95:64] <= r_adc_master_rx_buffer_1 [31:0];
              end // end else

              //r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;
              r_adc_master_rx_reading_counter <= 3;
            end // end case statement

            3:  begin
              if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                r_adc_master_tx_buffer_2 [127:96] <= r_adc_master_rx_buffer_1 [31:0];
              end // end if
              else  begin
                r_adc_master_tx_buffer_1 [127:96] <= r_adc_master_rx_buffer_1 [31:0];
              end // end else

              //r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;
              r_adc_master_rx_reading_counter <= 4;
            end // end case statement

            4:  begin
              if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                r_adc_master_tx_buffer_2 [159:128] <= r_adc_master_rx_buffer_1 [31:0];
              end // end if
              else  begin
                r_adc_master_tx_buffer_1 [159:128] <= r_adc_master_rx_buffer_1 [31:0];
              end // end else

              //r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;
              r_adc_master_rx_reading_counter <= 5;
            end // end case statement

            5:  begin
              if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                r_adc_master_tx_buffer_2 [191:160] <= r_adc_master_rx_buffer_1 [31:0];
              end // end if
              else  begin
                r_adc_master_tx_buffer_1 [191:160] <= r_adc_master_rx_buffer_1 [31:0];
              end // end else

              //r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;
              r_adc_master_rx_reading_counter <= 6;
            end // end case statement

            6:  begin
              if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                r_adc_master_tx_buffer_2 [223:192] <= r_adc_master_rx_buffer_1 [31:0];
              end // end if
              else  begin
                r_adc_master_tx_buffer_1 [223:192] <= r_adc_master_rx_buffer_1 [31:0];
              end // end else

              //r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;
              r_adc_master_rx_reading_counter <= 7;
            end // end case statement

            7:  begin
              if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                r_adc_master_tx_buffer_2 [255:224] <= r_adc_master_rx_buffer_1 [31:0];
              end // end if
              else  begin
                r_adc_master_tx_buffer_1 [255:224] <= r_adc_master_rx_buffer_1 [31:0];
              end // end else

              //r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;
              r_adc_master_rx_reading_counter <= 8;
            end // end case statement

            8:  begin
              if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                r_adc_master_tx_buffer_2 [287:256] <= r_adc_master_rx_buffer_1 [31:0];
              end // end if
              else  begin
                r_adc_master_tx_buffer_1 [287:256] <= r_adc_master_rx_buffer_1 [31:0];
              end // end else

              //r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;
              r_adc_master_rx_reading_counter <= 9;
            end // end case statement

            9:  begin
              if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                r_adc_master_tx_buffer_2 [319:288] <= r_adc_master_rx_buffer_1 [31:0];
              end // end if
              else  begin
                r_adc_master_tx_buffer_1 [319:288] <= r_adc_master_rx_buffer_1 [31:0];
              end // end else

              //r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;
              r_adc_master_rx_reading_counter <= 10;
            end // end case statement

            default:  begin
              /*if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                r_adc_master_tx_buffer_2 [31:0] <= r_adc_master_rx_buffer_1 [31:0];
              end // end if
              else  begin
                r_adc_master_tx_buffer_1 [31:0] <= r_adc_master_rx_buffer_1 [31:0];
              end // end else
              */
              r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;
              w_led_4 <= 1;
            end // end default case statement

          endcase // end rx reading counter case

          if(r_adc_master_rx_reading_counter == (ADC_READINGS-1) ) begin

            if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
              r_adc_master_tx_buffer_selector <= ADC_TX_BUFFER_2;
            end // end if
            else  begin
              r_adc_master_tx_buffer_selector <= ADC_TX_BUFFER_1;
            end // end else

            r_adc_master_rx_reading_counter <= 0;

            w_spi_master_tx_data_ready <= 1;

          end // end if

          r_adc_master_range_state <= ADC_RANGE_STATE_DONE;

        end // end case statement

        ADC_RANGE_STATE_UNCHECKED:  begin
          r_adc_master_last_range <= r_adc_master_range;

          // range selection in next clock proper range will be applied

          // nA to uA
          if(r_adc_master_last_range == ADC_RANGE_NA && r_adc_master_rx_buffer_1 >= AdC_RANGE_LIMIT_HIGH) begin
            r_adc_master_range <= ADC_RANGE_UA;

            w_adc_master_range_na <= 0;
            w_adc_master_range_ua <= 1;
            w_adc_master_range_ma <= 0;

          end // end if
          // uA to mA
          else if(r_adc_master_last_range == ADC_RANGE_UA && r_adc_master_rx_buffer_1 >= AdC_RANGE_LIMIT_HIGH)  begin
            r_adc_master_range <= ADC_RANGE_MA;

            w_adc_master_range_na <= 0;
            w_adc_master_range_ua <= 0;
            w_adc_master_range_ma <= 1;

          end // end if
          // mA to uA
          else if(r_adc_master_last_range == ADC_RANGE_MA && r_adc_master_rx_buffer_1 <= AdC_RANGE_LIMIT_LOW)  begin
            r_adc_master_range <= ADC_RANGE_UA;

            w_adc_master_range_na <= 0;
            w_adc_master_range_ua <= 1;
            w_adc_master_range_ma <= 0;

          end // end if
          // uA to nA
          else if(r_adc_master_last_range == ADC_RANGE_UA && r_adc_master_rx_buffer_1 <= AdC_RANGE_LIMIT_LOW)  begin
            r_adc_master_range <= ADC_RANGE_NA;

            w_adc_master_range_na <= 1;
            w_adc_master_range_ua <= 0;
            w_adc_master_range_ma <= 0;

          end // end if
          else  begin
            //r_adc_master_range <= ADC_RANGE_MA;

            //w_adc_master_range_na <= 0;
            //w_adc_master_range_ua <= 0;
            //w_adc_master_range_ma <= 1;

          end // end else

          r_adc_master_rx_buffer_1 [31:31] <= w_adc_master_range_ma;
          r_adc_master_rx_buffer_1 [30:30] <= w_adc_master_range_ua;
          r_adc_master_rx_buffer_1 [29:29] <= w_adc_master_range_na;

          r_adc_master_range_state <= ADC_RANGE_STATE_CHECKED;

        end // end case statement

        // this should never happen
        default:  begin
          r_adc_master_range <= ADC_RANGE_MA;

          w_adc_master_range_na <= 0;
          w_adc_master_range_ua <= 0;
          w_adc_master_range_ma <= 1;
        end // end default case statement

      endcase // end case adc range state machine





    end  /// end always


    // SPI MASTER to MCU
    assign PIN_2 = w_spi_master_clk;
    assign PIN_3 = w_spi_master_mosi;
    assign PIN_4 = w_spi_master_miso;
    assign PIN_5 = w_spi_master_cs;

    // SPI MASTER to ADC
    assign PIN_7 = w_spi_master_adc_rvs;
    assign PIN_8 = w_spi_master_adc_miso;    // SPI ADC MISO
    assign PIN_10 = w_spi_master_adc_mosi;
    assign PIN_11 = w_spi_master_adc_clk;
    assign PIN_12 = (w_spi_master_adc_cs && r_spi_master_adc_cs_control);
    //assign PIN_13 = r_spi_master_adc_convst;

    // ADC RANGE
    assign PIN_14 = w_adc_master_range_ma;  // mA range
    assign PIN_15 = w_adc_master_range_ua;  // uA range
    assign PIN_16 = w_adc_master_range_na;   // nA range

    // TEST OUTPUT FOR INDICATING INTERNAL STATES
    /*assign PIN_10 = w_led_1;
    assign PIN_11 = w_led_2;
    assign PIN_12 = w_led_3;
    assign PIN_13 = w_led_4;
    */
    /*
    assign PIN_10 = r_spi_master_reset;
    assign PIN_11 = w_spi_master_tx_ready;
    assign PIN_12 = r_spi_master_tx_dv;
    assign PIN_13 = w_spi_master_tx_data_ready;
    */
    //assign PIN_13 = w_spi_master_adc_tx_ready;
    assign PIN_13 = w_spi_master_tx_data_ready;
    //assign PIN_12 = r_spi_master_adc_tx_dv;

    assign PIN_1 = CLK;

endmodule
