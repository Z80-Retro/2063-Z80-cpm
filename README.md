# 2063-Z80-cpm

A BIOS and build scripts for installing CP/M 2.2 on an SD card for the [Z80 Retro! board.
](https://github.com/johnwinans/2063-Z80)

## How to Clone This Repo

Since incorporating the use of submodules, the process of 'getting everything' requires a command that will recursively download all of the parts like this:

	git clone --recurse-submodules https://github.com/Z80-Retro/2063-Z80-cpm.git

or, if you use ssh (useful if you want to push changes to a repo to make a pull request):

	git clone --recurse-submodules git@github.com:Z80-Retro/2063-Z80-cpm.git


## SD Card Preparation

A discussion of how to partition an SD card for the Retro! board can be found in [./README-SD.md](./README-SD.md)

Be sure to also read the details on [how to install filesystems onto your SD card](./filesystem/README.md).

## Boot a Hello World! app from the SD card

See the code in [./hello](./hello) to create a program that will load and run from the SD card.

## Where to download CP/M 

After the clarification of the Digital Research Inc. license in 2022 on the use and distribution of CP/M, all of the files needed to build and run CP/M on the Retro have been made available on github in the [Z80-Retro/cpm-2.2](https://github.com/Z80-Retro/cpm-2.2) repo.

The CP/M source, utilities, and manuals were collected from the [The Unofficial CP/M Web site](http://www.cpm.z80.de/) in 2023:
- [source code](http://www.cpm.z80.de/source.html) of various CP/M releases:
  - I used the link that says: [CP/M 2,2 ASM SOURCE code](http://www.cpm.z80.de/download/cpm2-asm.zip)
- Application program [binaries](http://www.cpm.z80.de/binary.html) that can run on the Retro!
  - I used the link that says: [CP/M 2.2 BINARY](http://www.cpm.z80.de/download/cpm22-b.zip) distribution disk for the Xerox 1800 system


## Build and install CP/M

See [./retro](./retro) for details on assembling and installing CP/M onto an SD card.

## Resource Links

- [CP/M Manuals](https://github.com/Z80-Retro/manuals)
- Individual manual booklets (for the purists):

- [The Unofficial CP/M Web site](http://www.cpm.z80.de/index.html)
- The PC parallel printer interface port pinout and signal meanings
  - https://bixolonusa.com/wp-content/uploads/2016/06/parallel.pdf
- The Humongous CP/M Software Archives
  - http://cpmarchives.classiccmp.org/
- Good stuff from someone writing a BIOS for a retro project with a nice story about what can happen if you don't carefully read the Alteration Guide first!
  - http://cpuville.com/Code/CPM-on-a-new-computer.html
- A discussion of CP/M internal basics
  - https://obsolescence.wixsite.com/obsolescence/cpm-internals
- A simulator that looks impressive:
  - https://www.autometer.de/unix4fun/z80pack/#documentation

