#ifndef TIME_KEEPING_H_
#define TIME_KEEPING_H_

#include <P32xxxx.h>
#include <time.h>

#define MS100 62500
#define MS90 56250
#define NTICKS 10

static inline void startSamplingTimer()
{
    /*
     * Assumes peripheral clock at 20MHz, use Timer2 for sampling timer
     *     bit 15  : ON    = 1  : timer on
     *     bit 14  : FRZ   = 0  : keep running in exception mode
     *     bit 13  : SIDL  = 0  : keep running in idle mode
     *     bit 12-8: unused
     *     bit 7   : TGATE = 0  : disable gated accumulation
     *     bit 6-4 : TCKPS = 101: 1:32 prescaler
     *     bit 3   : T32   = 0  : 16 bit timer
     *     bit 2   : unused
     *     bit 1   : TCS   = 0  : use internal peripheral clock
     *     bit 0   : unused
     */
    T2CON = 0x8050;
}

static inline void resetSamplingTimer()
{
    /* reset timer counter to 0 */
    TMR2 = 0;
}

static inline void startTimeKeepingTimer()
{
    /*
     * Assumes peripheral clock at 20MHz, use Timer2 for sampling timer
     *     bit 15  : ON    = 1  : timer on
     *     bit 14  : FRZ   = 0  : keep running in exception mode
     *     bit 13  : SIDL  = 0  : keep running in idle mode
     *     bit 12-8: unused
     *     bit 7   : TGATE = 0  : disable gated accumulation
     *     bit 6-4 : TCKPS = 101: 1:32 prescaler
     *     bit 3   : T32   = 0  : 16 bit timer
     *     bit 2   : unused
     *     bit 1   : TCS   = 0  : use internal peripheral clock
     *     bit 0   : unused
     */
    T4CON = 0x8050;
}

static inline void resetTimeKeepingTimer()
{
    /* reset timer counter to 0 */
    TMR4 = 0;
}


static inline void holdTimeKeepingTimer()
{
    while (TMR4 < MS100);
}


/* keeps the current time */
typedef struct {
    time_t currentTime;       /* current time */
    int    subSecondCount;    /* number of 25ms ticks since last second */
    int    dst;               /* flag indicating if it's daylight saving time */
} time_keeper;


/*
 * \brief Increment tick by 25 ms.
 *
 * \param timeKeeper Pointer to time_keeper to increment.
 */
void tick(time_keeper* timeKeeper);


/*
 * \brief Manually set the time.
 *
 * \param timeKeeper Pointer to time_keeper to reset.
 * \param newTime Time to reset timeKeeper to.
 * \param dst Flag to indicate if daylight saving is in effect.
 */
void setTime(time_keeper* timeKeeper, time_t newTime, int dst);


/*
 * \brief Initialize IO to get receiver board output.
 */
void initReceiver();


/*
 * \brief Get output from receiver board.
 * \returns 0 or 1 depending on amplitude of carrier wave received.
 */
char getReceiverOutput();


#endif /* TIME_KEEPING_H_ */

