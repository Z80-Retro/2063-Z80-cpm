# Go get the SLR assemblers & linker from www.retroarchive.org

all:: bin/SLRNK.COM bin/Z80ASM.COM bin/Z80ASM.PDF
#SLR180.COM 

TOP=../../..
include $(TOP)/Make.default
include $(TOP)/Make.rules

bin/SLR180.COM:	SLR180.ZIP
	unzip -n -d bin SLR180.ZIP
	touch bin/*

bin/SLRNK.COM: SLRNK.ZIP
	unzip -n -d bin SLRNK.ZIP
	touch bin/*

bin/Z80ASM.COM: Z80ASM.ZIP
	unzip -n -d bin Z80ASM.ZIP
	rm -f bin/DUMP.*		# This conflicts with the copy of DUMP.COM from the CP/M distro
	touch bin/*

bin/Z80ASM.PDF: slr_man.zip
	unzip -n -d doc slr_man.zip

SLR180.ZIP:
	wget http://www.retroarchive.org/cpm/lang/SLR180.ZIP

SLRNK.ZIP:
	wget http://www.retroarchive.org/cpm/lang/SLRNK.ZIP

Z80ASM.ZIP:
	wget http://www.retroarchive.org/cpm/lang/Z80ASM.ZIP

slr_man.zip:
	wget http://www.retroarchive.org/cpm/lang/slr_man.zip
