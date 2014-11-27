// spi_receiver.sv
// 10/28/14 by Mengyi Tao
// SPI receiver module

module spi_receiver (input  logic       sclk,
							input	 logic		 sdi,							// spi input from master (PIC)
							output logic [4:0] hour, 						// 0-60 ticks
							output logic [5:0] minute, second,			// 0-60
							output logic [3:0] month,						// 0-12
							output logic [4:0] day,							// 0-31
							output logic [5:0] year);						// 2000-2064
							

logic [31:0] timeout = 0;		// 32 bit number containing time information from PIC
logic [4:0] bitpos = 0;			// for tracking the bit that's being updated


assign hour = 4'd1; 
assign minute = 6'd20; 
assign second = 6'd30; 
assign month = 4'd10; 
assign day = 5'd2;
assign year = 5'd14; 


//always_ff @ (negedge sclk)
//begin
//	timeout <= {timeout[30:0], sdi};	// shift register
//	
//	if (bitpos == 0)
//		begin
//			hour <= timeout[31:27];
//			minute <= timeout[26:21];
//			second <= timeout[20:15];
//			month <= timeout[14:11];
//			day <= timeout[10:6];
//			year <= timeout[5:0];
//		end
//		
//	bitpos <= bitpos + 1;
//
//end

endmodule