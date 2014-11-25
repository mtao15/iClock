#include <stdio.h>

#include "time_decoder.h"

void printState(timeDecoder* decoder)
{
    switch (decoder->currentState)
    {
        case waitForHigh:
            printf("%s\n", "current state: waitForHigh");
            break;

        case waitForEdge:
            printf("%s\n", "current state: waitForEdge");
            break;

        case countLow:
            printf("%s\n", "current state: countLow");
            break;

        case countHigh:
            printf("%s\n", "current state: countHigh");
            break;

        default:
            printf("%s\n", "current state: full");
            break;
    }
}

int testFullTransmission(timeDecoder* decoder)
{
    char c = getchar();

    if (c == EOF)
        return -1;

    int bufferFull = 0;

    while (1) {
        if (c == EOF)
            return -1;

        char input = (short) (c - '0');
        bufferFull = updateDecoder(decoder, input);

        if (bufferFull == 3)
            break;

        c = getchar();
    }

    struct tm currentTime;

    int err = updateTimeAndDate(decoder, &currentTime);
    initDecoder(decoder);

    if(err) {
        printf("Err: valid bits but encoding is invalid.\n");
        return 1;
    }

    /* if successful, keep first marker and keep going */
    decoder->currentState = countLow;
    decoder->bitCount = 1;
    updateInputBuffer(decoder, 0);

    int year = 1900 + currentTime.tm_year;
    int month = currentTime.tm_mon + 1;
    int day = currentTime.tm_mday;
    int hour = currentTime.tm_hour;
    int minute = currentTime.tm_min;

    printf("%d-%02d-%02d %02d:%02d\n", year, month, day, hour, minute);

    return 0;
}

int main()
{
    timeDecoder decoder;
    initDecoder(&decoder);

    while (testFullTransmission(&decoder) != -1);
    return 0;
}

