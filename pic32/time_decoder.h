#ifndef DECODER_H_
#define DECODER_H_

#include <string.h>
#include <math.h>

#define NSAMPLES 40
#define NSPADDING 5
#define BUFFERSIZE 180

enum STATE {
    waitForHigh,
    waitForEdge,
    countLow,
    countHigh,
    bufferFull
};


/* Stores received signals from receiver board */
typedef struct {
    /* stores raw input from receiver board */
    short inputBuffer[NSAMPLES + NSPADDING];

    /* stores bits encoded in the transmission */
    char bitsBuffer[BUFFERSIZE];

    /* current state of the time decoder state machine */
    enum STATE currentState;

    short bitsCount;     /* number of encoded bits stored in bitsBuffer */
    short inputCount;    /* number of raw input samples in inputBuffer */

} timeDecoder;


/*
 * \brief Initialize a time decoder state machine.
 *
 * \param decoder Pointer to time decoder to initialize.
 */
void initTimeDecoder(timeDecoder* decoder);


/*
 * \brief Update the time decoder state machine.
 *
 * \param decoder Pointer to time decoder to update.
 * \param input Raw input sample from receiver board.
 *
 * \returns
 *     0: No errors detected yet in signal.
 *     1: Error detected in time signal and time decoder state machine
 *        has been reset.
 *     2: Buffer storing encoded bits is full, ready for decoding.
 */
int updateTimeDecoder(timeDecoder* decoder, short input);


/*
 * \brief Decode the time signal and get the current time.
 *
 * \param decoder Pointer to time decoder.
 * \param updatedTime Stores the current time is decoding is successful.
 *
 * \returns
 *     0: Time signal is successfully decoded
 *     1: Error(s) in time signal.
 */
int decodeTimeSignal(timeDecoder* decoder, short* currentTime);


/*
 * \brief Update the input buffer of the time decoder.
 *
 * \param decoder Pointer to the time decoder to update.
 * \param input Raw input sample from receiver board.
 */
void updateInputBuffer(timeDecoder* decoder, short input);


/*
 * \brief Update the bit buffer of the time decoder by decoding
 *        the samples from inputBuffer.
 *
 * \param decoder Pointer to the time decoder to update.
 *
 * \returns
 *     0: Input buffer decoded successfully.
 *     1: Input buffer is not a valid encoding.
 */
int updateBitBuffer(timeDecoder* decoder);


int funcWaitForHigh(timeDecoder* decoder, short input);


int funcWaitForEdge(timeDecoder* decoder, short input);


int funcCountLow(timeDecoder* decoder, short input);


int funcCountHigh(timeDecoder* decoder, short input);


#endif /* DECODER_H_ */

