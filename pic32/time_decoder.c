#include "time_decoder.h"
#include <stdio.h>

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

    switch(decoder->currentState)
    {
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
    int inputCount = decoder->inputCount;

    /* check if there is not too many or too few ones */
    int over  = inputCount >= NSAMPLES + NSPADDING &&  input;
    int under = inputCount <  NSAMPLES - NSPADDING && !input;

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
            decoder->currentState = countLow;
            return err;

        default:
            break;
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


int decodeFrame(char* bitBuffer, struct tm* currentTime)
{
    int err;

    err = checkFrame(bitBuffer);
    if (err)
        return 1;

    err = decodeTime(bitBuffer, currentTime);
    if (err)
        return 1;

    err = decodeDate(bitBuffer, currentTime);
    if (err)
        return 1;

    return 0;
}


int decodeTime(char* bitBuffer, struct tm* currentTime)
{
    /* calculate hour and minute */
    int minute = bitBuffer[1] * 40 + bitBuffer[2] * 20
               + bitBuffer[3] * 10 + bitBuffer[5] * 8
               + bitBuffer[6] * 4  + bitBuffer[7] * 2  + bitBuffer[8];

    int hour   = bitBuffer[12] * 20 + bitBuffer[13] * 10
               + bitBuffer[15] *  8 + bitBuffer[16] * 4
               + bitBuffer[17] *  2 + bitBuffer[18];

    /* check that encoded hour and minutes are valid */
    if (minute > 59 || hour > 23)
        return 1;

    currentTime->tm_sec  = 0;
    currentTime->tm_min  = minute;
    currentTime->tm_hour = hour;

    return 0;
}


int decodeDate(char* bitBuffer, struct tm* currentTime)
{
    /* calculate day of year and current year */
    int day  = bitBuffer[22] * 200 + bitBuffer[23] * 100
             + bitBuffer[25] * 80  + bitBuffer[26] * 40
             + bitBuffer[27] * 20  + bitBuffer[28] * 10
             + bitBuffer[30] * 8   + bitBuffer[31] * 4
             + bitBuffer[32] * 2   + bitBuffer[33];

    int year = bitBuffer[45] * 80 + bitBuffer[46] * 40
             + bitBuffer[47] * 20 + bitBuffer[48] * 10
             + bitBuffer[50] * 8  + bitBuffer[51] * 4
             + bitBuffer[52] * 2  + bitBuffer[53] + 2000;

    int dst  = bitBuffer[57] && bitBuffer[58];

    /* check if it's a leap year */
    int leapYear;
    if (year % 400 == 0 || (year % 4 == 0 && year % 100 != 0))
        leapYear = 1;

    /* check that the encoded day is valid and leap year matches up */
    if (day > 365 + leapYear || leapYear != bitBuffer[55])
        return 1;

    int daysInMonth[12] = {31, 28 + leapYear, 31, 30, 31, 30,
                           31, 31,            30, 31, 30, 31};

    /* 0 to 11 inclusive for month, convention of tm struct */
    int month    = 0;
    int daysUsed = 0;

    /* calculate current month */
    while (day > daysUsed) {
        daysUsed += daysInMonth[month++];
    }

    /* calculate day of the month */
    int dayOfMonth = daysInMonth[--month] - (daysUsed - day);

    /* update current date */
    currentTime->tm_year  = year - 1900;    /* convention of tm struct */
    currentTime->tm_mon   = month;
    currentTime->tm_mday  = dayOfMonth;
    currentTime->tm_isdst = dst;

    return 0;
}


int checkFrame(char* bitBuffer)
{
    int valid =
        bitBuffer[0]  == 'm' && bitBuffer[4]  ==  0  && bitBuffer[9]  == 'm' &&
        bitBuffer[10] ==  0  && bitBuffer[11] ==  0  && bitBuffer[14] ==  0  &&
        bitBuffer[19] == 'm' && bitBuffer[20] ==  0  && bitBuffer[21] ==  0  &&
        bitBuffer[24] ==  0  && bitBuffer[29] == 'm' && bitBuffer[34] ==  0  &&
        bitBuffer[35] ==  0  && bitBuffer[39] == 'm' && bitBuffer[44] ==  0  &&
        bitBuffer[49] == 'm' && bitBuffer[54] ==  0  && bitBuffer[59] == 'm';

    /* follow convention of returning 0 for success */
    return !valid;
}

