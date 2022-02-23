# A FLASH boot loader for Z80 Retro!

This is a boot loader that will load the first 16KB from partition 1 into RAM from `0xc000-0xffff` and then jump to `0xc000` to execute it.

On a PI-hosted dev system you can program this code into the FLASH like this:

	~/2065-Z80-programmer/pi/flash < firmware.bin
