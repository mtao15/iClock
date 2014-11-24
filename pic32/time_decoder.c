#include <stdio.h>
#include "time_decoder.h"

void initTimeDecoder(timeDecoder* decoder)
{
    /* reset everything to starting state */
    decoder->inputCount = 0;
    decoder->bitsCount = 0;
    decoder->currentState = waitForHigh;
}


int updateTimeDecoder(timeDecoder* decoder, short input)
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
            rVal = 2;
            break;
    }

    return rVal;
}


void updateInputBuffer(timeDecoder* decoder, short input)
{
    /* update inputCount and inputBuffer */
    (decoder->inputBuffer)[decoder->inputCount++] = input;
}


int updateBitBuffer(timeDecoder* decoder)
{
    short zeroCounts = 0;

    short* inputBuffer = decoder->inputBuffer;

    /* Count number of zeroes */
    for (int i = 0; i < decoder->inputCount; i++)
        if (!inputBuffer[i]) zeroCounts++;

    /* number or zero samples encode the bit */
    short marker = 4 * NSAMPLES / 5;
    short zero   =     NSAMPLES / 5;
    short one    =     NSAMPLES / 2;

    char bit;

    if (zeroCounts >= marker - 2 && zeroCounts <= marker + 2)
        bit = 'm';
    else if (zeroCounts >= zero - 2 && zeroCounts <= zero + 2)
        bit = '0';
    else if (zeroCounts >= one - 2 && zeroCounts <= one + 2)
        bit = '1';
    else
        return 1;

    (decoder->bitsBuffer)[decoder->bitsCount++] = bit;

    return 0;
}


int funcWaitForHigh(timeDecoder* decoder, short input)
{
    /* detected high raw input */
    if (input)
        decoder->currentState = waitForEdge;

    return 0;
}


int funcWaitForEdge(timeDecoder* decoder, short input)
{
    /* detected falling edge */
    if (!input) {
        decoder->currentState = countLow;
        updateInputBuffer(decoder, input);
    }

    return 0;
}


int funcCountLow(timeDecoder* decoder, short input)
{
    /* reset decoder if there are too many 0 samples */
    if (decoder->inputCount >= NSAMPLES) {
        initTimeDecoder(decoder);
        return 1;
    }

    /* update input buffer */
    updateInputBuffer(decoder, input);

    /* if input is 1, go to countHigh state */
    if (input)
        decoder->currentState = countHigh;

    return 0;
}


int funcCountHigh(timeDecoder* decoder, short input)
{
    short inputCount = decoder->inputCount;

    /* check if there is not too many or too little ones */
    short over  = inputCount >= NSAMPLES + NSPADDING;
    short under = inputCount <  NSAMPLES - NSPADDING && !input ;

    /* reset decoder if there are too many or not enough 1 samples */
    if (over || under) {
        initTimeDecoder(decoder);
        return 1;
    }

    /* if input is 1, update inputCount and inputBuffer */
    if (input) {
        updateInputBuffer(decoder, input);
        return 0;
    }

    /* if input is 0, decode bit from inputBuffer and update bitBuffer */
    int err = updateBitBuffer(decoder);

    /* inputBuffer does not encode a valid bit */
    if (err) {
        initTimeDecoder(decoder);
        return 1;
    }

    /* go to bufferFull state if bitBuffer is now full */
    if (decoder->bitsCount >= BUFFERSIZE) {
        decoder->currentState = bufferFull;
        return 2;
    }

    decoder->inputCount = 0;
    decoder->currentState = countLow;
    updateInputBuffer(decoder, input);

    return 0;
}

