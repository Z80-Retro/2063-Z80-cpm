
all:: 

TOP=../../..
include $(TOP)/Make.default
include $(TOP)/Make.rules

PROGS=\
	lu310.com \
	lu310.hlp \
	lu300.dqc \
	unarc.com \
	unarc.doc \
	uncr-z80.com \
	uncr8080.com \
	uncr8080.doc \
	unzip.com \
	usq120.com \
	usq120.hex

all:: $(PROGS)

$(PROGS):
	wget -O $@ http://cpmarchives.classiccmp.org/cpm/mirrors/oak.oakland.edu/pub/cpm/starter-/$@

