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

    // general constants
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


    // *********************** S P I - 8 MHz ************************************************//
    //***************************************************************************************//
    // define testing SPI Interface
    parameter SPI_MODE = 0; // CPOL = 1, CPHA = 1
    parameter CLKS_PER_HALF_BIT = 4;  // 6.25 MHz
    parameter MAIN_CLK_DELAY = 4;  // 25 MHz
    parameter MAX_BYTES_PER_CS = 4; // send maximum of 4 bytes before changing CS line

    // define spi signals
    wire w_spi_master_clk;
    wire w_spi_master_mosi;
    wire w_spi_master_miso;
    wire w_spi_master_cs;

    /*
    reg w_spi_master_clk;
    reg w_spi_master_mosi;
    reg w_spi_master_miso;
    reg w_spi_master_cs;
    */

    // indicating data readiness for sending over SPI bus
    reg r_spi_master_data_ready = 0;
    reg [3:0] start_sequnce = 4;

    // counters to define tx, rx bytes
    reg [2:0] r_spi_master_tx_data_count = 4;
    wire [2:0] r_spi_master_rx_data_count;

    // conters to point in registers
    reg [3:0] r_spi_master_tx_counter = 0;
    reg [3:0] r_spi_master_rx_counter = 0;

    // tx data -- 11 22 33 44 bytes
    reg [31:0] r_spi_master_tx_data = 740365835;
    reg [31:0] r_spi_master_rx_data;

    // state indication constants
    reg r_spi_master_reset = 0;
    reg r_spi_master_tx_dv = 0;
    wire r_spi_master_rx_dv;
    wire w_spi_master_tx_ready;

    // temp registry
    reg [7:0] r_temp_tx = 12;
    wire [7:0] r_temp_rx;

    reg [31:0] spi_transfer_counter = 0;

    /*
    #(
      .SPI_MODE( SPI_MODE ),
      .CLKS_PER_HALF_BIT( CLKS_PER_HALF_BIT ),
      .MAX_BYTES_PER_CS( MAX_BYTES_PER_CS ),
      .CS_INACTIVE_CLKS( MAIN_CLK_DELAY )
    )
    */

    SPI_Master_With_Single_CS spiMasterCS
    (
      .i_Rst_L(r_spi_master_reset),
      .i_Clk(CLK),

      // MOSI
      .i_TX_Count(r_spi_master_tx_data_count),
      .i_TX_Byte(r_temp_tx),
      .i_TX_DV(r_spi_master_tx_dv),
      .o_TX_Ready(w_spi_master_tx_ready),

      // MISO
      .o_RX_Count(r_spi_master_rx_data_count),
      .o_RX_DV(r_spi_master_rx_dv),
      .o_RX_Byte(r_temp_rx),

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


    always @ (posedge CLK) begin

      // handling Rx line
      if(r_spi_master_rx_dv) begin

        // for receiving up to 4 Bytes
        if( r_spi_master_rx_data_count == 0) begin
          r_spi_master_rx_data [7:0] <= r_temp_rx [7:0];
        end // end if
        else if( r_spi_master_rx_data_count == 1) begin
          r_spi_master_rx_data [15:8] <= r_temp_rx [7:0];
        end // end if
        else if( r_spi_master_rx_data_count == 2) begin
          r_spi_master_rx_data [23:16] <= r_temp_rx [7:0];
        end // end if
        else if( r_spi_master_rx_data_count == 3) begin
          r_spi_master_rx_data [31:24] <= r_temp_rx [7:0];
        end // end if

      end // end if

    end // end always

    always @ (posedge CLK) begin

      //w_led_1 <= r_cycle_counter[23];

      r_cycle_counter <= r_cycle_counter + 1;

      /*
      if(r_spi_master_rx_data == r_spi_master_tx_data) begin
        w_led_1 <= 1;
        w_led_2 <= 0;
        w_led_3 <= 1;
      end // end if
      */

      if( start_sequnce == 3 & spi_transfer_counter >= 1000) begin
        start_sequnce <= 0;
      end // end if

      if( start_sequnce == 3 ) begin
        spi_transfer_counter <= spi_transfer_counter + 1;
        //w_led_4 <= 1;
      end // end if


      if( start_sequnce == 2 ) begin
        //w_led_3 <= 1;
        r_spi_master_tx_counter <= 0;
        r_spi_master_rx_counter <= 0;

        r_spi_master_tx_data_count <= 4;

        //r_temp_tx [7:0] <= r_spi_master_tx_data [7:0];
        //r_spi_master_rx_data [31:0] <= 0;

        //r_spi_master_tx_dv <= 1;


        spi_transfer_counter <= 0;
        w_led_3 <= 1;

        start_sequnce <= 0;

        //w_led_3 <= 1;

      end // end else if

      if( start_sequnce == 1 ) begin
        r_spi_master_reset <= 1;
        start_sequnce <= 2;
        //r_spi_master_data_ready <= 0;
        w_led_2 <= 1;
      end // end if

      if(r_cycle_counter == 100) begin
      //if(r_cycle_counter [12]) begin
        r_spi_master_data_ready <= 1;
        start_sequnce <= 1;
        w_led_1 <= 1;
        //w_led_2 <= 0;

      end // end if

      // handling sending data
      if(w_spi_master_tx_ready && start_sequnce == 0) begin

        // for sensing up to 4 Bytes
        case (r_spi_master_tx_counter)
        	0: begin
              w_led_4 <= 1;
          		r_temp_tx [7:0] <= r_spi_master_tx_data [7:0];
          		r_spi_master_tx_dv <= 1;
              r_spi_master_tx_dv <= 0;
          		//r_spi_master_tx_counter <= 1;
              r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
            end
        	1: begin
            	r_temp_tx [7:0] <= r_spi_master_tx_data [15:8];
          		r_spi_master_tx_dv <= 1;
              r_spi_master_tx_dv <= 0;
          		//r_spi_master_tx_counter <= 2;
              r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
            end
        	2: begin
        		  r_temp_tx [7:0] <= r_spi_master_tx_data [23:16];
              r_spi_master_tx_dv <= 1;
              r_spi_master_tx_dv <= 0;
              //r_spi_master_tx_counter <= 3;
              r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
            end
        	3: begin
          		r_temp_tx [7:0] <= r_spi_master_tx_data [31:24];
          		r_spi_master_tx_dv <= 1;
              r_spi_master_tx_dv <= 0;
          		//r_spi_master_tx_counter <= 4;
              r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
            end
        	default: begin
            	r_temp_tx [7:0] <= r_spi_master_tx_data [7:0];
          		r_spi_master_tx_dv <= 1;
              r_spi_master_tx_dv <= 0;
          		//r_spi_master_tx_counter <= 1;
              r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;
            end
        endcase

        //r_spi_master_tx_counter <= r_spi_master_tx_counter + 1;

      end // end if
      else begin
        r_spi_master_tx_dv <= 0;

      end

    end  /// end always


    assign PIN_2 = w_spi_master_clk;
    assign PIN_3 = w_spi_master_mosi;
    assign PIN_4 = w_spi_master_miso;
    assign PIN_5 = w_spi_master_cs;

    // *********************** S P I - 8 MHz - E N D ****************************************//
    //***************************************************************************************//


    //assign PIN_11 = w_led_1;
    /*
    assign PIN_10 = w_led_1;
    assign PIN_11 = w_led_2;
    assign PIN_12 = w_led_3;
    assign PIN_13 = w_led_4;
    */

    assign PIN_10 = r_spi_master_reset;
    assign PIN_11 = w_spi_master_tx_ready;
    assign PIN_12 = r_spi_master_tx_dv;
    assign PIN_13 = r_spi_master_rx_dv;

    assign PIN_1 = CLK;

endmodule
