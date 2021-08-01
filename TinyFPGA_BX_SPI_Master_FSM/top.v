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
    input PIN_6,   // DATA SEND OUT ACK

    input PIN_7,    // ADC RVS
    input PIN_8,    // SPI ADC MISO
    output PIN_10,  // SPI ADC MOSI
    output PIN_11,  // SPI ADC CLK
    output PIN_12,  // SPI ADC CS
    output PIN_13,   // SPI ADC CONVS

    output PIN_14,  // mA range
    output PIN_15,  // uA range
    output PIN_16,   // nA range
    output PIN_17,  // mA range AS
    output PIN_18,  // uA range AS
    output PIN_19   // nA range AS


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

    wire w_clk_240mhz;
    wire w_clk_240mhz_locked;   // checking for clock phase locking

    // setting up PLL for 240 MHz main clock
    pll pll240( .clock_in(CLK), .clock_out(w_clk_240mhz), .locked(w_clk_240mhz_locked) );

    // *********************** P L L - 240 MHz - E N D **************************************//
    //***************************************************************************************//


    // ****************************** L E D *************************************************//
    //******************************* 16 MHz ************************************************//
    /*
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
*/
    // ****************************** L E D - E N D *****************************************//
    //******************************* 16 MHz ************************************************//

    // ****************************** L E D *************************************************//
    //******************************* 240 MHz ***********************************************//

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

    //assign PIN_1 = w_blink_output_2;
    assign LED = w_blink_output_2;

    // ****************************** L E D - E N D *****************************************//
    //******************************* 240 MHz ***********************************************//

    // *********************** A D C  - RANGE - 3CH *****************************************//
    //***************************************************************************************//

    // adc readings - number of reading before initializing transmission, all buffers must be able to handle x readings before sending
    // value between 1 to 10 readings
    localparam  ADC_READINGS = 30;

    // these addresses needs to be in first byte in receive buffer followed by command byte and then actual data with size up to 4 bytes
    localparam  FPGA_ADDR = 85; // 0x55 01010101
    localparam  ADC_ADDR = 170; // 0xAA 10101010

    // define all possible ranges for measuring current
    localparam  ADC_RANGE_MA = 0;
    localparam  ADC_RANGE_UA = 1;
    localparam  ADC_RANGE_NA = 2;
    localparam  ADC_RANGE_UNKNOWN = 3;

    // set range limits low and high in 32bit format
    localparam  ADC_RANGE_LIMIT_LOW = 2100;
    localparam  ADC_RANGE_LIMIT_HIGH = 220000;

    // set by default higher/largest range = mA
    reg w_adc_master_range_ma = 1;
    reg w_adc_master_range_ua = 0;
    reg w_adc_master_range_na = 0;

    // status flag to indicate adc correctly configured
    reg r_adc_master_configured = 0;


    // ADC range state reg for current range and previos range
    reg [2:0] r_adc_master_range = ADC_RANGE_MA;
    reg [2:0] r_adc_master_last_range = ADC_RANGE_MA;

    // ADC last/currently measured value, used for checking ranges
    reg [31:0] r_adc_master_last_measured_value = 0;

    // big 40 Byte register meant for storing 10 measured samples for increased throughput created 2 buffers with ability to switch between each as receive/transmit continue
    //reg [319:0] r_adc_master_tx_buffer_1 = 0;
    //reg [319:0] r_adc_master_tx_buffer_2 = 0;
    // big buffer for buffering before starting SPI MCU transfer, size must be equal or greater than number of ADC_READINGS * 4Bytes(one reading sample)
    reg [7:0] r_adc_master_tx_buffer_1 [0:ADC_READINGS*4];
    reg [7:0] r_adc_master_tx_buffer_2 [0:ADC_READINGS*4];

    // small 4 Byte registers for storing current received value from ADC, this register is copied into bug register for sending to mcu
    reg [31:0] r_adc_master_rx_buffer_1 = 0;
    reg [31:0] r_adc_master_rx_buffer_2 = 0;

    // constants for selecting rx, tx buffer
    localparam  ADC_TX_BUFFER_1 = 0;
    localparam  ADC_TX_BUFFER_2 = 1;
    localparam  ADC_RX_BUFFER_1 = 0;
    localparam  ADC_RX_BUFFER_2 = 1;

    // rx, tx buffer selector
    // for receiving and transmitting data, there are 2 independent buffers selected by selectors further down
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

    // *********************** A D C  - RANGE - 3CH - E N D *********************************//
    //***************************************************************************************//

    // ******************** S P I - ADC - 60 MHz ********************************************//
    //***************************************************************************************//

    // define testing SPI Interface
    parameter SPI_MODE_ADC = 0; // CPOL = 0, CPHA = 0 ===> compatible with STM basic settings
    parameter CLKS_PER_HALF_BIT_ADC = 3;  // select 3=10MHz for 60MHz clk source
    parameter CS_CLK_DELAY_ADC = 4;  // select 4 for 60MHz clk source
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

    // counters to point in registers
    reg [3:0] r_spi_master_adc_tx_counter = 0;
    reg [3:0] r_spi_master_adc_rx_counter = 0;

    // default tx data -- 11 22 33 44 bytes
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

    reg [7:0] r_adc_sample_delay = 0;
    localparam  ADC_SAMPLE_DELAY = 45; // needed approx. 666ns based on ADS8691 datasheet; select 45=750ns for 60MHz clk source
    localparam  ADC_CS_CONVS_DELAY = 10; // added so cs line will be Dig. LOW before conversion start; select 10=166,67ns for 60MHz clk source

    // define how many samples will be taken, before adding to mcu buffer
    // simply allow higher sampling rate for range changing, but send to MCU with lower sample sate
    localparam  ADC_MEASUREMENT_UNDERSAMPLE = 5;

    reg [3:0] r_adc_measure_under_sample = 0;

    // indication for stard sending data out to MCU, 0=doNOT send data, 1 = MCU is ready for data
    wire w_adc_master_mcu_transfer_ready;

    SPI_Master_With_Single_CS
    #(
      .SPI_MODE(SPI_MODE_ADC),
      .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT_ADC),
      .MAX_BYTES_PER_CS(MAX_BYTES_PER_CS_ADC),
      .CS_INACTIVE_CLKS(CS_CLK_DELAY_ADC)
    ) spiMasterADC
    (
      .i_Rst_L(r_spi_master_adc_reset),
      .i_Clk(w_clk_240mhz),

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
    parameter CLKS_PER_HALF_BIT = 3;  // select 3=10MHz for 60MHz clk source
    parameter CS_CLK_DELAY = 25;  // select 25 for 60MHz clk source
    //parameter MAX_BYTES_PER_CS = 40; // send maximum of 4 bytes before changing CS line
    parameter MAX_BYTES_PER_CS = ADC_READINGS*4; // send maximum of 4 bytes before changing CS line

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
    wire w_spi_master_mcu_clk;
    wire w_spi_master_mcu_mosi;
    wire w_spi_master_mcu_miso;
    wire w_spi_master_mcu_cs;

    // indicating data readiness for sending over SPI bus
    reg r_spi_master_data_ready = 0;

    // counters to define tx, rx bytes
    // size allocation must be adjusted according to adc readings to closes higher number of bits
    reg [6:0] r_spi_master_tx_data_count = ADC_READINGS*4;
    wire [6:0] w_spi_master_rx_data_count;

    // counters to point in registers
    reg [6:0] r_spi_master_tx_counter = 0;
    reg [6:0] r_spi_master_rx_counter = 0;

    // default tx data -- 11 22 33 44 bytes
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
      .i_Clk(w_clk_240mhz),

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

      .o_SPI_Clk(w_spi_master_mcu_clk),
      .i_SPI_MISO(w_spi_master_mcu_miso),
      .o_SPI_MOSI(w_spi_master_mcu_mosi),
      .o_SPI_CS_n(w_spi_master_mcu_cs)
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
    always @ (posedge w_clk_240mhz) begin

      // simple cycle counter 32b
      r_cycle_counter <= r_cycle_counter + 1;

      case (r_spi_master_state)

        SPI_UNKNOWN:  begin
          if (!r_spi_master_reset)  begin
            r_spi_master_reset <= 1;
          end // end if
          else begin
            //r_spi_master_tx_counter <= 0;
            //r_spi_master_rx_counter <= 0;

            //r_spi_master_tx_data_count <= 0;

            //w_led_1 <= 1;

            r_spi_master_state <= SPI_INITIALIZED;

          end // end else

        end // end case statement

        SPI_INITIALIZED:  begin
          r_spi_master_tx_counter <= 0;
          r_spi_master_rx_counter <= 0;

          r_spi_master_tx_data_count <= 0;

          w_led_2 <= 1;

          if (w_spi_master_tx_data_ready && w_adc_master_mcu_transfer_ready) begin
            w_led_3 <= 1;
            r_spi_master_state <= SPI_READY;
          end // end if

        end // end case statement

        SPI_READY:  begin

          if(r_spi_master_state != SPI_TRANSFERING) begin
            r_spi_master_tx_data_count <= ADC_READINGS*4;
            r_spi_master_state <= SPI_TRANSFERING;
            w_spi_master_tx_data_ready <= 0;
          end // end if

        end // end case statement

        SPI_TRANSFERING:  begin

          // handling sending data
          if( (r_spi_master_tx_dv == 0) && (w_spi_master_tx_ready) ) begin

            // sending bytes to MCU, tx counter selects which byte is send
            if( (r_spi_master_tx_counter < (ADC_READINGS*4) ) && (r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1) ) begin
              r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [r_spi_master_tx_counter];
              r_spi_master_tx_dv <= 1;
            end
            if( (r_spi_master_tx_counter < (ADC_READINGS*4) ) && (r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_2) ) begin
              r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [r_spi_master_tx_counter];
              r_spi_master_tx_dv <= 1;
            end

            r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;

            if ( (r_spi_master_tx_counter == (ADC_READINGS*4) ) ) begin
              r_spi_master_state <= SPI_INITIALIZED;
            end


            //if( (r_spi_master_tx_counter >= 0) && (r_spi_master_tx_counter < (ADC_READINGS*4) ) ) begin
            /*
            if( (r_spi_master_tx_counter < (ADC_READINGS*4) ) ) begin
              if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
                r_temp_tx [7:0] <= r_adc_master_tx_buffer_2 [r_spi_master_tx_counter];
                //r_temp_tx [7:0] <= r_spi_master_tx_counter*2;
              end // end if
              else  begin
                r_temp_tx [7:0] <= r_adc_master_tx_buffer_1 [r_spi_master_tx_counter];
                //r_temp_tx [7:0] <= r_spi_master_tx_counter;
              end // end else

              //r_spi_master_tx_counter <= 1;
              r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
              r_spi_master_tx_dv <= 1;

            end // end if
            else begin
              r_spi_master_state <= SPI_INITIALIZED;
            end // end else
            */

          end // end if

          else begin
            r_spi_master_tx_dv <= 0;
          end // end else

          // handling Rx line
          if(w_spi_master_rx_dv) begin

            // for receiving up to 4 Bytes
            case (w_spi_master_rx_data_count)
              0:  begin
                r_spi_master_rx_data [7:0] <= w_temp_rx [7:0];
              end
              1:  begin
                r_spi_master_rx_data [15:8] <= w_temp_rx [7:0];
              end
              2:  begin
                r_spi_master_rx_data [23:16] <= w_temp_rx [7:0];
              end
              3:  begin
                r_spi_master_rx_data [31:24] <= w_temp_rx [7:0];
              end
            endcase
            /*
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
            */

          end // end if RX
        end // end case statement

        // this should not happen, ever
        default:  begin
          r_spi_master_state <= SPI_UNKNOWN;
          r_spi_master_reset <= 0;

        end // end default case statement

      endcase // end case spi state machine




      // start spi transfer after 1mil clks, approx. 62,5 ms
      // 60MHz clock approx. 16,67 ns per clock >>> 100 us is about 6000 clocks

      if(r_cycle_counter >= 1200 ) begin
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

            r_adc_master_configured <= 0;

            r_adc_master_state <= ADC_READY;

            end // end else

        end // end case statement

        ADC_READY:  begin
          r_spi_master_adc_tx_counter <= 0;
          r_spi_master_adc_rx_counter <= 0;

          if (r_adc_master_configured == 0) begin
            r_spi_master_adc_tx_data [31:0] = 3490971659;   // ADC config 1,25x uni directional 0xD0 0x14 0x00 0x0B
          end
          else  begin
            r_spi_master_adc_tx_data [31:0] = 0;
          end

          r_spi_master_adc_tx_data_count <= 4;

          if(r_adc_master_conversion) begin
            r_adc_master_state <= ADC_SAMPLING;
          end

        end // end case statement

        ADC_SAMPLING:  begin

          if(r_adc_master_conversion) begin
            //r_adc_master_conversion <= 0;
            r_spi_master_adc_cs_control <= 0;
            r_spi_master_adc_convst <= 1;

            if(r_adc_sample_delay >= ADC_CS_CONVS_DELAY)  begin
              r_adc_master_conversion <= 0;
              r_adc_sample_delay <= 0;
            end // end if
            else  begin
              r_adc_sample_delay <= r_adc_sample_delay + 1;
            end // end else

          end // end if
          else  begin
            r_spi_master_adc_convst <= 0;
            r_spi_master_adc_cs_control <= 1;

            if(r_adc_sample_delay >= ADC_SAMPLE_DELAY)  begin
              r_adc_master_state <= ADC_ACQUIRING;
              r_adc_sample_delay <= 0;
            end // end if
            else  begin
              r_adc_sample_delay <= r_adc_sample_delay + 1;
            end // end else

          end // end else


        end // end case statement

        ADC_ACQUIRING:  begin

          //if(w_spi_master_adc_rvs && w_spi_master_rx_dv)  begin
          if(w_spi_master_adc_rx_dv)  begin
            // for receiving up to 4 Bytes
            case (w_spi_master_adc_rx_data_count)
              0:  begin
                r_spi_master_adc_rx_data [7:0] <= w_temp_adc_rx [7:0];
                r_spi_master_adc_rx_counter <= 1;
              end
              1:  begin
                r_spi_master_adc_rx_data [15:8] <= w_temp_adc_rx [7:0];
                r_spi_master_adc_rx_counter <= 2;
              end
              2:  begin
                r_spi_master_adc_rx_data [23:16] <= w_temp_adc_rx [7:0];
                r_spi_master_adc_rx_counter <= 3;
              end
              3:  begin
                r_spi_master_adc_rx_data [31:24] <= w_temp_adc_rx [7:0];
                r_spi_master_adc_rx_counter <= 4;
              end
            endcase
            /*
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
            */


          end // end ADC RX


          // handling sending data
          if( (r_spi_master_adc_tx_dv == 0) && (w_spi_master_adc_tx_ready) ) begin

            // for sending up to 4 Bytes
            case (r_spi_master_adc_tx_counter)

              0:  begin // end case statement
                r_temp_adc_tx [7:0] <= r_spi_master_adc_tx_data [31:24];
                r_spi_master_adc_tx_counter <= 1;
                //r_spi_master_adc_tx_counter <= r_spi_master_adc_tx_counter + 1;
                r_spi_master_adc_tx_dv <= 1;
              end // end case statement

              1:  begin
                r_temp_adc_tx [7:0] <= r_spi_master_adc_tx_data [23:16];
                r_spi_master_adc_tx_counter <= 2;
                //r_spi_master_adc_tx_counter <= r_spi_master_adc_tx_counter + 1;
                r_spi_master_adc_tx_dv <= 1;
              end // end case statement

              2:  begin
                r_temp_adc_tx [7:0] <= r_spi_master_adc_tx_data [15:8];
                r_spi_master_adc_tx_counter <= 3;
                //r_spi_master_adc_tx_counter <= r_spi_master_adc_tx_counter + 1;
                r_spi_master_adc_tx_dv <= 1;
              end // end case statement

              3:  begin
                r_temp_adc_tx [7:0] <= r_spi_master_adc_tx_data [7:0];
                r_spi_master_adc_tx_counter <= 4;
                //r_spi_master_adc_tx_counter <= r_spi_master_adc_tx_counter + 1;
                r_spi_master_adc_tx_dv <= 1;

                // finish sending config data
                if (r_adc_master_configured == 0) begin
                  r_adc_master_configured <= 1;
                end

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

          //if( (r_spi_master_adc_tx_data_count == r_spi_master_adc_rx_counter) && (r_spi_master_state == SPI_INITIALIZED) )  begin
          if( (r_spi_master_adc_tx_data_count == r_spi_master_adc_rx_counter) && (r_spi_master_adc_rx_counter == 4) )  begin

            // convert measured data into final value
            r_adc_master_rx_buffer_1 <= (r_spi_master_adc_rx_data [23:16] >> 6) | (r_spi_master_adc_rx_data [15:8] << 2) | (r_spi_master_adc_rx_data [7:0] << 10);

            // enter data about current measuring range
            r_adc_master_rx_buffer_1 [31:29] <= r_adc_master_last_range;

            // in case of 2 buffer for instant ADC measurements
            // currently not used as it complicates things further more and
            /*
            if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
              r_adc_master_rx_buffer_2 <= (r_spi_master_adc_rx_data [23:16] >> 6) | (r_spi_master_adc_rx_data [15:8] << 2) | (r_spi_master_adc_rx_data [7:0] << 10);
            end // end if
            else if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_2)  begin
              r_adc_master_rx_buffer_1 <= (r_spi_master_adc_rx_data [23:16] >> 6) | (r_spi_master_adc_rx_data [15:8] << 2) | (r_spi_master_adc_rx_data [7:0] << 10);
            end // end if
            */

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

      // Range state machine
      case (r_adc_master_range_state)

        ADC_RANGE_STATE_DONE: begin


        end // end case statement

        ADC_RANGE_STATE_CHECKED:  begin

          if ( (r_adc_master_rx_reading_counter < ADC_READINGS) && (r_adc_measure_under_sample == ADC_MEASUREMENT_UNDERSAMPLE))  begin
          //if ( (r_adc_master_rx_reading_counter >= 0) && (r_adc_master_rx_reading_counter < ADC_READINGS) )  begin

            if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
              //r_adc_master_tx_buffer_2 [r_adc_master_rx_reading_counter*4] <= r_adc_master_rx_reading_counter;
              r_adc_master_tx_buffer_2 [r_adc_master_rx_reading_counter*4] <= r_adc_master_rx_buffer_1 [31:24];
              r_adc_master_tx_buffer_2 [r_adc_master_rx_reading_counter*4 + 1] <= r_adc_master_rx_buffer_1 [23:16];
              r_adc_master_tx_buffer_2 [r_adc_master_rx_reading_counter*4 + 2] <= r_adc_master_rx_buffer_1 [15:8];
              r_adc_master_tx_buffer_2 [r_adc_master_rx_reading_counter*4 + 3] <= r_adc_master_rx_buffer_1 [7:0];
            end // end if
            else  begin
              //r_adc_master_tx_buffer_1 [r_adc_master_rx_reading_counter*4] <= r_adc_master_rx_reading_counter*2;
              r_adc_master_tx_buffer_1 [r_adc_master_rx_reading_counter*4] <= r_adc_master_rx_buffer_1 [31:24];
              r_adc_master_tx_buffer_1 [r_adc_master_rx_reading_counter*4 + 1] <= r_adc_master_rx_buffer_1 [23:16];
              r_adc_master_tx_buffer_1 [r_adc_master_rx_reading_counter*4 + 2] <= r_adc_master_rx_buffer_1 [15:8];
              r_adc_master_tx_buffer_1 [r_adc_master_rx_reading_counter*4 + 3] <= r_adc_master_rx_buffer_1 [7:0];
            end // end else

            r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;
            r_adc_measure_under_sample <= 0;
            // reset buffer so it won't interfere with range checking as it only expects measured data without range information
            //r_adc_master_rx_buffer_1 <= 0;
            //r_adc_master_rx_reading_counter <= 1;
          end // end if
          else  begin

            r_adc_master_rx_buffer_1 <= 0;
            r_adc_measure_under_sample <= r_adc_measure_under_sample + 1;

          end // end else

          // checking for full tx buffer based on reading counter, then it changes buffer for new readings and changes tx_data_ready flag, so data will be send to MCU
          if(r_adc_master_rx_reading_counter == (ADC_READINGS-1) ) begin

            if(r_adc_master_tx_buffer_selector == ADC_TX_BUFFER_1)  begin
              r_adc_master_tx_buffer_selector <= ADC_TX_BUFFER_2;
            end // end if
            else  begin
              r_adc_master_tx_buffer_selector <= ADC_TX_BUFFER_1;
            end // end else

            r_adc_master_rx_reading_counter <= 0;
            //r_adc_master_rx_reading_counter <= r_adc_master_rx_reading_counter + 1;

            w_spi_master_tx_data_ready <= 1;

          end // end if

          r_adc_master_range_state <= ADC_RANGE_STATE_DONE;

        end // end case statement

        ADC_RANGE_STATE_UNCHECKED:  begin

          r_adc_master_last_range <= r_adc_master_range;

          // range selection
          // in next clock proper range will be applied

          // nA to uA
          if(r_adc_master_last_range == ADC_RANGE_NA && r_adc_master_rx_buffer_1 [23:0] >= ADC_RANGE_LIMIT_HIGH) begin
            r_adc_master_range <= ADC_RANGE_UA;

            w_adc_master_range_na <= 0;
            w_adc_master_range_ua <= 1;
            w_adc_master_range_ma <= 0;

          end // end if
          // uA to mA
          else if(r_adc_master_last_range == ADC_RANGE_UA && r_adc_master_rx_buffer_1 [23:0] >= ADC_RANGE_LIMIT_HIGH)  begin
            r_adc_master_range <= ADC_RANGE_MA;

            w_adc_master_range_na <= 0;
            w_adc_master_range_ua <= 0;
            w_adc_master_range_ma <= 1;

          end // end if
          // mA to uA
          else if(r_adc_master_last_range == ADC_RANGE_MA && r_adc_master_rx_buffer_1 [23:0] <= ADC_RANGE_LIMIT_LOW)  begin
            r_adc_master_range <= ADC_RANGE_UA;

            w_adc_master_range_na <= 0;
            w_adc_master_range_ua <= 1;
            w_adc_master_range_ma <= 0;

          end // end if
          // uA to nA
          else if(r_adc_master_last_range == ADC_RANGE_UA && r_adc_master_rx_buffer_1 [23:0] <= ADC_RANGE_LIMIT_LOW)  begin
            r_adc_master_range <= ADC_RANGE_NA;

            w_adc_master_range_na <= 1;
            w_adc_master_range_ua <= 0;
            w_adc_master_range_ma <= 0;

          end // end if
          else  begin
            //r_adc_master_range <= ADC_RANGE_MA;

            // if there is no need for change, just save current range for next iteration
            //r_adc_master_range <= r_adc_master_last_range;

          end // end else

          /*
          if(r_adc_master_last_range == ADC_RANGE_MA) begin
            r_adc_master_rx_buffer_1 [31:29] <= 3'b100;
          end
          else if(r_adc_master_last_range == ADC_RANGE_UA)  begin
            r_adc_master_rx_buffer_1 [31:29] <= 3'b010;
          end
          else if(r_adc_master_last_range == ADC_RANGE_NA)  begin
            r_adc_master_rx_buffer_1 [31:29] <= 3'b001;
          end
          */
          /*
          r_adc_master_rx_buffer_1 [31:31] <= w_adc_master_range_ma;
          r_adc_master_rx_buffer_1 [30:30] <= w_adc_master_range_ua;
          r_adc_master_rx_buffer_1 [29:29] <= w_adc_master_range_na;
          */

          r_adc_master_range_state <= ADC_RANGE_STATE_CHECKED;

        end // end case statement

        // this should never happen
        default:  begin
          /*
          r_adc_master_range <= ADC_RANGE_MA;

          w_adc_master_range_na <= 0;
          w_adc_master_range_ua <= 0;
          w_adc_master_range_ma <= 1;
          */
        end // end default case statement

      endcase // end case adc range state machine

    end  /// end always


    // SPI MASTER to MCU
    assign PIN_2 = w_spi_master_mcu_clk;
    assign PIN_3 = w_spi_master_mcu_mosi;
    assign PIN_4 = w_spi_master_mcu_miso;
    assign PIN_5 = w_spi_master_mcu_cs;

    // mcu transfer ready flag
    assign PIN_6 = w_adc_master_mcu_transfer_ready;

    // SPI MASTER to ADC
    assign PIN_7 = w_spi_master_adc_rvs;
    assign PIN_8 = w_spi_master_adc_miso;    // SPI ADC MISO
    assign PIN_10 = w_spi_master_adc_mosi;
    assign PIN_11 = w_spi_master_adc_clk;
    assign PIN_12 = (w_spi_master_adc_cs && r_spi_master_adc_cs_control);
    //assign PIN_13 = r_spi_master_adc_convst;

    // ADC RANGE - Power Transistor
    assign PIN_14 = w_adc_master_range_ma;  // mA range
    assign PIN_15 = w_adc_master_range_ua;  // uA range
    assign PIN_16 = w_adc_master_range_na;  // nA range

    // ADC RANGE - Analog Switch
    assign PIN_17 = !w_adc_master_range_ma;  // mA range AS
    assign PIN_18 = !w_adc_master_range_ua;  // uA range AS
    assign PIN_19 = !w_adc_master_range_na;  // nA range AS

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
    //assign PIN_13 = w_spi_master_tx_data_ready;
    //assign PIN_12 = r_spi_master_adc_tx_dv;

    //assign PIN_1 = w_clk_240mhz;

endmodule
