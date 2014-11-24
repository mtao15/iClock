#ifndef DECODER_H_
#define DECODER_H_

#include <time.h>

#define NSAMPLES 40
#define NSPADDING 4
#define BUFFERSIZE 120

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
    char inputBuffer[NSAMPLES + NSPADDING];

    /* stores bits encoded in the transmission */
    char bitBuffer[BUFFERSIZE];

    /* current state of the timeDecoder state machine */
    enum STATE currentState;

    int foundStart;   /* have seen two consecutive marker bits */
    int bitCount;     /* number of encoded bits stored in bitBuffer */
    int inputCount;   /* number of raw input samples in inputBuffer */

} timeDecoder;


/*
 * \brief Initialize a timeDecoder state machine.
 *
 * \param decoder Pointer to timeDecoder to initialize.
 */
void initDecoder(timeDecoder* decoder);


/*
 * \brief Update the timeDecoder state machine.
 *
 * \param decoder Pointer to timeDecoder to update.
 * \param input Raw input sample from receiver board.
 *
 * \returns
 *     0: No errors detected yet in signal.
 *     1: Error detected in time signal and timeDecoder state machine
 *        has been reset.
 *     2: Signal valid so far, but have not found start of frame.
 *     3: Buffer storing encoded bits is full, ready for decoding.
 */
int updateDecoder(timeDecoder* decoder, int input);


/*
 * \brief Decode received transmission frames and get the current time and date.
 *
 * \param decoder Pointer to timeDecoder.
 * \param updatedTime Stores the current time and date if decoding is successful.
 *
 * \returns
 *     0: Time signal is successfully decoded
 *     1: Error(s) in time signal.
 */
int updateTimeAndDate(timeDecoder* decoder, time_t* currentTime);


/*
 * \brief Update the input buffer of the timeDecoder.
 *
 * \param decoder Pointer to the timeDecoder to update.
 * \param input Raw input sample from receiver board.
 */
void updateInputBuffer(timeDecoder* decoder, int input);


/*
 * \brief Update the bit buffer of the timeDecoder by decoding
 *        the samples from inputBuffer.
 *
 * \param decoder Pointer to the timeDecoder to update.
 *
 * \returns
 *     0: Input buffer decoded successfully.
 *     1: Input buffer is not a valid encoding.
 *     2: Input buffer is valid but can be discarded.
 */
int updateBitBuffer(timeDecoder* decoder);


int funcWaitForHigh(timeDecoder* decoder, int input);


int funcWaitForEdge(timeDecoder* decoder, int input);


int funcCountLow(timeDecoder* decoder, int input);


int funcCountHigh(timeDecoder* decoder, int input);


/*
 * \brief Decode the time and date from one complete frame of transmission.
 *
 * \param bitBuffer Pointer to array storing one full frame.
 * \param updatedTime Stores the current time and date.
 *
 * \returns
 *     0: Time signal is successfully decoded
 *     1: Error(s) in time signal.
 */
int decodeFrame(char* bitBuffer, struct tm* currentTime);


/*
 * \brief Decode only the time from one complete frame of transmission.
 *
 * \param bitBuffer Pointer to array storing one full frame.
 * \param updatedTime Stores the current time and date.
 *
 * \returns
 *     0: Time signal is successfully decoded
 *     1: Error(s) in time signal.
 */
int decodeTime(char* bitBuffer, struct tm* currentTime);


/*
 * \brief Decode only the date from one complete frame of transmission.
 *
 * \param bitBuffer Pointer to array storing one full frame.
 * \param updatedTime Stores the current time and date.
 *
 * \returns
 *     0: Time signal is successfully decoded
 *     1: Error(s) in time signal.
 */
int decodeDate(char* bitBuffer, struct tm* currentTime);


/*
 * \brief Check that predefined 0 and marker bits are in the right position.
 *
 * \param bitBuffer Pointer to array storing one full frame.
 *
 * \returns
 *     0: Predefined bits are in the correct position.
 *     1: Invalid frame.
 */
int checkFrame(char* bitBuffer);


#endif /* DECODER_H_ */

