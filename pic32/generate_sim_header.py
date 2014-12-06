from generate_signal import *

import datetime

# set numbers of cases to generate
minutes = 30
currentTime = datetime.datetime(year = 2014, month = 12, day = 6,\
        hour = 1, minute = 7, second = 0)

bitString = ''

headerFile = open('../wwvb_simulator/signal_out.h', 'w')

for x in xrange(minutes):
    year = currentTime.year - 2000
    month = currentTime.month
    day = currentTime.day
    hour = currentTime.hour
    minute = currentTime.minute

    bitString = bitString + generateTimeSignal(year, month, day, hour, minute)

    currentTime = currentTime + datetime.timedelta(seconds=60)


headerFile.write('int signal_out()\n')
headerFile.write('{\n')


headerFile.write('    ')
headerFile.write('static int bitsCount = ' + str(len(bitString)) + ';\n')


headerFile.write('    ')
headerFile.write('static char *bits = \"' + bitString + '\";\n\n')


headerFile.write('    ')
headerFile.write('static int index = 0;\n\n')

headerFile.write('    ')
headerFile.write('int retVal = ~(bits[index] - \'0\');\n')

headerFile.write('    ')
headerFile.write('index = (index + 1) % bitsCount;\n\n')

headerFile.write('    ')
headerFile.write('return retVal;\n')

headerFile.write('}\n')
