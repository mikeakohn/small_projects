#!/usr/bin/env python3

# For more info:
# https://www.mikekohn.net/micro/winbond_flash.php

import gpiozero
import spidev
import time

winbond_reset = gpiozero.LED(17)
winbond_wp = gpiozero.LED(27)
spi_cs = gpiozero.LED(22)

# Set /RESET low to put the Winbond in a reset state.
# Set /WP low to make the chip's memory read only.
# Set /CS high (deselecting it).
winbond_reset.off()
winbond_wp.off()
spi_cs.on()

# Pause for a second (shouldn't be needed).
print("Starting up...")
time.sleep(1)

# Set /RESET high taking the Winbond out of reset state.
# Set /WP high to make the chip's memory writable.
winbond_reset.on()
winbond_wp.on()

# Initialize SPI bus.
spi = spidev.SpiDev()
spi.open(0, 0)
spi.mode = 0
spi.lsbfirst = False
spi.max_speed_hz = 1000000

# Read manufacturer and device ID (last two bytes) from device.
# Should come back as 0xef (239) and 0x17 (23).
spi_cs.off()
ids = spi.xfer2([ 0x90, 0x00, 0x00, 0x00, 0x00, 0x00 ])
spi_cs.on()

# Read STATUS_1 register.
spi_cs.off()
status_1 = spi.xfer2([ 0x05, 0x00 ])
spi_cs.on()

# Read 4 bytes at location 0x000000.
spi_cs.off()
data = spi.xfer2([ 0x03, 0x00, 0x00, 0x00,  0x00, 0x00, 0x00, 0x00 ])
spi_cs.on()

print("ids=" + str(ids))
print("status_1=" + str(status_1))
print("data=" + str(data))

spi.close()

