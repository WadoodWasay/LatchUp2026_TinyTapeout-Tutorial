/*
 * tt_ww_charlieplex_wrapper.v
 *
 * Wrapper for Arty A7 board around the
 * TinyTapeout project tt_ww_charlieplex.v
 *
 * What this wrapper adds:
 *
 * (1) Divide-by-2 on the clock to match the TinyTapeout
 *     development board running at 50MHz
 * (2) Bidirectional pin handling
 * (3) UART-to-SPI to use the Arty's FTDI for USB communication
 *
 */

// Note that this creates new signal name "uio_inout" which is
// what must be connected to the eight pins in the "JB" PMOD
// in the Arty board configuration file.
//
// Two more signals are added:  ser_tx_out and ser_rx_in.  These
// need to be connected to the FTDI in the Arty board configuration
// file.

module tt_ww_charlieplex_wrapper (
    inout  wire [7:0] uio_inout,  // Bidirectional input and output (JB PMOD)
    input  wire [7:0] ui_in,	  // (Unused) input (JA PMOD)
    output wire [7:0] uo_out,	  // (Unused) output (JC PMOD)
    input  wire       clk,        // clock
    input  wire       rst_n,      // reset - low to reset
    input  wire	      ser_rx_in,  // UART input from FTDI on Arty board
    output wire	      ser_tx_out  // UART output to FTDI on Arty board
);

    reg clk2;

    // NOTE:  For the Arty board FPGA implementation, the SPI signals
    // are handled internally to the FPGA.  For Tiny Tapeout, they
    // would be routed to ui_in[] and uo_out[] pins (see mapping below).
    //
    // To mimic the Tiny Tapeout configuration, the module
    // tt_ww_charlieplex is kept, which is the top level Tiny Tapeout
    // module with the assigned Tiny Tapeout I/O.  Only the SPI input
    // signals are re-routed so that they can come from the USB
    // interface.  The SPI output is duplicated, going both internally
    // to the FPGA and also going to the PMOD output like it would on
    // the Tiny Tapeout board.
    //
    // For compatibility with other Tiny Tapeout projects, the mappings
    // for the SPI match the ones found here:
    // https://tinytapeout.com/chips/tt07/tt_um_riscv_spi_wrapper
    //
    // ui_in[0]  = SCK
    // ui_in[1]  = CS
    // ui_in[2]  = SDI
    // ui_out[0] = SDO
    // 
    // Note that "SDO" of the interface is the output of the interface
    // and therefore is the input to the project;  "SDI" is input to
    // the interface and therefore the output from the project.

    wire [7:0] uio_oe;
    wire [7:0] uio_in;
    wire [7:0] uio_out;

    wire sdo, csb, sck;		// Re-routed signals
    wire nc;			// Internally unconnected signal

    // Instantiate the Tiny Tapeout project

    tt_ww_charlieplex project (
	.ui_in({ui_in[7:3], sdo, csb, sck}),	// 8-bit input
	.uo_out({uo_out[7:1], nc}),	// 8-bit output
	.uio_in(uio_in),	// 8-bit bidirectional (in)
	.uio_out(uio_out),	// 8-bit bidirectional (out)
	.uio_oe(uio_oe),	// 8-bit bidirectional (enable)
	.ena(1'b1),		// project enable (not used)
	.clk(clk2),		// halved clock
	.rst_n(rst_n)		// inverted reset
    );

    // Instantiate the UART-to-SPI module
    uart_to_spi interface (
	.clk(clk),
	.resetn(rst_n),
	.ser_tx(ser_tx_out),
	.ser_rx(ser_rx_in),
	.spi_sdo(sdo),
	.spi_csb(csb),
	.spi_sdi(uo_out[0]),
	.spi_sck(sck)
    );

    // Handle bidirectional I/Os
    generate
        genvar i;
        for (i = 0; i < 8; i = i + 1)
            assign uio_inout[i] = uio_oe[i] ? uio_out[i] : 1'bz;
    endgenerate
    assign uio_in = uio_inout;

    // Halve the clock

    always @(posedge clk) begin
	if (rst_n) begin
	    clk2 <= ~clk2;
	end else begin
	    clk2 <= 0;
	end
    end

endmodule;

