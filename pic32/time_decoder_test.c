#include <stdio.h>
#include <stdlib.h>

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

int main()
{
    timeDecoder decoder;
    initTimeDecoder(&decoder);

    char c = getchar();

    while (c != '\n' && c != '\r' && c != EOF) {
        short input = (short) (c - '0');

        updateTimeDecoder(&decoder, input);
//        printState(&decoder);
        c = getchar();
    }


    for (int i = 0; i < decoder.bitsCount; i++)
    {
        printf("%c", decoder.bitsBuffer[i]);
    }

    printf("\n");

    return 0;
}
