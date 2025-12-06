# Go get the SLR assemblers & linker from www.retroarchive.org

all:: bin/SLRNK.COM bin/Z80ASM.COM 
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
	rm -f bin/DUMP.*		# this will conflict with the DUMP.COM from the cp/m distro
	touch bin/*

SLR180.ZIP:
	wget http://www.retroarchive.org/cpm/lang/SLR180.ZIP

SLRNK.ZIP:
	wget http://www.retroarchive.org/cpm/lang/SLRNK.ZIP

Z80ASM.ZIP:
	wget http://www.retroarchive.org/cpm/lang/Z80ASM.ZIP
