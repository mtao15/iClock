import sys
import random
import datetime

def generateBit(bit):
    lows = 8

    if bit == '0' or bit == 0:
        lows = 2
    elif bit == '1' or bit == 1:
        lows = 5

    string = ''

    for x in xrange(lows):
        string += '0'
    for x in xrange(10 - lows):
        string += '1'

    return string


def fillFrame(value, indAndWeight, frame):
    indAndWeight = indAndWeight

    for pair in indAndWeight:
        (ind, weight) = pair
        frame[ind] = value / weight

        if (value / weight > 0):
            value %= weight


def generateTimeBits(year, month, day, hour, minute):
    frame = [0 for x in xrange(60)]

    # minute
    indAndWeight = [(1,40), (2,20), (3,10), (5,8), (6,4), (7,2), (8,1)]
    fillFrame(minute, indAndWeight, frame)

    # hour
    indAndWeight = [(12,20), (13,10), (15,8), (16,4), (17,2), (18,1)]
    fillFrame(hour, indAndWeight, frame)

    yearStart = datetime.date(2000+year, 1, 1)
    currentDate = datetime.date(2000+year, month, day)

    dayOfYear = datetime.date.toordinal(currentDate)\
              - datetime.date.toordinal(yearStart) + 1


    # day of year
    indAndWeight = [(22,200), (23,100), (25,80), (26,40), (27,20),\
                    (28,10),  (30,8),   (31,4),  (32,2),  (33,1)]
    fillFrame(dayOfYear, indAndWeight, frame)


    # last 2 digit of year
    indAndWeight = [(45,80), (46,40), (47,20), (48,10),\
                    (50,8),  (51,4),  (52,2),  (53,1)]
    fillFrame(year, indAndWeight, frame)

    dst = 0
    leapYear = 0
    if year % 400 == 0 or (year % 4 == 0 and year % 100 != 0):
        leapYear = 1

    frame[55] = leapYear
    frame[57] = frame[58] = 0;

    fillPreDefinedBits(frame)

    return frame

def generateTimeSignal(year, month, day, hour, minute):
    frame = generateTimeBits(year, month, day, hour, minute)
    signal = ''

    for bit in frame:
        signal += generateBit(bit)
    return signal

def fillPreDefinedBits(frame):
    frame[0]  = 'm' ; frame[4]  =  0 ; frame[9]  = 'm';
    frame[10] =  0  ; frame[11] =  0 ; frame[14] =  0 ;
    frame[19] = 'm' ; frame[20] =  0 ; frame[21] =  0 ;
    frame[24] =  0  ; frame[29] = 'm'; frame[34] =  0 ;
    frame[35] =  0  ; frame[39] = 'm'; frame[44] =  0 ;
    frame[49] = 'm' ; frame[54] =  0 ; frame[59] = 'm';


def generateNoise():
    length = random.randint(10,60)
    noise = [random.randint(0,1) for x in xrange(length)]

    out = ''
    for x in noise:
        out += str(x)

    return out

def generateBitNoise():
    out = ''
    nPad = random.randint(2, 10)
    for x in xrange(nPad):
        bit = random.randint(0, 1)
        out += generateBit(bit)

    return out


def generateTests(bitNoise=True, randomNoise=True):
    epoch = datetime.datetime(year=2000, month=1, day=1, hour=0, minute=0, second = 0)

    frame1Time = epoch + datetime.timedelta(seconds=random.randint(0, 32*31536000))
    frame2Time = frame1Time + datetime.timedelta(seconds=60)

    syncFinishedTime = frame2Time + datetime.timedelta(seconds=60)

    frame1Signal = generateTimeSignal(frame1Time.year - 2000, frame1Time.month,\
                                      frame1Time.day,frame1Time.hour, frame1Time.minute)
    frame2Signal = generateTimeSignal(frame2Time.year - 2000, frame2Time.month,\
                                      frame2Time.day,frame2Time.hour, frame2Time.minute)

    bitNoiseStart = bitNoiseEnd = randomNoiseStart = ''

    if bitNoise:
        bitNoiseStart = generateBitNoise() + generateBit('m')
        bitNoiseEnd = generateBitNoise()

    if randomNoise:
        randomNoiseStart = generateNoise()

    out = randomNoiseStart + bitNoiseStart + frame1Signal + frame2Signal + bitNoiseEnd

    return (out, syncFinishedTime)


if __name__ == '__main__':
    (testSignal, syncFinishTime) = generateTests()

    sys.stdout.write(testSignal)

