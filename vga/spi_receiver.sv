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
  logic [4:0] cnt = 0;			// for tracking the bit that's being updated

  logic [31:0] q;

  // 3-bit counter tracks when full byte is transmitted and new d should be sent
  always_ff @(negedge sclk)
    cnt <= cnt + 5'b1;

  // loadable shift register
  // loads d at the start, shifts sdo into bottom position on subsequent step
  // once q is full, load it into output buffer
  always_ff @(posedge sclk) begin
    timeout <=  (cnt == 0) ? q : timeout;
    q       <=  {q[30:0], sdi};
  end
  
  assign header = timeout[31];
  assign	year = timeout[30:26];
	assign		month = timeout[25:22];
	assign		day = timeout[21:17];
	assign		hour = timeout[16:12] % 5'd12;
	assign		minute = timeout[11:6];
	assign		second= timeout[5:0];



endmodule