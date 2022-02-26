# 2063-Z80-cpm

A BIOS and build scripts for installing CP/M 2.2 on an SD card for the [Z80 Retro! board.
](https://github.com/johnwinans/2063-Z80)

## SD Card Preparation

A discussion of how to partition an SD card for the Retro! board can be found in [./README-SD.md](./README-SD.md)

## Boot a Hello World! app from the SD card

See the code in [./hello](./hello) to create a program that will load and run from the SD card.

## Where to download CP/M 

[The Unofficial CP/M Web site](http://www.cpm.z80.de/) contains:
- [source code](http://www.cpm.z80.de/source.html) of various CP/M releases:
  - We want the link that says: [CP/M 2,2 ASM SOURCE code](http://www.cpm.z80.de/download/cpm2-asm.zip)
- Application program [binaries](http://www.cpm.z80.de/binary.html) that can run on the Retro!
  - We want the link that says: [CP/M 2.2 BINARY](http://www.cpm.z80.de/download/cpm22-b.zip) distribution disk for the Xerox 1800 system

See [./cpm22](./cpm22) for details on downloading and preparing the files for assembly.

## Build and install CP/M

See [./retro](./retro) for details on assembling and installing CP/M onto an SD card.
