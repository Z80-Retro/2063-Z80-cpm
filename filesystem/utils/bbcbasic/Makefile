# Go get BBC BASIC from https://github.com/Z80-Retro/BBCZ80

all:: bin/BBCBASIC.COM

TOP=../../..
include $(TOP)/Make.default
include $(TOP)/Make.rules

bin/BBCBASIC.COM:
	wget -O $@ https://github.com/Z80-Retro/BBCZ80/raw/refs/heads/master/bin/cpm/BBCBASIC.COM
