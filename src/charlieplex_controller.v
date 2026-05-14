// Charlieplex LED Controller for TinyTapeout
// 8 pins -> 56 LEDs, 3-bit grayscale using BCM
// MODIFIED BY WADOOD 5/14/2026 fixed bug in the default pattern (was
// displaying only 1 pixel of the 7th row because pixels were organized into
// rows of 7 instead of 8)

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
    localparam GREYSCALE_BITS = 3;
    
    // frame buffer: 56 LEDs x 3 bits = 168 bits
    reg [GREYSCALE_BITS-1:0] brightness [0:NUM_LEDS-1];
    
    // SPI receiver for loading brightness values
    reg [2:0] spi_bit_cnt;
    reg [5:0] spi_led_cnt;
    reg [7:0] spi_shift_reg;
    reg [1:0] spi_sclk_prev;
    reg	      has_address;
    
    wire spi_sclk_rising = spi_sclk_prev[0] && !spi_sclk_prev[1];

    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_bit_cnt <= 0;
            spi_led_cnt <= 0;
            spi_shift_reg <= 0;
            spi_sclk_prev <= 0;
	    has_address <= 0;
	    // Test: set all LEDs to be on by default, with a brightness gradient
	    for (i = 0; i < NUM_LEDS; i = i + 1)
	        brightness[i] <= (i < 8)  ?  7 :
				 (i < 15) ?  6 :
				 (i < 23) ?  5 :
				 (i < 31) ?  4 :
				 (i < 39) ?  3 :
				 (i < 47) ?  2 :
				 1 ;

        end else begin
            spi_sclk_prev <= {spi_sclk_prev[0], spi_sclk};
            
            if (spi_cs_n) begin
                // CS high = idle, reset counters
                spi_bit_cnt <= 0;
                spi_led_cnt <= 0;
		has_address <= 1'b0;
            end else if (spi_sclk_rising) begin
                spi_shift_reg <= {spi_shift_reg[6:0], spi_mosi};
                spi_bit_cnt <= spi_bit_cnt + 1;
                
		// After 8 bits received:
		// First byte sent:  Set the address (spi_led_cnt).
		// All other bytes sent:  Store brightness value and increment address
                if (spi_bit_cnt == 3'd7) begin
		    if (has_address == 1'b0) begin
			spi_led_cnt <= {spi_shift_reg[4:0], spi_mosi};
			has_address <= 1'b1;
		    end else begin
			if (spi_led_cnt < NUM_LEDS) begin
			    brightness[spi_led_cnt] <= {spi_shift_reg[1:0], spi_mosi};
			end
			spi_led_cnt <= spi_led_cnt + 1;
		    end
                end
            end
        end
    end
    
    // BCM Scan Controller
    reg [5:0] led_index;        		// 0-55: LED being addressed
    reg [GREYSCALE_BITS-1:0] on_cnt;    	// counter for time LED is on
    reg [5:0] base_cnt;				// minimum clocks per LED cycle
    
    // current LED's brightness value
    wire [GREYSCALE_BITS-1:0] current_brightness = brightness[led_index];
    
    reg led_on;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_index <= 0;
            on_cnt <= 0;
	    base_cnt <= 0;
	    led_on <= 1'b0;
        end else if (spi_cs_n) begin
            if (on_cnt == 3'b111 && base_cnt == 6'b111111) begin
		led_on <= 1'b0;
                // done with this LED
                if (led_index == NUM_LEDS - 1) begin
                    // done with all LEDs, move to next bit plane
                    led_index <= 0;
                end else begin
                    led_index <= led_index + 1;
                end
		base_cnt <= 0;
		on_cnt <= 0;
	    end else if (base_cnt == 6'b111111) begin
		base_cnt <= 0;
		on_cnt <= on_cnt + 1;
            end else begin
                if (on_cnt >= current_brightness) begin
		    led_on <= 1'b0;
		end else begin
		    led_on <= 1'b1;
		end
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
            for (j = 0; j < 8; j = j + 1) begin
                if (j == anode_pin) begin
                    led_out[j] = 1'b1;
                    led_oe[j] = 1'b1;
                end else if (j == cathode_pin) begin
                    led_out[j] = 1'b0;
                    led_oe[j] = 1'b1;
                end
                // else stays Hi-Z (oe=0)
            end
        end
    end

endmodule
