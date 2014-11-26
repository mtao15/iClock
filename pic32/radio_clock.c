#include "time_keeping.h"
#include "time_decoder.h"

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
