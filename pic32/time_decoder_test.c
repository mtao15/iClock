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
    initDecoder(&decoder);

    char c = getchar();

    while (c != '\n' && c != '\r' && c != EOF) {
        short input = (short) (c - '0');

        updateDecoder(&decoder, input);
        c = getchar();
    }


    for (int i = 0; i < decoder.bitCount; i++)
    {
        char c;
        switch (decoder.bitBuffer[i]){
            case 0:
                c = '0';
                break;
            case 1:
                c = '1';
                break;
            default:
                c = 'm';
        }
        printf("%c", c);
    }

    printf("\n");

    return 0;
}

