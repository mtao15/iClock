// vga.sv
// 20 October 2011 Karl_Wang & David_Harris@hmc.edu
// Edited 10/27/2014 by Mengyi Tao
// VGA driver with character generator

module vga(input  logic       clk, 
			  input	logic			sclk, sdi,					// SPI 
			  output logic       vgaclk,						// 25 MHz VGA clock
			  output logic       hsync, vsync, sync_b,	// to monitor & DAC
			  output logic [7:0] r, g, b, led);					// to video DAC
 
  logic [9:0] x, y;
  logic [7:0] r_int, g_int, b_int;
	
  // Use a PLL to create the 25.175 MHz VGA pixel clock 
  // 25.175 Mhz clk period = 39.772 ns
  // Screen is 800 clocks wide by 525 tall, but only 640 x 480 used for display
  // HSync = 1/(39.772 ns * 800) = 31.470 KHz
  // Vsync = 31.474 KHz / 525 = 59.94 Hz (~60 Hz refresh rate)
  pll	vgapll(.inclk0(clk),	.c0(vgaclk)); 

  // generate monitor timing signals
  vgaController vgaCont(vgaclk, hsync, vsync, sync_b,  
                        r_int, g_int, b_int, r, g, b, x, y);
	
  // user-defined module to determine pixel color
  videoGen videoGen(sclk, sdi, x, y, r_int, g_int, b_int, led[7:0]);
  
endmodule


module vgaController #(parameter HMAX   = 10'd800,
                                 VMAX   = 10'd525, 
											HSTART = 10'd152,
											WIDTH  = 10'd640,
											VSTART = 10'd37,
											HEIGHT = 10'd480)
						  (input  logic       vgaclk, 
                     output logic       hsync, vsync, sync_b,
							input  logic [7:0] r_int, g_int, b_int,
							output logic [7:0] r, g, b,
							output logic [9:0] x, y);

  logic [9:0] hcnt, vcnt;
  logic       oldhsync;
  logic       valid;
  
  // counters for horizontal and vertical positions
  always @(posedge vgaclk) begin
    if (hcnt >= HMAX) hcnt = 0;
    else hcnt++;
	 if (hsync & ~oldhsync) begin // start of hsync; advance to next row
	   if (vcnt >= VMAX) vcnt = 0;
      else vcnt++;
    end
    oldhsync = hsync;
  end
  
  // compute sync signals (active low)
  assign hsync = ~(hcnt >= 10'd8 & hcnt < 10'd104); 	// horizontal sync
  assign vsync = ~(vcnt >= 2 & vcnt < 4); 				// vertical sync
  assign sync_b = hsync | vsync;

  // determine x and y positions
  assign x = hcnt - HSTART;
  assign y = vcnt - VSTART;
  
  // force outputs to black when outside the legal display area
  assign valid = (hcnt >= HSTART & hcnt < HSTART+WIDTH &
                  vcnt >= VSTART & vcnt < VSTART+HEIGHT);
  assign {r,g,b} = valid ? {r_int,g_int,b_int} : 24'b0;
endmodule


module videoGen(input  logic sclk, sdi,						//SPI
					 input  logic [9:0] x, y,
           		 output logic [7:0] r_int, g_int, b_int,
					 output logic [7:0] led);
	
  logic pixelstar;
  logic pixelrect;
  logic pixelcirc;
  logic pixelrip;
  logic stargenrange;
  logic [15:0] xcursor;
  logic [15:0] ycursor;
  
  // call other modules
  spi_receiver spirec(sclk, sdi, xcursor, ycursor);							// read cursor position (from PIC) over spi
  assign led[7:0] = xcursor[9:2];													// display top 8 bits of x position to LED
  circle drawcirc(xcursor[9:0], ycursor[9:0], x, y, 10'd5, pixelcirc);	// generate circular cursor image
  
  ripple drawrip(10'd100, 10'd100, x, y, 10'd5, pixelrip);					// generate circular ripple pattern (not used)
  stargenrom stargenromb(x, y, pixelstar);  										// generate stars on BG flag picture
  assign stargenrange = (x <= 10'd240) & (y <= 10'd224);						// note if (x,y) is inside blue rectangle
  rectangle drawrect(10'd0, 10'd0, x, y, 10'd240, 10'd224, pixelrect);	// generate blue rectangle on BG picture

  always_comb
  begin
  // draw circular cursor at appropriate position
  {r_int, g_int, b_int} = {8'h00, {8{pixelcirc}}, 8'h00};
  
  // draw stars inside blue rectangle range
  if (r_int == 8'h00 & g_int == 8'h00 & b_int == 8'h00)		// pixel isn't already used by cursor 
		{r_int, g_int, b_int} = (stargenrange == 1) ? {{8{pixelstar}},{8{pixelstar}},{8{pixelstar}}} : 
																	24'h000000;
  // draw blue rectangle
  if (r_int == 8'h00 & g_int == 8'h00 & b_int == 8'h00)		// pixel isn't already used by cursor or stars
		begin
		r_int = 8'h00;
		g_int = 8'h00;
		b_int = {{1{pixelrect}}, 7'b00};
		end
  
  // draw stripes
  if (r_int == 8'h00 & g_int == 8'h00 & b_int == 8'h00)		// pixel isn' already used by cursor, stars, or rectangle
		{r_int, g_int, b_int} = (y[5]==0) ? {{8'hF0},16'h0000} : 24'hffffff;  
  end
endmodule


module stargenrom(input  logic [9:0] x, y,
						output logic       pixel);
						
  logic [239:0] stars[223:0]; 			// star generator ROM
  logic [239:0] line;            		// a line read from the ROM
  
  // initialize ROM with characters from text file 
  initial 
	 $readmemb("stars.txt", stars);		// .txt file of star pattern
	 
  // index into ROM to find line of character
  assign line = {stars[y]}; 
  
  // reverse order of bits
  assign pixel = line[8'd239-x];
endmodule


module rectangle (input logic [9:0] xshape, yshape, x, y,	// rectangle: top left corner at (xshape, yshape)
						input logic [9:0] width, height,				// rectangle width & height
						output logic pixel);
	always_comb
	begin
	if ((x <= xshape + width)& (x >= xshape)&(y <= yshape + height)&(y >= yshape))
		pixel = 1;
	else
		pixel = 0;
	end
endmodule

	
module circle (input logic [9:0] xcent, ycent, x, y,		// circle centered at (xcent, ycent)
					input logic [9:0] radius,						// circle radius = radius
					output logic pixel);
					
	logic [19:0]xdistsquared;
	logic [19:0]ydistsquared;
	logic [19:0]radiussquared;
	
	always_comb
	begin
	xdistsquared = ((x-xcent)*(x-xcent));						
	ydistsquared = ((y-ycent)*(y-ycent));
	radiussquared = (radius*radius);
	if ((xdistsquared + ydistsquared) <= radiussquared)	// pixel within radius of circle
		pixel = 1;
	else
		pixel = 0;
	end
endmodule


module ripple (input logic [9:0] xcent, ycent, x, y,		// create ripples pattern from multiple circles
					input logic [9:0] radius,
					output logic pixel);
					
	logic [9:0]xdistsquared;		// truncated dist^2 bits leads to repetition & ripple effect
	logic [9:0]ydistsquared;
	logic [9:0]radiussquared;
	
	always_comb
	begin
	xdistsquared = ((x-xcent)*(x-xcent));
	ydistsquared = ((y-ycent)*(y-ycent));
	radiussquared = (radius*radius);
	if ((xdistsquared + ydistsquared) <= radiussquared)	
		pixel = 1;
	else
		pixel = 0;
	end
endmodule