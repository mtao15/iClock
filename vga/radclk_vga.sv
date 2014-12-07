// radclk_vga.sv
// Last Edited 12/06/2014 by Mengyi Tao & Yukun Lin
// VGA driver for radio clock project
// Based off of vga.sv (20 October 2011 Karl_Wang & David_Harris@hmc.edu)

module radclk_vga(input logic clk,
                  input logic sclk, sdi,                // SPI
                  input logic [3:0] s,
                  output logic vgaclk,                  // 25 MHz VGA clock
                  output logic hsync, vsync, sync_b,    // to monitor & DAC
                  output logic [7:0] r, g, b            // to video DAC
);

  logic [9:0] x, y;
  logic [7:0] r_int, g_int, b_int;

  // Used PLL to create the 25.175 MHz VGA pixel clock
  // 25.175 Mhz clk period = 39.772 ns
  // Screen is 800 clocks wide by 525 tall, but only 640 x 480 used for display
  // HSync = 1/(39.772 ns * 800) = 31.470 KHz
  // Vsync = 31.474 KHz / 525 = 59.94 Hz (~60 Hz refresh rate)

  pll vgapll(.inclk0(clk), .c0(vgaclk));


  // generate monitor timing signals
  vgaController vgaCont(vgaclk, hsync, vsync, sync_b,
  r_int, g_int, b_int, r, g, b, x, y);

  // user-defined module to determine pixel color
  videoGen videoGen(clk, sclk, sdi, s, x, y, r_int, g_int, b_int);

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
                       output logic [9:0] x, y
);

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
  assign hsync = ~(hcnt >= 10'd8 & hcnt < 10'd104);     // horizontal sync
  assign vsync = ~(vcnt >= 2 & vcnt < 4);               // vertical sync
  assign sync_b = hsync | vsync;

  // determine x and y positions
  assign x = hcnt - HSTART;
  assign y = vcnt - VSTART;

  // force outputs to black when outside the legal display area
  assign valid = (hcnt >= HSTART & hcnt < HSTART+WIDTH &
  vcnt >= VSTART & vcnt < VSTART+HEIGHT);
  assign {r,g,b} = valid ? {r_int,g_int,b_int} : 24'b0;
  
endmodule


module videoGen(input logic clk, 
                input logic sclk, sdi,                  //SPI
                input logic [3:0] s,
                input logic [9:0] x, y,
                output logic [7:0] r_int, g_int, b_int
);

  logic pixelstar;
  logic pixelrect;
  logic pixelcircclk;
  logic pixelclk;
  logic pixelsec;
  logic pixelmin;
  logic pixelhr;
  logic pixeldisplay;
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


  // Instantiate modules
  
  // read in time from PIC over SPI 
  spi_receiver spirec(clk, sclk, sdi, s, header, hour_in, minute_in, 
                      second_in, month_in, day_in, year_in);
  
  // generate digital time display for current time & time of last sync
  datetimedisp dateandtime(x, y, header, second_in, minute_in, hour_in, 
                           month_in, day_in, year_in, pixeldisplay);
    
  // generate circular clock face
  circle clkface(10'd320, 10'd240, x, y, 10'd200, pixelcircclk);                            

  // generate clock hands
  rotrectangle secondhand(10'd270, 10'd238, x, y, 10'd200, 
                          10'd4, 10'd320, 10'd240, second_in, pixelsec);
  rotrectangle minutehand(10'd280, 10'd237, x, y, 10'd200, 10'd6, 
                          10'd320, 10'd240, minute_in, pixelmin);
  rotrectangle hourhand(10'd280, 10'd236, x, y, 10'd150, 10'd8, 10'd320, 
                        10'd240, (hour_in % 5'd12)*5 + minute_in/12, 
                        pixelhr);
    
  // generate clock face tick pattern
  clkgenrom clkgen(x-10'd377, y-10'd40, pixelclk);   
    
  // check if (x, y) is consrained to clock face dimension (400 x 400)
  assign clkgenrange = (x >= 10'd120) & (x <= 10'd520) & 
                       (y >= 10'd40) & (y <= 10'd440);   

  always_comb
  begin
  // draw clock hands
  {r_int, g_int, b_int} = {{8{pixelsec}}, {16'h0000}};
  if (r_int == 8'h00 & g_int == 8'h00 & b_int == 8'h00)     // unused pixel
    {r_int, g_int, b_int} = {{7'h0, {1{pixelmin}}}, {7'h0, {1{pixelmin}}}, 
                             {7'h0, {1{pixelmin}}}};
  if (r_int == 8'h00 & g_int == 8'h00 & b_int == 8'h00)        
    {r_int, g_int, b_int} = {{7'h0, {1{pixelhr}}}, {7'h0, {1{pixelhr}}}, 
                             {7'h0, {1{pixelhr}}}};

  // draw clock ticks
  if (r_int == 8'h00 & g_int == 8'h00 & b_int == 8'h00)     
    {r_int, g_int, b_int} = (clkgenrange == 1) ? 
                                {{7'h0, {1{pixelclk}}}, {7'h0, {1{pixelclk}}}, 
                                {7'h0, {1{pixelclk}}}}:  24'h000000;
                          

  // draw circular clock face at center of screen
  if (r_int == 8'h00 & g_int == 8'h00 & b_int == 8'h00)        
    {r_int, g_int, b_int} = {{8{pixelcircclk}}, {8{pixelcircclk}}, 
                             {8{pixelcircclk}}};

  // digital time display
  if (r_int == 8'h00 & g_int == 8'h00 & b_int == 8'h00)       
    {r_int, g_int, b_int} = {{8{pixeldisplay}}, {8{pixeldisplay}}, 
                             {8{pixeldisplay}}};
  end
  
endmodule



// This module generates the digital time display
module datetimedisp (input logic [9:0] x, y,
                     input logic header,
                     input logic [5:0] second_in, minute_in,
                     input logic [4:0] hour_in,
                     input logic [3:0] month_in,
                     input logic [4:0] day_in,
                     input logic [5:0] year_in,
                     output logic pixel);

  logic [50:0] pixelarray;
  logic [9:0] yoffset;
  logic [9:0] xoffset;
  logic [9:0] charheight;
  logic [9:0] charwidth;
  logic [3:0] syncmonth;
  logic [4:0] syncday;
  logic [5:0] syncyear;
  logic [5:0] syncsec, syncmin;
  logic [4:0] synchr;

  // define offset for location of digital text to be displayed on vga
  assign yoffset = 10'd40;
  assign xoffset = 10'd30;
  assign charheight = 10'd8;
  assign charwidth = 10'd8;

  // store time of last sync
  assign syncmonth = ~header ? month_in : syncmonth;
  assign syncday = ~header ? day_in : syncday;
  assign syncyear = ~header ? year_in : syncyear;
  assign syncsec = ~header ? second_in : syncsec;
  assign syncmin = ~header ? minute_in : syncmin;
  assign synchr = ~header ? hour_in : synchr;

  // generate static text "CURRENT TIME" & "LAST SYNC" using charrom.txt
  chargenrom C1(xoffset, yoffset, x, y, 8'd67, pixelarray[0]);              
  chargenrom U1(xoffset+charwidth, yoffset, x, y, 8'd85, pixelarray[1]);    
  chargenrom R1(xoffset+charwidth*2, yoffset, x, y, 8'd82, pixelarray[2]);   
  chargenrom R2(xoffset+charwidth*3, yoffset, x, y, 8'd82, pixelarray[3]);  
  chargenrom E1(xoffset+charwidth*4, yoffset, x, y, 8'd69, pixelarray[4]);  
  chargenrom N1(xoffset+charwidth*5, yoffset, x, y, 8'd78, pixelarray[5]); 
  chargenrom T1(xoffset+charwidth*6, yoffset, x, y, 8'd84, pixelarray[6]);  

  chargenrom T2(xoffset+charwidth*8, yoffset, x, y, 8'd84, pixelarray[7]); 
  chargenrom I1(xoffset+charwidth*9, yoffset, x, y, 8'd73, pixelarray[8]); 
  chargenrom M1(xoffset+charwidth*10, yoffset, x, y, 8'd77, pixelarray[9]); 
  chargenrom E2(xoffset+charwidth*11, yoffset, x, y, 8'd69, pixelarray[10]);  

  chargenrom L1(xoffset+charwidth*61, yoffset, x, y, 8'd76, pixelarray[11]);  
  chargenrom A1(xoffset+charwidth*62, yoffset, x, y, 8'd65, pixelarray[12]);  
  chargenrom S1(xoffset+charwidth*63, yoffset, x, y, 8'd83, pixelarray[13]); 
  chargenrom T3(xoffset+charwidth*64, yoffset, x, y, 8'd84, pixelarray[14]);  

  chargenrom S2(xoffset+charwidth*66, yoffset, x, y, 8'd83, pixelarray[15]);   
  chargenrom Y1(xoffset+charwidth*67, yoffset, x, y, 8'd89, pixelarray[16]);  
  chargenrom N2(xoffset+charwidth*68, yoffset, x, y, 8'd78, pixelarray[17]);  
  chargenrom C2(xoffset+charwidth*69, yoffset, x, y, 8'd67, pixelarray[18]);  

  // generate text for current date (month, day, year) using charrom.txt
  // month
  mongenrom mon(xoffset+charwidth, yoffset+charheight*3/2, x, y, month_in, 
                pixelarray[19]); 
  // tens digit of day
  chargenrom day10(xoffset+charwidth*5, yoffset+charheight*3/2, x, y, 
                   8'd48+(day_in/8'd10), pixelarray[20]);  
  // ones digit of day                 
  chargenrom day1(xoffset+charwidth*6, yoffset+charheight*3/2, x, y, 
                  8'd48+(day_in % 8'd10), pixelarray[21]); 
  // "2" (thoudsands digit of year)                
  chargenrom year3(xoffset+charwidth*8, yoffset+charheight*3/2, x, y, 8'd50, 
                   pixelarray[22]);         
  // "0" (hundreds digit of year)                 
  chargenrom year2(xoffset+charwidth*9, yoffset+charheight*3/2, x, y, 8'd48, 
                   pixelarray[23]);         
  // tens digit of year                 
  chargenrom year1(xoffset+charwidth*10, yoffset+charheight*3/2, x, y, 
                   8'd48+((year_in+8'd14)/8'd10), pixelarray[24]);  
  // ones digit of year                 
  chargenrom year0(xoffset+charwidth*11, yoffset+charheight*3/2, x, y, 
                   8'd48+((year_in+8'd14) % 8'd10), pixelarray[25]);    

  // Generate current time
  // tens digit of hour
  chargenrom hour10(xoffset+charwidth*2, yoffset+charheight*3, x, y, 
                    8'd48+(hour_in/8'd10), pixelarray[26]);    
  // ones digit of hour
  chargenrom hour1(xoffset+charwidth*3, yoffset+charheight*3, x, y, 
                   8'd48+(hour_in % 8'd10), pixelarray[27]);    
  // colon
  chargenrom colon1(xoffset+charwidth*4, yoffset+charheight*3, x, y, 
                    8'd58, pixelarray[28]);  
  // tens digit of hour
  chargenrom min10(xoffset+charwidth*5, yoffset+charheight*3, x, y, 
                   8'd48+(minute_in/8'd10), pixelarray[29]);  
  // ones digit of hour
  chargenrom min1(xoffset+charwidth*6, yoffset+charheight*3, x, y, 
                  8'd48+(minute_in % 8'd10), pixelarray[30]);    
  // colon
  chargenrom colon2(xoffset+charwidth*7, yoffset+charheight*3, x, y, 
                    8'd58, pixelarray[31]);    
  // tens digit of hour
  chargenrom sec10(xoffset+charwidth*8, yoffset+charheight*3, x, y, 
                   8'd48+(second_in/8'd10), pixelarray[32]);    
  // ones digit of hour
  chargenrom sec1(xoffset+charwidth*9, yoffset+charheight*3, x, y, 
                  8'd48+(second_in % 8'd10), pixelarray[33]);    

  // generate date of last sync
  // char representation for month
  mongenrom syncmon(xoffset+charwidth*60, yoffset+charheight*3/2, x, y, 
                    syncmonth, pixelarray[34]);    
  // tens digit of day
  chargenrom syncday10(xoffset+charwidth*64, yoffset+charheight*3/2, x, y, 
                       8'd48+(syncday/8'd10), pixelarray[35]);        
  // ones digit of day
  chargenrom syncday1(xoffset+charwidth*65, yoffset+charheight*3/2, x, y, 
                      8'd48+(syncday % 8'd10), pixelarray[36]);    
  // "2" (thoudsands digit of year)
  chargenrom syncyear3(xoffset+charwidth*67, yoffset+charheight*3/2, x, y, 
                       8'd50, pixelarray[37]);    
  // "0" (hundreds digit of year)
  chargenrom syncyear2(xoffset+charwidth*68, yoffset+charheight*3/2, x, y, 
                       8'd48, pixelarray[38]);    
  // tens digit of year
  chargenrom syncyear1(xoffset+charwidth*69, yoffset+charheight*3/2, x, y, 
                       8'd48+((syncyear+8'd14)/8'd10), pixelarray[39]);    
  // ones digit of year
  chargenrom syncyear0(xoffset+charwidth*70, yoffset+charheight*3/2, x, y, 
                       8'd48+((syncyear+8'd14) % 8'd10), pixelarray[40]);    

  // generate time of last sync
  // tens digit of hour
  chargenrom synchour10(xoffset+charwidth*61, yoffset+charheight*3, x, y, 
                        8'd48+(synchr/8'd10), pixelarray[41]);    
  // ones digit of hour
  chargenrom synchour1(xoffset+charwidth*62, yoffset+charheight*3, x, y, 
                       8'd48+(synchr % 8'd10), pixelarray[42]);    
  // colon
  chargenrom synccolon1(xoffset+charwidth*63, yoffset+charheight*3, x, y, 
                        8'd58, pixelarray[43]);    
  // tens digit of hour
  chargenrom syncmin10(xoffset+charwidth*64, yoffset+charheight*3, x, y, 
                       8'd48+(syncmin/8'd10), pixelarray[44]);    
  // ones digit of hour
  chargenrom syncmin1(xoffset+charwidth*65, yoffset+charheight*3, x, y, 
                      8'd48+(syncmin % 8'd10), pixelarray[45]);    
  // colon
  chargenrom synccolon2(xoffset+charwidth*66, yoffset+charheight*3, x, y, 
                        8'd58, pixelarray[46]);    
  // tens digit of hour
  chargenrom syncsec10(xoffset+charwidth*67, yoffset+charheight*3, x, y, 
                       8'd48+(syncsec/8'd10), pixelarray[47]);    
  // ones digit of hour
  chargenrom syncsec1(xoffset+charwidth*68, yoffset+charheight*3, x, y, 
                      8'd48+(syncsec % 8'd10), pixelarray[48]);    

  assign pixel = pixelarray > 0;  
  
endmodule



module chargenrom(input logic [9:0] xstart, ystart, x, y,
                  input logic [7:0]ch,
                  output logic pixel
);

  logic [5:0] charrom[743:0]; // character generator ROM
  logic [7:0] line;            // a line read from the ROM
  logic [9:0] xdiff, ydiff;

  assign xdiff = x - xstart;
  assign ydiff = y - ystart;

  // initialize ROM with characters from text file
  initial
    $readmemb("charrom.txt", charrom);

  // index into ROM to find line of character
  assign line = {charrom[ydiff[2:0]+{ch, 3'b000}]};
  
  // reverse order of bits; see if pixel is within range of desired character
  assign pixel = ((ydiff < 10'd8) & (xdiff <= 10'd8)) ? line[3'd7-xdiff[2:0]] 
                                                        : 0;
  endmodule



// This module generates display for 3-letter representation of month
module mongenrom(input  logic [9:0] xstart, ystart, x, y,
                 input  logic [3:0] month,
                 output logic pixel
);

  logic [23:0] monthrom[110:0]; // character generator ROM
  logic [23:0] line;            // a line read from the ROM
  logic [9:0] xdiff, ydiff;

  assign xdiff = x - xstart;
  assign ydiff = y - ystart;

  // initialize ROM with characters from text file
  initial
    $readmemb("monthrom.txt", monthrom);

  // index into ROM to find line of character
  assign line = {monthrom[ydiff[2:0]+{month, 3'b000}]};
  // reverse order of bits & decide if pixel is within range of desired character
  assign pixel = ((ydiff < 10'd8) & (xdiff <= 10'd24)) ? line[5'd24-xdiff[4:0]] : 0;

endmodule



// This module draws the clock face
module clkgenrom(input logic [9:0] x, y,
                 output logic pixel
);

  logic [399:0] clocktick[399:0];        // clock tick generator ROM
  logic [399:0] line;                    // a line read from the ROM

  // initialize ROM with characters from text file
  initial
    $readmemb("clkface1.txt", clocktick);   // .txt file of clock tick pattern

  // index into ROM to find line of character
  assign line = {clocktick[y]};

  // reverse order of bits
  assign pixel = line[8'd399-x];
  
endmodule



// This module makes a rotated rectangle 
// The rectanlge has top left corner at (xshape, yshape) before rotation
// The point of rotation is at (xrot, yrot); theta = tick * 6 degrees

module rotrectangle (input logic [9:0] xshape, yshape, x, y,   
                     input logic [9:0] width, height,
                     input logic [9:0] xrot, yrot,   
                     input logic [5:0] tick,      
                     output logic pixel
);

  logic [31:0] costheta;    //costheta = cos(tick*6)*2^16
  logic [31:0] sintheta;    //sintheta = sin(tick*6)*2^16
  logic [9:0] x0;
  logic [9:0] y0;

  coslookup trigcos(tick, costheta);
  sinlookup trigsin(tick, sintheta);

  always_comb
  begin
    // 'unrotate' current pixel using rotation matrix
    x0 = (((x-xrot)*costheta - (y-yrot)*sintheta)>>16) + xrot; 
    y0 = (((y-yrot)*costheta + (x-xrot)*sintheta)>>16) + yrot;

    // check if current pixel is a part of the rotated rectangle
    if ((x0 <= xshape + width) & (x0 >= xshape) & (y0 <= yshape + height) 
         & (y0 >= yshape))
      pixel = 1;
    else
      pixel = 0;
  end

endmodule



// This module makes a circle centered at (xcent, ycent) with radius of radius
module circle (input logic [9:0] xcent, ycent, x, y, 
               input logic [9:0] radius,
               output logic pixel
);

  logic [19:0]xdistsquared;
  logic [19:0]ydistsquared;
  logic [19:0]radiussquared;

  always_comb
  begin
    xdistsquared = ((x-xcent)*(x-xcent));
    ydistsquared = ((y-ycent)*(y-ycent));
    radiussquared = (radius*radius);
    
    // check if pixel is within radius of circle
    if ((xdistsquared + ydistsquared) < radiussquared)    
      pixel = 1;
    else
      pixel = 0;
  end

endmodule



// This module looks up cos(tick)*2^16
module coslookup (input logic [5:0] tick,
                  output logic [31:0] costheta
);

  always_comb
  case(tick)
    0: costheta = 0;       // 90 degrees (12 o'clock position)
    1: costheta = 6850;    // 84 deg (cos = 0.10453; costheta = 0.10453 * 2^16)
    2: costheta = 13626;   // 78 deg (cos = 0.20791)
    3: costheta = 20252;   // 72 deg (cos = 0.30902)
    4: costheta = 26656;   // 66 deg (cos = 0.40674)
    5: costheta = 32768;   // 60 deg (cos = 0.50000)
    6: costheta = 38521;   // 54 deg (cos = 0.58779)
    7: costheta = 43852;   // 48 deg (cos = 0.66913)
    8: costheta = 48702;   // 42 deg (cos = 0.74314)
    9: costheta = 53020;   // 36 deg (cos = 0.80902)
    10: costheta = 56756;  // 30 deg (cos = 0.86603)
    11: costheta = 59870;  // 24 deg (cos = 0.91355)
    12: costheta = 62329;  // 18 deg (cos = 0.95106)
    13: costheta = 64104;  // 12 deg (cos = 0.97815)
    14: costheta = 65177;  // 6 deg (cos = 0.99452)
    15: costheta = 65536;  // 0 deg (cos = 1)
    16: costheta = 65177;  // -6 deg
    17: costheta = 64104;  // -12 deg
    18: costheta = 62329;  // -18 deg
    19: costheta = 59870;  // -24 deg
    20: costheta = 56756;  // -30 deg
    21: costheta = 53020;  // -36 deg
    22: costheta = 48702;  // -42 deg
    23: costheta = 43852;  // -48 deg
    24: costheta = 38521;  // -54 deg
    25: costheta = 32768;  // -60 deg
    26: costheta = 26656;  // -66 deg
    27: costheta = 20252;  // -72 deg
    28: costheta = 13626;  // -78 deg
    29: costheta = 6850;   // -84 deg
    30: costheta = 0;      // -90 deg
    31: costheta = -6850;  // -96 deg
    32: costheta = -13626; // -102 deg
    33: costheta = -20252; // -108 deg
    34: costheta = -26656; // -114 deg
    35: costheta = -32768; // -120 deg
    36: costheta = -38521; // -126 deg
    37: costheta = -43852; // -132 deg
    38: costheta = -48702; // -138 deg
    39: costheta = -53020; // -144 deg
    40: costheta = -56756; // -150 deg
    41: costheta = -59870; // -156 deg
    42: costheta = -62329; // -162 deg
    43: costheta = -64104; // -168 deg
    44: costheta = -65177; // -174 deg
    45: costheta = -65536; // -180 deg = 180 deg
    46: costheta = -65177; // 174 deg
    47: costheta = -64104; // 168 deg
    48: costheta = -62329; // 162 deg
    49: costheta = -59870; // 156 deg
    50: costheta = -56756; // 150 deg
    51: costheta = -53020; // 144 deg
    52: costheta = -48702; // 138 deg
    53: costheta = -43852; // 132 deg
    54: costheta = -38521; // 126 deg
    55: costheta = -32768; // 120 deg
    56: costheta = -26656; // 114 deg
    57: costheta = -20252; // 108 deg
    58: costheta = -13626; // 102 deg
    59: costheta = -6850;  // 96 deg
    default: costheta = 0;
  endcase
 
endmodule



// This module looks up sin(tick)* 2^16
module sinlookup (input logic [5:0] tick,
                  output logic [31:0] sintheta
);

  always_comb
  case(tick)
    0: sintheta = 65536;   // 90 degrees (12 o'clock position)
    1: sintheta = 65177;   // 84 deg (sin = 0.99452; sintheta = 0.99452 * 2^16)
    2: sintheta = 64104;   // 78 deg (sin = 0.97815)
    3: sintheta = 62329;   // 72 deg (sin = 0.95106)
    4: sintheta = 59870;   // 66 deg (sin = 0.91355)
    5: sintheta = 56756;   // 60 deg (sin = 0.86603)
    6: sintheta = 53020;   // 54 deg (sin = 0.80902)
    7: sintheta = 48702;   // 48 deg (sin = 0.74314)
    8: sintheta = 43852;   // 42 deg (sin = 0.66913)
    9: sintheta = 38521;   // 36 deg (sin = 0.58779)
    10: sintheta = 32768;  // 30 deg (sin = 0.50000)
    11: sintheta = 26656;  // 24 deg (sin = 0.40674)
    12: sintheta = 20252;  // 18 deg (sin = 0.30902)
    13: sintheta = 13626;  // 12 deg (sin = 0.20791)
    14: sintheta = 6850;   // 6 deg (sin = 0.10453)
    15: sintheta = 0;      // 0 deg
    16: sintheta = -6850;  // -6 deg
    17: sintheta = -13626; // -12 deg
    18: sintheta = -20252; // -18 deg
    19: sintheta = -26656; // -24 deg
    20: sintheta = -32768; // -30 deg
    21: sintheta = -38521; // -36 deg
    22: sintheta = -43852; // -42 deg
    23: sintheta = -48702; // -48 deg
    24: sintheta = -53020; // -54 deg
    25: sintheta = -56756; // -60 deg
    26: sintheta = -59870; // -66 deg
    27: sintheta = -62329; // -72 deg
    28: sintheta = -64104; // -78 deg
    29: sintheta = -65177; // -84 deg
    30: sintheta = -65536; // -90 deg
    31: sintheta = -65177; // -96 deg
    32: sintheta = -64104; // -102 deg
    33: sintheta = -62329; // -108 deg
    34: sintheta = -59870; // -114 deg
    35: sintheta = -56756; // -120 deg
    36: sintheta = -53020; // -126 deg
    37: sintheta = -48702; // -132 deg
    38: sintheta = -43852; // -138 deg
    39: sintheta = -38521; // -144 deg
    40: sintheta = -32768; // -150 deg
    41: sintheta = -26656; // -156 deg
    42: sintheta = -20252; // -162 deg
    43: sintheta = -13626; // -168 deg
    44: sintheta = -6850;  // -174 deg
    45: sintheta = 0;      // -180 deg = 180 deg
    46: sintheta = 6850;   // 174 deg
    47: sintheta = 13626;  // 168 deg
    48: sintheta = 20252;  // 162 deg
    49: sintheta = 26656;  // 156 deg
    50: sintheta = 32768;  // 150 deg
    51: sintheta = 38521;  // 144 deg
    52: sintheta = 43852;  // 138 deg
    53: sintheta = 48702;  // 132 deg
    54: sintheta = 53020;  // 126 deg
    55: sintheta = 56756;  // 120 deg
    56: sintheta = 59870;  // 114 deg
    57: sintheta = 62329;  // 108 deg
    58: sintheta = 64104;  // 102 deg
    59: sintheta = 65177;  // 96 deg
    default: sintheta = 65536;
  endcase
  
endmodule