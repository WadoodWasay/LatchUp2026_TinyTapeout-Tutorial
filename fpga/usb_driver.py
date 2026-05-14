#!/usr/bin/env python3
#
# Driver for charlieplex array project
# This can be used to send SPI commands to the project over
# USB from a host computer.

from pyftdi.ftdi import Ftdi
import time
import sys, os
# from pyftdi.spi import SpiController
import pyftdi.serialext
from array import array as Array
import binascii
import struct
from io import StringIO

# Open the USB FTDI device
# This is roundabout but works. . .

s = StringIO()
Ftdi.show_devices(out=s)
devlist = s.getvalue().splitlines()[1:-1]
gooddevs = []
for dev in devlist:
    url = dev.split('(')[0].strip()
    name = '(' + dev.split('(')[1]
    # if name == '(Single RS232-HS)':
    if name == '(Digilent USB Device)' and url.endswith('/2'):
        gooddevs.append(url)
if len(gooddevs) == 0:
    print('Error:  No matching FTDI devices on USB bus!')
    sys.exit(1)
elif len(gooddevs) > 1:
    print('Error:  Too many matching FTDI devices on USB bus!')
    Ftdi.show_devices()
    sys.exit(1)
else:
    print('Success: Found one matching FTDI device at ' + gooddevs[0])

port = pyftdi.serialext.serial_for_url(gooddevs[0], baudrate=96000)

remap = [ 6,  5,  4,  3,  2,  1,  0,  7,
	 13, 12, 11, 10,  9,  8, 15, 14,
	 20, 19, 18, 17, 16, 23, 22, 21,
	 27, 26, 25, 24, 31, 30, 29, 28,
	 34, 33, 32, 39, 38, 37, 36, 35,
	 41, 40, 47, 46, 45, 44, 43, 42,
	 48, 55, 54, 53, 52, 51, 50, 49]

k = '0'
while (k != 'q'):

    print("\n-----------------------------------\n")
    print("Select option:")
    print("  (1) all on ")
    print("  (2) all off ")
    print("  (3) smiley ")
    print("  (4) gradient ")
    print("  (5) progressive ones ")
    print("  (6) progressive zeros ")
    print("  (q) quit")

    print("\n")

    k = input()

    # To do:  Put meaningful data here.  The Charlieplex array
    # controller takes care of which lines should be high, low, or
    # high-impedence.  The registered data represents the 4-bit
    # gray-scale values of the 58 LEDs.  There are 58 registers,
    # one for each LED, 

    if k == '1':
        print("Setting all LEDs on")
	# Write 56 bytes (56 nybbles)
        port.write(b'\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff')
        port.read(57)

    elif k == '2':
        print("Setting all LEDs off")
	# Write 56 bytes (56 nybbles)
        port.write(b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')
        port.read(57)

    elif k == '3':
        print("Setting LED test")
        # Set all LEDs off
        port.write(b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')
        port.read(57)
        # Set LEDs at specific coordinates
        xvals = [2, 5, 2, 5, 1, 2, 3, 4, 5, 6]
        yvals = [1, 1, 2, 2, 4, 5, 5, 5, 5, 4]
        for i in range(0, len(xvals)):
            idx = yvals[i] * 8 + xvals[i]
            c = chr(remap[idx])
            port.write(c + '\x07')
            port.read(2)

    elif k == '4':
        print("Setting LED gradient")
        d = '\x01\x02\x03\x04\x05\x06\x07'
        e = 0.0
        for x in range(0, 8):
            for y in range(0, 7):
                idx = y * 8 + x
                c = chr(remap[idx])
                port.write(c + d[y])
                port.read(2)

    elif k == '5':
        print("Progressive ones")
        for c in remap:
            port.write(chr(c) + '\x07')
            port.read(2)
            time.sleep(0.05)

    elif k == '6':
        print("Progressive zeros")
        for c in remap:
            port.write(chr(c) + '\x00')
            port.read(2)
            time.sleep(0.05)

    elif k == 'q':
        print("Exiting...")

    else:
        print('Selection not recognized.\n')

port.close()

