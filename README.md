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

## Resource Links

- Manuals
  - [CP/M 2.2 Alteration Guide](http://bitsavers.trailing-edge.com/pdf/digitalResearch/cpm/2.2/CPM_2.2_Alteration_Guide_1979.pdf)
  - A book of the CP/M 2 manuals http://bitsavers.trailing-edge.com/pdf/digitalResearch/cpm/CPM_Operating_System_Manual_Jul82.pdf

- [The Unofficial CP/M Web site](http://www.cpm.z80.de/index.html)
- Genuine Internet hearsay evidence that *suggests* that CP/M can be used in for personal use! 
  - http://www.gaby.de/faq.htm#5
  - http://www.cpm.z80.de/tim.htm
- The PC parallel printer interface port pinout and signal meanings
  - https://bixolonusa.com/wp-content/uploads/2016/06/parallel.pdf
- THe Humongous CP/M Software Archives
  - http://cpmarchives.classiccmp.org/
- Good stuff from someone writing a BIOS for a retro project with a nice story about what can happen if you don't carefully read the Alteration Guide first!
  - http://cpuville.com/Code/CPM-on-a-new-computer.html
- A discussion of CP/M internal basics
  - https://obsolescence.wixsite.com/obsolescence/cpm-internals
- A simulator that looks impressive. But complicated:
  - https://www.autometer.de/unix4fun/z80pack/#documentation

