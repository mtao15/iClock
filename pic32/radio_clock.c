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


int createPacket(struct tm* timeToSend)
{
    int year = timeToSend->tm_year + 1900;
    int month = timeToSend->tm_mon + 1;
    int day = timeToSend->tm_mday;
    int hour = timeToSend->tm_hour;
    int minute = timeToSend->tm_min;

    year  = year << 20;
    month = month << 16;
    day   = day << 11;
    hour  = hour << 6;

    return year | month | day | hour | minute;
}


int main()
{
    /* initialize receiver timers */
    initReceiver();
    resetTimeKeepingTimer();
    resetSamplingTimer();

    /* initialize current time to 00:00:00, Januray 1, 2000 UTC */
    time_keeper timeKeeper;
    setTime(&timeKeeper, 0x386D4380, 0);

    /* set up time signal decoder */
    timeDecoder decoder;
    initDecoder(&decoder);

    /* start timer */
    startTimeKeepingTimer();

    while (1) {
        char x = getReceiverOutput();

        int rVal = updateDecoder(&decoder, x);

        PORTD = decoder.bitCount;

        if (rVal == 3) {
            int err = updateTimeAndDate(&decoder,
                                        &(timeKeeper.currentTime),
                                        &(timeKeeper.dst));
            /* reset decoder */
            initDecoder(&decoder);

            /* covert unix time year, month, day, hour and minute
             * and encode it in 32 bits */
            struct tm* timeToSend = localtime(&(timeKeeper.currentTime));
            int      packetToSend = createPacket(timeToSend);
        }

        tick(&timeKeeper);
        holdTimeKeepingTimer();
        resetTimeKeepingTimer();
    }
    return 0;
}

