# 2063-Z80-cpm

A BIOS and build scripts for installing CP/M 2.2 on an SD card for the [Z80 Retro! board.
](https://github.com/johnwinans/2063-Z80)

## How to Avoid Spoilers!

Starting on 20220304 you can avoid any spoilers while watching my 
[YouTube video playlist](https://www.youtube.com/playlist?list=PL3by7evD3F51Cf9QnsAEdgSQ4cz7HQZX5) that discusses this project by clicking on the 
Releases/tags link in github and locate the tag that matches the datecode
in each video. (Specifically the datecode *in* the video itself, not the
dates that YouTube posts about when the videos are uploaded etc.)

Note that I use datacodes that look like this: YYYYMMDD.n 

Sorry I did not think of this before.

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

- Individual manual booklets (for the purists):
  - [Introduction to CPM Features and Facilities](http://www.cpm.z80.de/randyfiles/DRI/Intro_to_CPM_Feat_and_Facilities.pdf)
  - [CP/M 2.0 Guide for CP/M 1.4 Users](http://www.cpm.z80.de/randyfiles/DRI/CPM_2_0_UG_for_CPM_1_4_Users.pdf)
  - [ED (A Text Editor)](http://www.cpm.z80.de/randyfiles/DRI/ED.pdf)
  - [DDT (Dynamic Debugging Tool)](http://www.cpm.z80.de/randyfiles/DRI/DDT.pdf)
  - [ASM (An 8080 Assembler)](http://www.cpm.z80.de/randyfiles/DRI/ASM.pdf)
  - [CP/M 2.0 Interface Guide](http://www.cpm.z80.de/randyfiles/DRI/CPM_2_0_Interface_Guide.pdf)
  - [CP/M 2.0 System Alteration Guide](http://www.cpm.z80.de/randyfiles/DRI/CPM_2_0_System_Alteration_Guide.pdf)
  - [CP/M 2.2 System Alteration Guide](http://bitsavers.trailing-edge.com/pdf/digitalResearch/cpm/2.2/CPM_2.2_Alteration_Guide_1979.pdf)
- One big book of all the above manuals
  - [CP/M 2.x Operating System Manual](http://bitsavers.trailing-edge.com/pdf/digitalResearch/cpm/CPM_Operating_System_Manual_Jul82.pdf)

- [The Unofficial CP/M Web site](http://www.cpm.z80.de/index.html)
- Genuine Internet hearsay evidence that *suggests* that CP/M can be used in for personal use! 
  - http://www.gaby.de/faq.htm#5
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

