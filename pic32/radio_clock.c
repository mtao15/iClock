#include "time_keeping.h"
#include "time_decoder.h"

/* offset for pacific time zone */
#define TIMEZONE -28800

void initSPI()
{
	// SPI setup
	long readdata;

    /* turn off SPI */
	SPI2CON = 0x0;//0xFFFF7FFF & SPI2CON;

    /* read BUF to clear it */
	readdata = SPI2BUF;

    /* set baud rate to 1.25MHz for a 20MHz peripheral clk */
	SPI2BRG = 0x0007;

    /* set to Master mode (bit 5), SDO centered on rising clk edge (bit 8),
     * 32 bit mode (bit 11 - 10) */
	SPI2CON = SPI2CON | 0x00000920;

    /* turn SPI back on */
	SPI2CON = SPI2CON | 0x00008000;
}


void sendCurrentTime(int packet)
{
	SPI2BUF = packet;
}


int createPacket(struct tm* timeToSend, int packetType)
{
    int year = timeToSend->tm_year + 1900 - 2014;
    int month = timeToSend->tm_mon + 1;
    int day = timeToSend->tm_mday;
    int hour = timeToSend->tm_hour;
    int minute = timeToSend->tm_min;
    int second = timeToSend->tm_sec;

    int header = packetType << 31;

    year   = year << 26;
    month  = month << 22;
    day    = day << 17;
    hour   = hour << 12;
    minute = minute << 6;

    return header | year | month | day | hour | minute | second;
}


int main()
{
    /* initialize receiver board */
    initReceiver();

    /* initialize SPI module */
    initSPI();

    /* initialize timers */
    resetTimeKeepingTimer();
    resetSamplingTimer();

    /* initialize current time to 00:00:00, Januray 1, 2014 UTC */
    time_keeper timeKeeper;
    setTime(&timeKeeper, 1388534400, 0);

    /* set up time signal decoder */
    timeDecoder decoder;
    initDecoder(&decoder);

    /* start timer */
    startTimeKeepingTimer();
    startSamplingTimer();

    while (1) {
        /* update time */
        tick(&timeKeeper);

        /* get output from receiver */
        char x = getReceiverOutput();

        int packetHeader = 1;

        /* update decoder and get its status */
        int decoderStatus = updateDecoder(&decoder, x);
        PORTD = decoder.bitCount;

        /* if decoder has two full transmission frames */
        if (decoderStatus == 3) {
            /* decode the two frames to get current time */
            time_t currentUnixTime;
            int dst;
            int err = updateTimeAndDate(&decoder, &currentUnixTime, &dst);

            /* reset decoder */
            initDecoder(&decoder);

            if (!err) {
                /* update time keeper */
                setTime(&timeKeeper, currentUnixTime, dst);

                /* next data packet will indicate sync has happened */
                packetHeader = 0;
            }
        }

        /* offset utc time to local time */
        int dstOffset           = timeKeeper.dst * 3600;
        time_t currentLocalTime = timeKeeper.currentTime + TIMEZONE + dstOffset;

        /* send current local time to FPGA via SPI */
        struct tm* timeToSend = localtime(&currentLocalTime);
        int        timePacket = createPacket(timeToSend, packetHeader);
        sendCurrentTime(timePacket);

        /* pause loop until 25 ms has ellapsed */
        holdTimeKeepingTimer();
        resetTimeKeepingTimer();
    }

    return 0;
}

