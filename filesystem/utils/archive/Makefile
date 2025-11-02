
all:: 

TOP=../../..
include $(TOP)/Make.default
include $(TOP)/Make.rules

BIN=\
	lu310.com \
	unarc.com \
	uncr-z80.com \
	uncr8080.com \
	unzip.com \
	usq120.com

TXT=\
	lu310.hlp \
	unarc.doc \
	uncr8080.doc \
	usq120.doc

all:: $(BIN) $(TXT)

$(BIN):
	wget -O $@ http://cpmarchives.classiccmp.org/cpm/mirrors/oak.oakland.edu/pub/cpm/starter-/$@

$(TXT):
	wget -O $@ http://cpmarchives.classiccmp.org/cpm/mirrors/oak.oakland.edu/pub/cpm/starter-/$@
	unix2dos $@
