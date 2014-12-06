#include "time_keeping.h"

void tick(time_keeper* timeKeeper)
{
    if (++(timeKeeper->subSecondCount) >= NTICKS) {
        timeKeeper->subSecondCount = 0;
        timeKeeper->currentTime++;
    }
}


void setTime(time_keeper* timeKeeper, time_t newTime, int dst)
{
    timeKeeper->currentTime = newTime;
    timeKeeper->subSecondCount = 0;
    timeKeeper->dst = dst;
}


void initReceiver()
{
    /* set up LEDs to display received signal */
    TRISD = 0xFF00;

    /* set up input for receiver board */
    TRISF = 0xFFFF;
}


char getReceiverOutput()
{
    /* get input from RF0, output from board is negated */
    char accum = ~PORTF & 0x1;
    resetSamplingTimer();

    /* get a sample every millisecond */
    int intervalCount = MS90 / 1000;
    int count = 1;

    while (TMR2 < MS90) {
        if (TMR2 % intervalCount == 0) {
            accum += ~PORTF & 0x1;
            count++;
        }
    }


    /* write to led for debugging */
    char avg = accum / count;

    return avg;
}
