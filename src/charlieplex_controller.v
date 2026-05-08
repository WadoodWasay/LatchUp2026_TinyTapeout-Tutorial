// Charlieplex LED Controller for TinyTapeout
// 8 pins -> 56 LEDs, 4-bit grayscale using BCM
// MODIFIED BY WADOOD 12/11/2025 for initial version of controller

module charlieplex_controller (
    input  wire       clk,
    input  wire       rst_n,
    
    // SPI interface for loading frame buffer
    input  wire       spi_cs_n,
    input  wire       spi_sclk,
    input  wire       spi_mosi,
    
    // active-high output enable and active-low output enable
    output reg  [7:0] led_out,
    output reg  [7:0] led_oe
);

    localparam NUM_PINS = 8;
    localparam NUM_LEDS = 56;
    localparam GREYSCALE_BITS = 4;
    
    // frame buffer: 56 LEDs x 4 bits = 224 bits
    reg [GREYSCALE_BITS-1:0] brightness [0:NUM_LEDS-1];
    
    // SPI receiver for loading brightness values
    reg [2:0] spi_bit_cnt;
    reg [5:0] spi_led_cnt;
    reg [7:0] spi_shift_reg;
    reg       spi_sclk_prev;
    
    wire spi_sclk_rising = spi_sclk && !spi_sclk_prev;

    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_bit_cnt <= 0;
            spi_led_cnt <= 0;
            spi_shift_reg <= 0;
            spi_sclk_prev <= 0;
	    // Test: set all LEDs to be on by default, with a brightness gradient
	    for (i = 0; i < NUM_LEDS; i = i + 1)
	        brightness[i] <= (i < 7)  ? 15 :
				 (i < 14) ? 11 :
				 (i < 21) ?  8 :
				 (i < 28) ?  6 :
				 (i < 35) ?  4 :
				 (i < 42) ?  3 :
				 (i < 49) ?  2 :
				 1 ;

        end else begin
            spi_sclk_prev <= spi_sclk;
            
            if (spi_cs_n) begin
                // CS high = idle, reset counters
                spi_bit_cnt <= 0;
                spi_led_cnt <= 0;
            end else if (spi_sclk_rising) begin
                spi_shift_reg <= {spi_shift_reg[6:0], spi_mosi};
                spi_bit_cnt <= spi_bit_cnt + 1;
                
		// store brightness values after 8 bits
                if (spi_bit_cnt == 3'd7) begin
                    if (spi_led_cnt < NUM_LEDS) begin
                        brightness[spi_led_cnt] <= {spi_shift_reg[2:0], spi_mosi};
                    end
                    spi_led_cnt <= spi_led_cnt + 1;
                end
            end
        end
    end
    
    // BCM Scan Controller
    reg [5:0] led_index;        		// 0-55: LED being addressed
    reg [GREYSCALE_BITS-1:0] on_cnt;    	// counter for time LED is on
    reg [7:0] base_cnt;				// minimum clocks per LED cycle
    
    // current LED's brightness value
    wire [GREYSCALE_BITS-1:0] current_brightness = brightness[led_index];
    
    wire led_on = (current_brightness == 0) ? 1'b0 : 1'b1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_index <= 0;
            on_cnt <= 0;
	    base_cnt <= 0;
        end else if (spi_cs_n) begin
            if (on_cnt >= current_brightness) begin
                // done with this LED
                if (led_index == NUM_LEDS - 1) begin
                    // done with all LEDs, move to next bit plane
                    led_index <= 0;
                end else begin
                    led_index <= led_index + 1;
                end
		on_cnt <= 0;
	    end else if (base_cnt == 8'b11111111) begin
		base_cnt <= 0;
		on_cnt <= on_cnt + 1;
            end else begin
                base_cnt <= base_cnt + 1;
            end
        end
    end
    
    // with 8 pins numbered 0-7:
    //   LED 0-6:   anode=0, cathode=1,2,3,4,5,6,7
    //   LED 7-13:  anode=1, cathode=0,2,3,4,5,6,7
    //   etc
    wire [2:0] anode_pin;
    wire [2:0] cathode_pin;
    wire [2:0] cathode_offset;
    
    assign anode_pin = led_index / 7;
    assign cathode_offset = led_index % 7;
    // skip over the anode pin number in the cathode sequence
    assign cathode_pin = (cathode_offset < anode_pin) ? cathode_offset : (cathode_offset + 1);
    
    // output generation
    
    always @(*) begin
        // default: all pins Hi-Z
        led_out = 8'b0;
        led_oe = 8'b0;
        
        if (led_on) begin
            // drive anode HIGH, cathode LOW, others Hi-Z
            for (i = 0; i < 8; i = i + 1) begin
                if (i == anode_pin) begin
                    led_out[i] = 1'b1;
                    led_oe[i] = 1'b1;
                end else if (i == cathode_pin) begin
                    led_out[i] = 1'b0;
                    led_oe[i] = 1'b1;
                end
                // else stays Hi-Z (oe=0)
            end
        end
    end

endmodule
