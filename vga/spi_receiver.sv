// spi_receiver.sv
// 10/28/14 by Mengyi Tao
// SPI receiver module

module spi_receiver (input  logic       sclk,
							input	 logic		 sdi,							// spi input from master (PIC)
							input  logic [3:0] s,						// switch input
							output logic 		 header,						// header = 1: clock is syncing; header = 0: SPI passing time of last successful sync
							output logic [4:0] hour, 						// 0-11 hours
							output logic [5:0] minute, second,			// 0-60
							output logic [3:0] month,						// 0-12
							output logic [4:0] day,							// 0-31
							output logic [4:0] year);						// 2000-2064
							

logic [31:0] timeout = 0;		// 32 bit number containing time information from PIC
logic [4:0] bitpos = 0;			// for tracking the bit that's being updated

//assign second = 6'd0;		
//assign hour = s % 5'd12; //4'd1; 
//assign minute = 6'd20; 
//assign month = 4'd10; 
//assign day = 5'd2;
//assign year = 5'd14; 


always_ff @ (negedge sclk)
	bitpos <= bitpos + 1;

always_ff @ (posedge sclk)
begin
	timeout <= {timeout[30:0], sdi};	// shift register
	
	if (bitpos == 0)
		begin
			header <= timeout[31];
			year <= timeout[30:26];
			month <= timeout[25:22];
			day <= timeout[21:17];
			hour <= timeout[16:12] % 5'd12;
			minute <= timeout[11:6];
			second <= timeout[5:0];
		end
		


end

endmodule