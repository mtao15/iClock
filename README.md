##WWVB Radio Controlled Clock

###Overview

The NIST radio station WWVB based in Colorado broadcasts the current UTC time
over a 60kHz carrier wave. These time signals can be picked up by a receiver
and used to synchronize a clock.

###PIC32

A WWVB receiver board is connected to a PIC32 microprocessor, which decodes the
received time signal. The decoded time signal is used to synchronize the time
of the PIC32, which is then sent via SPI to a FPGA.

###FPGA

A VGA monitor is connected to the FPGA, which draws an analogue clock face to
display the current time.
