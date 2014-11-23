// spi_receiver.sv
// 10/28/14 by Mengyi Tao
// SPI receiver module

module spi_receiver (input  logic       sclk,
							input	 logic		 sdi,							// spi input from master (PIC)
							output logic [15:0] xcursor, ycursor);		// position of cursor read from PIC

logic [31:0] cursorpos = 0;		// 32 bit number containing x and y position (shorts) of cursor
logic [4:0] bitpos = 0;			// for tracking the bit that's being updated

always_ff @ (negedge sclk)
begin
	cursorpos <= {cursorpos[30:0], sdi};	// shift register
	
	if (bitpos == 0)
		begin
			xcursor <= cursorpos[31:16];
			ycursor <= cursorpos[15:0];
		end
		
	bitpos <= bitpos + 1;

end

endmodule