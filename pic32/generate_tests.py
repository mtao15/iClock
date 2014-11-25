from generate_signal import *
import datetime

# set numbers of cases to generate
lines = 100000
# set continuous or non-continuous double frames
continuous = True


signal = open('signals.txt', 'w')
truth = open('time.txt', 'w')

randomNoiseStart = generateNoise()
bitNoiseStart = generateBitNoise() + generateBit('m')
signal.write(randomNoiseStart)
signal.write(bitNoiseStart)

for x in xrange(lines):
    (testSignal, syncFinishTime) =\
            generateTests(bitNoise=continuous, randomNoise=continuous)
    timeString = syncFinishTime.strftime('%Y-%m-%d %H:%M')

    signal.write(testSignal)
    truth.write(timeString + '\n')

signal.write('0')

truth.close()
signal.close()
