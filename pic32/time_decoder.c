#include "time_decoder.h"

void initDecoder(timeDecoder* decoder)
{
    /* reset everything to starting state */
    decoder->inputCount   = 0;
    decoder->bitCount     = 0;
    decoder->currentState = waitForHigh;
    decoder->foundStart   = 0;
}


int updateDecoder(timeDecoder* decoder, int input)
{
    int rVal;

    switch(decoder->currentState) {
        case waitForHigh:
            rVal = funcWaitForHigh(decoder, input);
            break;

        case waitForEdge:
            rVal = funcWaitForEdge(decoder, input);
            break;

        case countLow:
            rVal = funcCountLow(decoder, input);
            break;

        case countHigh:
            rVal = funcCountHigh(decoder, input);
            break;

        default:
            rVal = 3;
            break;
    }

    return rVal;
}


int updateTimeAndDate(timeDecoder* decoder, time_t* currentTime, int* dst)
{
    char* frame1 = decoder->bitBuffer;
    char* frame2 = decoder->bitBuffer + 60;

    struct tm frame1Time, frame2Time;

    /* decode the 2 frames and check for errors */
    if (decodeFrame(frame1, &frame1Time) || decodeFrame(frame2, &frame2Time))
        return 1;

    /* daylight saving times don't match */
    if (frame1Time.tm_isdst != frame2Time.tm_isdst)
        return 1;

    /* remove and store dst flag */
    int dstFlag = frame2Time.tm_isdst;
    frame1Time.tm_isdst = frame2Time.tm_isdst = -1;

    /* convert to unix time */
    time_t unixTime1 = mktime(&frame1Time);
    time_t unixTime2 = mktime(&frame2Time);

    /* check for time conversion errors */
    if (unixTime1 == -1 || unixTime2 == -1)
        return 1;

    /* check that the two frames differ by 60 seconds */
    if (unixTime2 - unixTime1 != 60)
        return 1;

    /* 60 seconds has passed since the second frame */
    *currentTime = unixTime2 + 60;
    *dst = dstFlag;

    return 0;
}


void updateInputBuffer(timeDecoder* decoder, int input)
{
    /* update inputCount and inputBuffer */
    (decoder->inputBuffer)[decoder->inputCount++] = input;
}


int updateBitBuffer(timeDecoder* decoder)
{
    int zeroCounts = 0;

    char* inputBuffer = decoder->inputBuffer;

    /* Count number of zeroes */
    for (int i = 0; i < decoder->inputCount; i++)
        if (!inputBuffer[i]) zeroCounts++;

    /* number or zero samples encode the bit */
    int marker = 4 * NSAMPLES / 5;
    int zero   =     NSAMPLES / 5;
    int one    =     NSAMPLES / 2;

    char bit;

    if (zeroCounts >= marker - 2 && zeroCounts <= marker + 2)
        bit = 'm';
    else if (zeroCounts >= zero - 2 && zeroCounts <= zero + 2)
        bit = 0;
    else if (zeroCounts >= one - 2 && zeroCounts <= one + 2)
        bit = 1;
    else
        return 1;


    int   bitCount  = decoder->bitCount;
    char* bitBuffer = decoder->bitBuffer;

    /* if empty bitBuffer and marker, or frame star found, append bit */
    if ((bitCount == 0 && bit == 'm') || decoder->foundStart) {
        bitBuffer[decoder->bitCount++] = bit;
        return 0;
    }

    /* two consecutive marker bits, start of frame has been found */
    if (bitCount == 1 && bitBuffer[0] == 'm' && bit == 'm') {
        decoder->foundStart = 1;
        return 0;
    }

    return 2;
}


int funcWaitForHigh(timeDecoder* decoder, int input)
{
    /* detected high raw input */
    if (input)
        decoder->currentState = waitForEdge;

    return 0;
}


int funcWaitForEdge(timeDecoder* decoder, int input)
{
    /* detected falling edge */
    if (!input) {
        decoder->currentState = countLow;
        updateInputBuffer(decoder, input);
    }

    return 0;
}


int funcCountLow(timeDecoder* decoder, int input)
{
    /* reset decoder if there are too many 0 samples */
    if (decoder->inputCount >= NSAMPLES) {
        initDecoder(decoder);
        return 1;
    }

    /* update input buffer */
    updateInputBuffer(decoder, input);

    /* if input is 1, go to countHigh state */
    if (input)
        decoder->currentState = countHigh;

    return 0;
}


int funcCountHigh(timeDecoder* decoder, int input)
{
    /* check if there is not too many or too few ones */
    int over  = decoder->inputCount >= NSAMPLES + NSPADDING &&  input;
    int under = decoder->inputCount <  NSAMPLES - NSPADDING && !input;

    /* reset decoder if there are too many or not enough 1 samples */
    if (over || under) {
        initDecoder(decoder);
        return 1;
    }

    /* if input is 1, update inputCount and inputBuffer */
    if (input) {
        updateInputBuffer(decoder, input);
        return 0;
    }

    /* if input is 0, decode bit from inputBuffer and update bitBuffer */
    int err = updateBitBuffer(decoder);

    /* check for error conditions */
    switch (err) {

        case 1:    /* inputBuffer does not encode a valid bit */
            initDecoder(decoder);
            return err;

        case 2:    /* valid bit, but haven't found start of frame */
            initDecoder(decoder);
            updateInputBuffer(decoder, input);
            decoder->currentState = countLow;
            return err;
    }

    /* go to bufferFull state if bitBuffer is now full */
    if (decoder->bitCount >= BUFFERSIZE) {
        decoder->currentState = bufferFull;
        return 3;
    }

    /* start counting 0's again */
    decoder->inputCount = 0;
    decoder->currentState = countLow;
    updateInputBuffer(decoder, input);

    return 0;
}


int decodeFrame(char* frame, struct tm* frameTime)
{
    /* check position of marker and predefined 0 bits */
    if (checkFrame(frame))
        return 1;


    /* decode time and check for errors */
    if (decodeTime(frame, frameTime))
        return 1;


    /* decode date and check for errors */
    if (decodeDate(frame, frameTime))
        return 1;

    return 0;
}


int decodeTime(char* frame, struct tm* frameTime)
{
    /* calculate hour and minute */
    int minute = frame[1] * 40 + frame[2] * 20
               + frame[3] * 10 + frame[5] * 8
               + frame[6] * 4  + frame[7] * 2  + frame[8];

    int hour   = frame[12] * 20 + frame[13] * 10
               + frame[15] *  8 + frame[16] * 4
               + frame[17] *  2 + frame[18];

    /* check that encoded hour and minutes are valid */
    if (minute > 59 || hour > 23)
        return 1;

    frameTime->tm_sec  = 0;
    frameTime->tm_min  = minute;
    frameTime->tm_hour = hour;

    return 0;
}


int decodeDate(char* frame, struct tm* frameTime)
{
    /* calculate day of year and current year */
    int day  = frame[22] * 200 + frame[23] * 100
             + frame[25] * 80  + frame[26] * 40
             + frame[27] * 20  + frame[28] * 10
             + frame[30] * 8   + frame[31] * 4
             + frame[32] * 2   + frame[33];

    int year = frame[45] * 80 + frame[46] * 40
             + frame[47] * 20 + frame[48] * 10
             + frame[50] * 8  + frame[51] * 4
             + frame[52] * 2  + frame[53] + 2000;

    int dst  = frame[57] && frame[58];

    /* check if it's a leap year */
    int leapYear = 0;
    if (year % 400 == 0 || (year % 4 == 0 && year % 100 != 0))
        leapYear = 1;

    /* check that the encoded day is valid and leap year matches up */
    if (day > 365 + leapYear || leapYear != frame[55])
        return 1;


    int daysInMonth[12] = {31, 28 + leapYear, 31, 30, 31, 30,
                           31, 31,            30, 31, 30, 31};

    /* 0 to 11 inclusive for month, convention of tm struct */
    int month    = 0;
    int daysUsed = 0;

    /* calculate current month */
    while (day > daysUsed)
        daysUsed += daysInMonth[month++];

    /* calculate day of the month */
    int dayOfMonth = daysInMonth[--month] - (daysUsed - day);

    /* update current date */
    frameTime->tm_year  = year - 1900;    /* convention of tm struct */
    frameTime->tm_mon   = month;
    frameTime->tm_mday  = dayOfMonth;
    frameTime->tm_isdst = dst;

    return 0;
}


int checkFrame(char* frame)
{
    int valid =
        frame[0]  == 'm' && frame[4]  ==  0  && frame[9]  == 'm' &&
        frame[10] ==  0  && frame[11] ==  0  && frame[14] ==  0  &&
        frame[19] == 'm' && frame[20] ==  0  && frame[21] ==  0  &&
        frame[24] ==  0  && frame[29] == 'm' && frame[34] ==  0  &&
        frame[35] ==  0  && frame[39] == 'm' && frame[44] ==  0  &&
        frame[49] == 'm' && frame[54] ==  0  && frame[59] == 'm';

    /* follow convention of returning 0 for success */
    return !valid;
}

