#include "time_keeping.h"
#include "time_decoder.h"


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

