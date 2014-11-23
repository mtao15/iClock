#ifndef DECODE_H_
#define DECODE_H_

#include <string.h>
#include <math.h>

#define NSAMPLES 40
#define BUFFERSIZE 180

enum STATE {
    startLow,
    startHigh,
    countLow,
    countHigh
}


typedef struct {
    short        [NSAMPLES + 10] inputBuffer;
    char         [BUFFERSIZE]    bitsBuffer;
    unsigned int [BUFFERSIZE]    receptionTime;

    int bitsCount = 0;
    int inputCount = 0;

    enum STATE currentState;

} timeDecoder;


void initTimeDecoder(timeDecoder* decoder, short firstInput);


void resetTimeDecoder(timeDecoder* decoder);


int updateTimeDecoder(timeDecoder* decoder, short input);


int decodeTimeSignal(timeDecoder* decoder);

/* blah */

#endif /* DECODE_H_ */

