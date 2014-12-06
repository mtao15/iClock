from generate_signal import *
import datetime

# set numbers of cases to generate
lines = 150000


signal = open('signals.txt', 'w')
truth = open('time.txt', 'w')

bitNoiseStart = '1111111111111111111111' + generateBit('m')
signal.write(bitNoiseStart)

for x in xrange(lines):
    (testSignal, syncFinishTime) =\
            generateTests()
    timeString = syncFinishTime.strftime('%Y-%m-%d %H:%M')

    signal.write(testSignal)
    truth.write(timeString + '\n')

signal.write('0')

truth.close()
signal.close()
