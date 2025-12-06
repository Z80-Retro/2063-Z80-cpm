# Go get the SLR assemblers & linker from the net

all:: SLRNK.COM Z80ASM.COM 
#SLR180.COM 

TOP=../../..
include $(TOP)/Make.default
include $(TOP)/Make.rules

SLR180.COM:	SLR180.ZIP
	unzip SLR180.ZIP

SLRNK.COM: SLRNK.ZIP
	unzip SLRNK.ZIP

Z80ASM.COM: Z80ASM.ZIP
	unzip Z80ASM.ZIP

SLR180.ZIP:
	wget http://www.retroarchive.org/cpm/lang/SLR180.ZIP

SLRNK.ZIP:
	wget http://www.retroarchive.org/cpm/lang/SLRNK.ZIP

Z80ASM.ZIP:
	wget http://www.retroarchive.org/cpm/lang/Z80ASM.ZIP
