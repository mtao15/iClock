#include <P32xxxx.h>
#include <time.h>
#include "signal_out.h"

#define MS100 62500


int main()
{
    /* initialize output */
    TRISF = 0x0000;


    /* initialize timers */
    T4CON = 0x8050;

    /* start timer */
    TMR4 = 0;

    while (1) {
        /* update time */
        int current = signal_out();
        while (TMR4 < MS100)
            PORTF = current;

        TMR4 = 0;
    }

    return 0;
}

