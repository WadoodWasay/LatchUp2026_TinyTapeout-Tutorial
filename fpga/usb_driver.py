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

k = '0'
while (k != 'q'):

    print("\n-----------------------------------\n")
    print("Select option:")
    print("  (1) all on ")
    print("  (2) all off ")
    print("  (3) gradient ")
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
        port.write(b'\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff')
        port.read(56)

    elif k == '2':
        print("Setting all LEDs off")
	# Write 56 bytes (56 nybbles)
        port.write(b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00')
        port.read(56)

    elif k == '3':
        print("Setting LED gradient")
	# Write 56 bytes (56 nybbles)
        port.write(b'\x11\x11\x22\x22\x33\x33\x44\x44\x55\x55\x66\x66\x77\x77\x88\x88\x99\x99\xaa\xaa\xbb\xbb\xcc\xcc\xdd\xdd\xee\xee\x11\x11\x22\x22\x33\x33\x44\x44\x55\x55\x66\x66\x77\x77\x88\x88\x99\x99\xaa\xaa\xbb\xbb\xcc\xcc\xdd\xdd\xee\xee')
        port.read(56)

    elif k == 'q':
        print("Exiting...")

    else:
        print('Selection not recognized.\n')

port.close()

