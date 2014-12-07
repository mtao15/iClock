// spi_receiver.sv
// Lasted edited 12/06/2014 by Mengyi Tao & Yukun Lin
// SPI receiver module for radio clock project

module spi_receiver (input  logic clk, sclk,     //clk @ 40MHz (0.025us period)
                                                 //sclk @ 1.25MHz (0.8us period)
                     input  logic sdi,           // spi input from master (PIC)
                     output logic header,        // denotes if current time = time 
                                                 // of last sync (if so, header = 1)
                     output logic [4:0] hour,    // 0-23 hours
                     output logic [5:0] minute,  // 0-60
                     output logic [5:0] second,  // 0-60
                     output logic [3:0] month,   // 0-12
                     output logic [4:0] day,     // 0-31
                     output logic [4:0] year     // 2014-2078; 2014 is the reference year (i.e. year = 0 -> 2014)
);
                            

  logic [31:0] spizerocount = 0;
  logic lastZero = 1;
  logic [31:0] timeout = 0;         // 32 bit number containing time information from PIC
  logic [4:0] cnt = 0;              // for tracking the bit that's being updated
  logic reset;                      // reset SPI buffer
  logic [31:0] q;

  
  // track number of consecutive lows in sclk
  always_ff @(posedge clk) 
    begin
    if (!sclk)                               // sclk is low this cycle
      begin
      if (lastZero)                          // sclk was low on the previous cycle
        spizerocount <= spizerocount + 1;    // increment counter
      else
        lastZero = 1; 
      end
    else 
      begin
      lastZero <= 0;
      spizerocount <= 0;
      end
    end
 
  // reset SPI buffer if sclk went low for ~0.2 ms = 8,000 clk cycles. 
  assign reset = spizerocount > 8000;   
  
  
  // 5-bit counter tracks when full 32 bit is transmitted from the PIC
  always_ff @(negedge sclk, posedge reset) 
    begin
    if (reset)
      cnt <= 0;
    else
      cnt <= cnt + 5'b1;
    end

    
  // loadable shift register; once q is full, load it into output buffer (timeout)
  always_ff @(posedge sclk) 
    begin
      timeout <=  (cnt == 0) ? q : timeout;
      q       <=  {q[30:0], sdi};
    end
  
  
  // parse time information from output buffer
  assign header = timeout[31];
  assign year = timeout[30:26];
  assign month = timeout[25:22];
  assign day = timeout[21:17];
  assign hour = timeout[16:12];
  assign minute = timeout[11:6];
  assign second= timeout[5:0];

endmodule