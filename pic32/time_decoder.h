#ifndef DECODER_H_
#define DECODER_H_

#include <time.h>

#define NSAMPLES 10       /* Number of samples per second */
#define NSPADDING 2       /* Padding for error tolerance */
#define BUFFERSIZE 120    /* Number of transmitted bits to store */

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
 * \param currentTime Stores the current time and date if decoding is successful.
 * \param dst Indicates if DST is in effect.
 *
 * \returns
 *     0: Time signal is successfully decoded
 *     1: Error(s) in time signal.
 */
int updateTimeAndDate(timeDecoder* decoder, time_t* currentTime, int* dst);


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


/*
 * \brief Decode the time and date from one complete frame of transmission.
 *
 * \param frame Pointer to array storing one full frame.
 * \param frameTime Stores the frame time and date.
 *
 * \returns
 *     0: Time signal is successfully decoded
 *     1: Error(s) in time signal.
 */
int decodeFrame(char* frame, struct tm* frameTime);


/*
 * \brief Decode only the time from one complete frame of transmission.
 *
 * \param frame Pointer to array storing one full frame.
 * \param frameTime Stores the frame time and date.
 *
 * \returns
 *     0: Time signal is successfully decoded
 *     1: Error(s) in time signal.
 */
int decodeTime(char* frame, struct tm* frameTime);


/*
 * \brief Decode only the date from one complete frame of transmission.
 *
 * \param frame Pointer to array storing one full frame.
 * \param frameTime Stores the frame time and date.
 *
 * \returns
 *     0: Time signal is successfully decoded
 *     1: Error(s) in time signal.
 */
int decodeDate(char* frame, struct tm* frameTime);


/*
 * \brief Check that predefined 0 and marker bits are in the right position.
 *
 * \param frame Pointer to array storing one full frame.
 *
 * \returns
 *     0: Predefined bits are in the correct position.
 *     1: Invalid frame.
 */
int checkFrame(char* frame);


#endif /* DECODER_H_ */

