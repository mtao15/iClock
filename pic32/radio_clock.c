#include "time_keeping.h"
#include "time_decoder.h"

//SPI
void SPI_mouseOutput(void){
	// SPI setup
	long readdata;
	SPI2CON = 0xFFFF7FFF && SPI2CON; 	// turn off SPI
	readdata = SPI2BUF; 				// read BUF to clear it
	SPI2BRG = 0x0007;					// set baud rate to 1.25MHz for a 20MHz peripheral clk
	SPI2CON = SPI2CON | 0x00000920;	// set to Master mode (bit 5), SDO centered on rising clk edge (bit 8), 32 bit mode (bit 11 - 10)
	SPI2CON = SPI2CON | 0x00008000;	// turn SPI back on


	// Send mouse position data over SPI
	short xmouse, ymouse;
	long outputpos;
	xmouse = xpos/scale;	// Scaled x mouse location
	ymouse = ypos/scale;	// Scaled y mouse location
	outputpos = xmouse;
	outputpos = outputpos << 16;
	outputpos = outputpos | ymouse;	// outputpos = {{xmouse}{ymouse}}
	SPI2BUF = outputpos;
}

int main()
{
    initReceiver();

    resetTimeKeepingTimer();
    resetSamplingTimer();

    time_keeper timeKeeper;
    setTime(&timeKeeper, 42);

    timeDecoder decoder;
    initDecoder(&decoder);

    time_t theCurrentUnixTime = 0;
    while (1) {
        startTimeKeepingTimer();
        char x = getReceiverOutput();

        int rVal = updateDecoder(&decoder, x);

        PORTD = decoder.bitCount;

        int dst;
        if (rVal == 3) {
            int err = updateTimeAndDate(&decoder, &(timeKeeper.currentTime), &dst);
            if (err == 0) {
                theCurrentUnixTime = timeKeeper.currentTime;
                break;
            }

        }

        tick(&timeKeeper);
        holdTimeKeepingTimer();
        resetTimeKeepingTimer();
    }
    return 0;
}
