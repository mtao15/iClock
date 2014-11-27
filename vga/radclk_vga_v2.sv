// radclk_vga.sv
// 20 October 2011 Karl_Wang & David_Harris@hmc.edu
// Edited 11/17/2014 by Mengyi Tao
// VGA driver 

module radclk_vga(input  logic       clk, 
			  input	logic			sclk, sdi,					// SPI 
			  input logic	[3:0] s,
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
  videoGen videoGen(clk, sclk, sdi, s, x, y, r_int, g_int, b_int, led[7:0]);
  
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


module videoGen(input  logic clk, sclk, sdi,						//SPI
						input logic [3:0] s,
					 input  logic [9:0] x, y,
           		 output logic [7:0] r_int, g_int, b_int,
					 output logic [7:0] led);
	
	logic pixelstar;
   logic pixelrect;
   logic pixelcircclk;
	logic pixelclk;
	logic pixelsec;
	logic pixelmin;
	logic pixelhr;
	logic header;
	logic [5:0] second, minute, hour;
	logic [5:0] second_in, minute_in;
	logic [4:0] hour_in;
	logic [3:0] month_in;
	logic [4:0] day_in;
	logic [5:0] year_in;
	logic synccounter;
	logic clkgenrange;
   logic stargenrange;

  
   // instantiate other modules
   spi_receiver spirec(sclk, sdi, s, header, hour_in, minute_in, second_in, month_in, day_in, year_in);		// read cursor position (from PIC) over spi
   //assign led[5:0] = second_in;														// display top 8 bits of x position to LED

	circle clkface(10'd320, 10'd240, x, y, 10'd200, pixelcircclk);				// generate circular clock face
	
   assign stargenrange = (x <= 10'd240) & (y <= 10'd224);						// note if (x,y) is inside blue rectangle
	
   rectangle drawrect(10'd0, 10'd0, x, y, 10'd240, 10'd224, pixelrect);		// generate blue rectangle on BG picture

	clkhanddrive clkhands(clk, header, second_in, minute_in, hour_in, second, minute, hour, synccounter);
	
	// generate clock hands
	rotrectangle secondhand(10'd270, 10'd238, x, y, 10'd200, 10'd4, 10'd320, 10'd240, second, pixelsec);
	rotrectangle minutehand(10'd280, 10'd237, x, y, 10'd200, 10'd6, 10'd320, 10'd240, minute, pixelmin);
	rotrectangle hourhand(10'd280, 10'd236, x, y, 10'd150, 10'd8, 10'd320, 10'd240, hour, pixelhr);

	clkgenrom clkgen(x-10'd377, y-10'd40, pixelclk);								// generate clock tick pattern
	assign clkgenrange = (x >= 10'd120) & (x <= 10'd520) & (y >= 10'd40) & (y <= 10'd440);		// check if(x,y) is consrained to clock face dimension (400x400)

   always_comb
   begin
	// draw clock hands
	{r_int, g_int, b_int} = {{8{pixelsec}}, {16'h0000}};
	if (r_int == 8'h00 & g_int == 8'h00 & b_int == 8'h00)		// pixel isn't already used
		{r_int, g_int, b_int} = {{7'h0, {1{pixelmin}}}, {7'h0, {1{pixelmin}}}, {7'h0, {1{pixelmin}}}};
	if (r_int == 8'h00 & g_int == 8'h00 & b_int == 8'h00)		// pixel isn't already used
		{r_int, g_int, b_int} = {{7'h0, {1{pixelhr}}}, {7'h0, {1{pixelhr}}}, {7'h0, {1{pixelhr}}}};
		
   // draw clock ticks
	if (r_int == 8'h00 & g_int == 8'h00 & b_int == 8'h00)		// pixel isn't already used
		{r_int, g_int, b_int} = (clkgenrange == 1) ? {{7'h0, {1{pixelclk}}}, {7'h0, {1{pixelclk}}}, {7'h0, {1{pixelclk}}}}:
																24'h000000;
		
   // draw circular clock face at center of screen
   if (r_int == 8'h00 & g_int == 8'h00 & b_int == 8'h00)		// pixel isn't already used
		{r_int, g_int, b_int} = {{8{pixelcircclk}}, {8{pixelcircclk}}, {8{pixelcircclk}}};
 
	end
endmodule


// This module iterates clock ticks. 
// Output minute, second, and hour are given in terms of clock tick postions
module clkhanddrive(input logic clk,
						input logic header,
						input logic [5:0] second_in, minute_in,
						input logic [4:0] hour_in,
						output logic [5:0] second, minute, hour,
						output logic [31:0] synccounter);

logic [25:0] clkcounter;	
logic [15:0] secondcounter;	// count total number of seconds passed since the clock was at 12:00:00
logic [15:0] timein;

logic [15:0] prevtimein = 0;
logic [15:0] rem;					//remainder

always_ff @ (posedge clk)
	begin
//		clkcounter <= clkcounter+1;
//		if(clkcounter == 26'd40000000)		// a new second begins
//			begin
//			clkcounter <= 0;						// reset clock counter 
//			secondcounter <= (secondcounter+1) % 16'd43200;		// increment counter & reset every 43,200s (12 hrs)
//			synccounter <= synccounter+1;		// tracks number of seconds passed since last sync
//			end
//		else if(timein != prevtimein)		// new sync input detected
//			begin
//			prevtimein <= timein;
//			secondcounter <= timein;
//			synccounter <= 0;
//			end
//			
	end
	
always_comb
	begin
//		timein = second_in + 60*minute_in + 60*60*hour_in;
//		hour = secondcounter/(60*12);		// converted from hours (0-12) to ticks (0-60)
//		rem = secondcounter % (60*60);
//		minute = rem/60;
//		second = rem % 60;

		hour = hour_in*60/12;		// converted from hours (0-12) to ticks (0-60)
		minute = minute_in;
		second = second_in;
	end
endmodule
  
  
// This module draws the clock face  
module clkgenrom(input  logic [9:0] x, y,
						output logic       pixel);
						
  logic [399:0] clocktick[399:0]; 		// star generator ROM
  logic [399:0] line;            		// a line read from the ROM
  
  // initialize ROM with characters from text file 
  initial 
	 $readmemb("clkface1.txt", clocktick);		// .txt file of star pattern
	 
  // index into ROM to find line of character
  assign line = {clocktick[y]}; 
  
  // reverse order of bits
  assign pixel = line[8'd399-x];
endmodule



// This module makes a rectangle
module rectangle (input logic [9:0] xshape, yshape, x, y,	// rectangle: top left corner at (xshape, yshape)
						input logic [9:0] width, height,				// rectangle width & height
						output logic pixel);
	always_comb
	begin
	if ((x <= xshape + width) & (x >= xshape)&(y <= yshape + height)&(y >= yshape))
		pixel = 1;
	else
		pixel = 0;
	end
endmodule


// This module makes a rotated rectangle
module rotrectangle (input logic [9:0] xshape, yshape, x, y,	// rectangle's top left corner at (xshape, yshape)
							input logic [9:0] width, height,				// rectangle width & height
							input logic [9:0] xrot, yrot,					// point of rotation (pivot)
							input logic [5:0] tick,							// 60 ticks around clock face -> theta = tick * 6deg
							output logic pixel);

logic [31:0]costheta;	//costheta = cos(tick*6)*2^16
logic [31:0]sintheta;
logic [9:0]x0;
logic [9:0]y0;

coslookup trigcos(tick, costheta);
sinlookup trigsin(tick, sintheta);

	always_comb
	begin
	// 'unrotate' current pixel
	x0 = (((x-xrot)*costheta - (y-yrot)*sintheta)>>16) + xrot;	// cos(-theta) = cos(theta); sin(-theta) = -sin(theta)
	y0 = (((y-yrot)*costheta + (x-xrot)*sintheta)>>16) + yrot;
	
	if ((x0 <= xshape + width) & (x0 >= xshape)&(y0 <= yshape + height)&(y0 >= yshape))
		pixel = 1;
	else
		pixel = 0;
	end

endmodule							


// This module makes a circle	
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
	if ((xdistsquared + ydistsquared) < radiussquared)	// pixel within radius of circle
		pixel = 1;
	else
		pixel = 0;
	end
endmodule



// This module looks up cos values (multiplied by 2^16) for each clock tick position
module coslookup (input logic [5:0] tick,
						output logic [31:0] costheta);
						
always_comb
case(tick)
	0: costheta = 0;	// 90 degrees (12 o'clock position)
	1: costheta = 6850;	// 84 deg (cos = 0.10453; costheta = 0.10453 * 2^16)
	2: costheta = 13626;	// 78 deg (cos = 0.20791)
	3: costheta = 20252;	// 72 deg (cos = 0.30902)
	4: costheta = 26656;	// 66 deg (cos = 0.40674)
	5: costheta = 32768;	// 60 deg (cos = 0.50000)
	6: costheta = 38521;	// 54 deg (cos = 0.58779)
	7: costheta = 43852;	// 48 deg (cos = 0.66913)
	8: costheta = 48702;	// 42 deg (cos = 0.74314)
	9: costheta = 53020;	// 36 deg (cos = 0.80902)
	10: costheta = 56756;	// 30 deg (cos = 0.86603)
	11: costheta = 59870;	// 24 deg (cos = 0.91355)
	12: costheta = 62329;	// 18 deg (cos = 0.95106)
	13: costheta = 64104;	// 12 deg (cos = 0.97815)
	14: costheta = 65177;	// 6 deg (cos = 0.99452)
	15: costheta = 65536;	// 0 deg (cos = 1)
	16: costheta = 65177;	// -6 deg
	17: costheta = 64104;	// -12 deg
	18: costheta = 62329;	// -18 deg
	19: costheta = 59870;	// -24 deg
	20: costheta = 56756;	// -30 deg
	21: costheta = 53020;	// -36 deg
	22: costheta = 48702;	// -42 deg
	23: costheta = 43852;	// -48 deg
	24: costheta = 38521;	// -54 deg
	25: costheta = 32768;	// -60 deg
	26: costheta = 26656;	// -66 deg
	27: costheta = 20252;	// -72 deg
	28: costheta = 13626;	// -78 deg
	29: costheta = 6850;	// -84 deg
	30: costheta = 0;	// -90 deg
	31: costheta = -6850;	// -96 deg
	32: costheta = -13626;	// -102 deg
	33: costheta = -20252;	// -108 deg
	34: costheta = -26656;	// -114 deg
	35: costheta = -32768;	// -120 deg
	36: costheta = -38521;	// -126 deg
	37: costheta = -43852;	// -132 deg
	38: costheta = -48702;	// -138 deg
	39: costheta = -53020;	// -144 deg
	40: costheta = -56756;	// -150 deg
	41: costheta = -59870;	// -156 deg
	42: costheta = -62329;	// -162 deg
	43: costheta = -64104;	// -168 deg
	44: costheta = -65177;	// -174 deg
	45: costheta = -65536;	// -180 deg = 180 deg
	46: costheta = -65177;	// 174 deg
	47: costheta = -64104;	// 168 deg
	48: costheta = -62329;	// 162 deg
	49: costheta = -59870;	// 156 deg
	50: costheta = -56756;	// 150 deg
	51: costheta = -53020;	// 144 deg
	52: costheta = -48702;	// 138 deg
	53: costheta = -43852;	// 132 deg
	54: costheta = -38521;	// 126 deg
	55: costheta = -32768;	// 120 deg
	56: costheta = -26656;	// 114 deg
	57: costheta = -20252;	// 108 deg
	58: costheta = -13626;	// 102 deg
	59: costheta = -6850;	// 96 deg
	default: costheta = 0;
endcase
endmodule


// This module looks up sin values (multiplied by 2^16) corresponding to each clock tick
module sinlookup (input logic [5:0] tick,
						output logic [31:0] sintheta);
						
always_comb
case(tick)
	0: sintheta = 65536;	// 90 degrees (12 o'clock position)
	1: sintheta = 65177;	// 84 deg (sin = 0.99452; sintheta = 0.99452 * 2^16)
	2: sintheta = 64104;	// 78 deg (sin = 0.97815)
	3: sintheta = 62329;	// 72 deg (sin = 0.95106)
	4: sintheta = 59870;	// 66 deg (sin = 0.91355)
	5: sintheta = 56756;	// 60 deg (sin = 0.86603)
	6: sintheta = 53020;	// 54 deg (sin = 0.80902)
	7: sintheta = 48702;	// 48 deg (sin = 0.74314)
	8: sintheta = 43852;	// 42 deg (sin = 0.66913)
	9: sintheta = 38521;	// 36 deg (sin = 0.58779)
	10: sintheta = 32768;	// 30 deg (sin = 0.50000)
	11: sintheta = 26656;	// 24 deg (sin = 0.40674)
	12: sintheta = 20252;	// 18 deg (sin = 0.30902)
	13: sintheta = 13626;	// 12 deg (sin = 0.20791)
	14: sintheta = 6850;	// 6 deg (sin = 0.10453)
	15: sintheta = 0;	// 0 deg
	16: sintheta = -6850;	// -6 deg
	17: sintheta = -13626;	// -12 deg
	18: sintheta = -20252;	// -18 deg
	19: sintheta = -26656;	// -24 deg
	20: sintheta = -32768;	// -30 deg
	21: sintheta = -38521;	// -36 deg
	22: sintheta = -43852;	// -42 deg
	23: sintheta = -48702;	// -48 deg
	24: sintheta = -53020;	// -54 deg
	25: sintheta = -56756;	// -60 deg
	26: sintheta = -59870;	// -66 deg
	27: sintheta = -62329;	// -72 deg
	28: sintheta = -64104;	// -78 deg
	29: sintheta = -65177;	// -84 deg
	30: sintheta = -65536;	// -90 deg
	31: sintheta = -65177;	// -96 deg
	32: sintheta = -64104;	// -102 deg
	33: sintheta = -62329;	// -108 deg
	34: sintheta = -59870;	// -114 deg
	35: sintheta = -56756;	// -120 deg
	36: sintheta = -53020;	// -126 deg
	37: sintheta = -48702;	// -132 deg
	38: sintheta = -43852;	// -138 deg
	39: sintheta = -38521;	// -144 deg
	40: sintheta = -32768;	// -150 deg
	41: sintheta = -26656;	// -156 deg
	42: sintheta = -20252;	// -162 deg
	43: sintheta = -13626;	// -168 deg
	44: sintheta = -6850;	// -174 deg
	45: sintheta = 0;	// -180 deg = 180 deg
	46: sintheta = 6850;	// 174 deg
	47: sintheta = 13626;	// 168 deg
	48: sintheta = 20252;	// 162 deg
	49: sintheta = 26656;	// 156 deg
	50: sintheta = 32768;	// 150 deg
	51: sintheta = 38521;	// 144 deg
	52: sintheta = 43852;	// 138 deg
	53: sintheta = 48702;	// 132 deg
	54: sintheta = 53020;	// 126 deg
	55: sintheta = 56756;	// 120 deg
	56: sintheta = 59870;	// 114 deg
	57: sintheta = 62329;	// 108 deg
	58: sintheta = 64104;	// 102 deg
	59: sintheta = 65177;	// 96 deg
	default: sintheta = 65536;
endcase
endmodule

